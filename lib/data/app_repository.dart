import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../core/app_date.dart';
import '../core/calculators.dart';
import '../models/ai.dart';
import '../models/exercise.dart';
import '../models/models.dart';
import 'seed_exercises.dart';
import 'seed_plans.dart';
import 'seed_recipes.dart';

/// 本地数据仓库：内存中维护全部实体，写入 SharedPreferences。
/// 数据量在个人使用场景内很小，读写都是毫秒级。
class AppRepository extends ChangeNotifier {
  AppRepository({SharedPreferences? preferences}) : _prefs = preferences;

  static const int seedVersion = 1;

  static const String _kProfile = 'xy.profile';
  static const String _kWeights = 'xy.weights';
  static const String _kRecipes = 'xy.recipes';
  static const String _kEntries = 'xy.meals';
  static const String _kWater = 'xy.water';
  static const String _kSeedVersion = 'xy.seedVersion';
  static const String _kAiConfig = 'xy.ai';
  static const String _kCustomPlans = 'xy.customPlans';
  static const String _kExerciseFavorites = 'xy.exerciseFavorites';
  static const String _kExercisePlan = 'xy.exercisePlan';

  static const List<String> _mealOrder = [
    'breakfast',
    'lunch',
    'dinner',
    'snack',
  ];

  SharedPreferences? _prefs;

  Profile _profile = const Profile();
  final List<WeightRecord> _weights = [];
  final List<Recipe> _recipes = [];
  final List<MealEntry> _entries = [];
  final List<WaterLog> _water = [];
  final List<DietPlan> _customPlans = [];
  final List<ExercisePlanEntry> _exerciseEntries = [];
  final Set<String> _favoriteExercises = <String>{};
  AiConfig _aiConfig = const AiConfig();

  bool _loaded = false;
  String? _loadError;

  bool get loaded => _loaded;
  String? get loadError => _loadError;

  Profile get profile => _profile;

  AiConfig get aiConfig => _aiConfig;

  List<WeightRecord> get weightRecords =>
      List<WeightRecord>.unmodifiable(_sortedWeights());

  List<Recipe> get recipes => List<Recipe>.unmodifiable(_recipes);

  List<Recipe> get builtinRecipes =>
      List<Recipe>.unmodifiable(_recipes.where((r) => r.isBuiltin));

  List<Recipe> get customRecipes =>
      List<Recipe>.unmodifiable(_recipes.where((r) => !r.isBuiltin));

  List<MealEntry> get mealEntries => List<MealEntry>.unmodifiable(_entries);

  List<WaterLog> get waterLogs => List<WaterLog>.unmodifiable(_water);

  /// 内置方案在前，用户自定义方案按创建顺序排在后面。
  List<DietPlan> get dietPlans =>
      List<DietPlan>.unmodifiable([...seedPlans, ..._customPlans]);

  List<DietPlan> get customDietPlans =>
      List<DietPlan>.unmodifiable(_customPlans);

  DietPlan? dietPlanById(String id) {
    for (final plan in _customPlans) {
      if (plan.id == id) return plan;
    }
    return planById(id);
  }

  bool isDietPlanCustom(String id) => _customPlans.any((plan) => plan.id == id);

  List<ExerciseVideo> get exercises =>
      List<ExerciseVideo>.unmodifiable(seedExercises);

  List<ExercisePlanEntry> get exercisePlanEntries =>
      List<ExercisePlanEntry>.unmodifiable(_exerciseEntries);

  Set<String> get favoriteExerciseIds =>
      Set<String>.unmodifiable(_favoriteExercises);

  bool isExerciseFavorite(String id) => _favoriteExercises.contains(id);

  ExerciseVideo? exerciseById(String id) {
    for (final video in seedExercises) {
      if (video.id == id) return video;
    }
    return null;
  }

  List<ExerciseVideo> get favoriteExercises => List<ExerciseVideo>.unmodifiable(
    seedExercises.where((video) => _favoriteExercises.contains(video.id)),
  );

  Future<void> load() async {
    _prefs ??= await SharedPreferences.getInstance();
    try {
      final profileRaw = _prefs!.getString(_kProfile);
      if (profileRaw != null && profileRaw.isNotEmpty) {
        final decoded = jsonDecode(profileRaw);
        if (decoded is Map) {
          _profile = Profile.fromJson(Map<String, dynamic>.from(decoded));
        }
      }
      _weights
        ..clear()
        ..addAll(_decodeList(_kWeights, WeightRecord.fromJson));
      _recipes
        ..clear()
        ..addAll(_decodeList(_kRecipes, Recipe.fromJson));
      _entries
        ..clear()
        ..addAll(_decodeList(_kEntries, MealEntry.fromJson));
      _water
        ..clear()
        ..addAll(_decodeList(_kWater, WaterLog.fromJson));
      _customPlans
        ..clear()
        ..addAll(_decodeList(_kCustomPlans, DietPlan.fromJson));
      _exerciseEntries
        ..clear()
        ..addAll(_decodeList(_kExercisePlan, ExercisePlanEntry.fromJson));
      _favoriteExercises
        ..clear()
        ..addAll(
          _prefs!.getStringList(_kExerciseFavorites) ?? const <String>[],
        );
      final aiRaw = _prefs!.getString(_kAiConfig);
      if (aiRaw != null && aiRaw.isNotEmpty) {
        final decoded = jsonDecode(aiRaw);
        if (decoded is Map) {
          _aiConfig = AiConfig.fromJson(Map<String, dynamic>.from(decoded));
        }
      }
    } catch (error) {
      _loadError = '$error';
    }
    await _seedIfNeeded();
    _loaded = true;
    notifyListeners();
  }

  List<T> _decodeList<T>(
    String key,
    T Function(Map<String, dynamic>) fromJson,
  ) {
    final raw = _prefs?.getString(key);
    if (raw == null || raw.isEmpty) return <T>[];
    final decoded = jsonDecode(raw);
    if (decoded is! List) return <T>[];
    final result = <T>[];
    for (final item in decoded) {
      if (item is Map) {
        result.add(fromJson(Map<String, dynamic>.from(item)));
      }
    }
    return result;
  }

  Future<void> _seedIfNeeded() async {
    final current = _prefs?.getInt(_kSeedVersion) ?? 0;
    if (current >= seedVersion) return;
    final ids = _recipes.map((r) => r.id).toSet();
    var changed = false;
    for (final recipe in seedRecipes) {
      if (!ids.contains(recipe.id)) {
        _recipes.add(recipe);
        changed = true;
      }
    }
    await _prefs?.setInt(_kSeedVersion, seedVersion);
    if (changed) {
      await _saveRecipes();
    }
  }

  // ---------------------------------------------------------------------------
  // 持久化
  // ---------------------------------------------------------------------------

  Future<void> _saveProfile() async {
    await _prefs?.setString(_kProfile, jsonEncode(_profile.toJson()));
  }

  Future<void> _saveWeights() async {
    await _prefs?.setString(
      _kWeights,
      jsonEncode(_weights.map((e) => e.toJson()).toList()),
    );
  }

  Future<void> _saveRecipes() async {
    await _prefs?.setString(
      _kRecipes,
      jsonEncode(_recipes.map((e) => e.toJson()).toList()),
    );
  }

  Future<void> _saveEntries() async {
    await _prefs?.setString(
      _kEntries,
      jsonEncode(_entries.map((e) => e.toJson()).toList()),
    );
  }

  Future<void> _saveWater() async {
    await _prefs?.setString(
      _kWater,
      jsonEncode(_water.map((e) => e.toJson()).toList()),
    );
  }

  Future<void> _saveCustomPlans() async {
    await _prefs?.setString(
      _kCustomPlans,
      jsonEncode(_customPlans.map((e) => e.toJson()).toList()),
    );
  }

  Future<void> _saveExercisePlan() async {
    await _prefs?.setString(
      _kExercisePlan,
      jsonEncode(_exerciseEntries.map((e) => e.toJson()).toList()),
    );
  }

  Future<void> _saveExerciseFavorites() async {
    await _prefs?.setStringList(
      _kExerciseFavorites,
      _favoriteExercises.toList(growable: false),
    );
  }

  // ---------------------------------------------------------------------------
  // 资料
  // ---------------------------------------------------------------------------

  Future<void> updateProfile(Profile value) async {
    _profile = value;
    await _saveProfile();
    notifyListeners();
  }

  Future<void> updateAiConfig(AiConfig value) async {
    _aiConfig = value;
    await _prefs?.setString(_kAiConfig, jsonEncode(value.toJson()));
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // 体重
  // ---------------------------------------------------------------------------

  List<WeightRecord> _sortedWeights() {
    final list = _weights.toList();
    list.sort((a, b) => a.recordedAt.compareTo(b.recordedAt));
    return list;
  }

  WeightRecord? get latestWeight {
    if (_weights.isEmpty) return null;
    return _sortedWeights().last;
  }

  double get currentWeightKg =>
      latestWeight?.weightKg ?? _profile.startWeightKg;

  WeightRecord? lastRecordOnDate(String date) {
    WeightRecord? result;
    for (final record in _weights) {
      if (record.date != date) continue;
      if (result == null || record.recordedAt.isAfter(result.recordedAt)) {
        result = record;
      }
    }
    return result;
  }

  List<WeightRecord> weightsForDate(String date) {
    final result = _weights.where((w) => w.date == date).toList();
    result.sort((a, b) => b.recordedAt.compareTo(a.recordedAt));
    return result;
  }

  double? weightForDate(String date) => lastRecordOnDate(date)?.weightKg;

  double? previousWeightBefore(String date) {
    WeightRecord? result;
    for (final record in _weights) {
      if (record.date.compareTo(date) >= 0) continue;
      if (result == null || record.recordedAt.isAfter(result.recordedAt)) {
        result = record;
      }
    }
    return result?.weightKg;
  }

  Future<void> addWeight(WeightRecord record) async {
    _weights.add(record);
    await _saveWeights();
    notifyListeners();
  }

  Future<void> updateWeight(WeightRecord record) async {
    final index = _weights.indexWhere((w) => w.id == record.id);
    if (index < 0) return;
    _weights[index] = record;
    await _saveWeights();
    notifyListeners();
  }

  Future<void> deleteWeight(String id) async {
    _weights.removeWhere((w) => w.id == id);
    await _saveWeights();
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // 食谱
  // ---------------------------------------------------------------------------

  Recipe? recipeById(String? id) {
    if (id == null) return null;
    for (final recipe in _recipes) {
      if (recipe.id == id) return recipe;
    }
    return null;
  }

  Future<void> addRecipe(Recipe recipe) async {
    _recipes.add(recipe);
    await _saveRecipes();
    notifyListeners();
  }

  Future<void> updateRecipe(Recipe recipe) async {
    final index = _recipes.indexWhere((r) => r.id == recipe.id);
    if (index < 0) return;
    _recipes[index] = recipe;
    await _saveRecipes();
    notifyListeners();
  }

  Future<void> toggleFavorite(String id) async {
    final index = _recipes.indexWhere((r) => r.id == id);
    if (index < 0) return;
    _recipes[index] = _recipes[index].copyWith(
      isFavorite: !_recipes[index].isFavorite,
    );
    await _saveRecipes();
    notifyListeners();
  }

  Future<void> deleteRecipe(String id) async {
    _recipes.removeWhere((r) => r.id == id && !r.isBuiltin);
    await _saveRecipes();
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // 长期食谱方案
  // ---------------------------------------------------------------------------

  Future<void> addDietPlan(DietPlan plan) async {
    _customPlans.add(plan.copyWith(isCustom: true));
    await _saveCustomPlans();
    notifyListeners();
  }

  Future<void> updateDietPlan(DietPlan plan) async {
    final index = _customPlans.indexWhere((item) => item.id == plan.id);
    if (index < 0) return;
    _customPlans[index] = plan.copyWith(isCustom: true);
    await _saveCustomPlans();
    notifyListeners();
  }

  Future<void> deleteDietPlan(String id) async {
    final before = _customPlans.length;
    _customPlans.removeWhere((plan) => plan.id == id);
    if (_customPlans.length == before) return;
    await _saveCustomPlans();
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // 饮食记录
  // ---------------------------------------------------------------------------

  List<MealEntry> entriesFor(String date, {String? mealType}) {
    final result = _entries
        .where(
          (e) => e.date == date && (mealType == null || e.mealType == mealType),
        )
        .toList();
    result.sort((a, b) {
      final orderA = _mealOrder.indexOf(a.mealType);
      final orderB = _mealOrder.indexOf(b.mealType);
      if (orderA != orderB) return orderA.compareTo(orderB);
      if (a.sortOrder != b.sortOrder) return a.sortOrder.compareTo(b.sortOrder);
      return a.id.compareTo(b.id);
    });
    return result;
  }

  int consumedKcalFor(String date) => entriesFor(
    date,
  ).where((e) => e.isCompleted).fold(0, (sum, e) => sum + e.calories);

  int plannedKcalFor(String date) =>
      entriesFor(date).fold(0, (sum, e) => sum + e.calories);

  Future<void> addMealEntry(MealEntry entry) async {
    _entries.add(entry);
    await _saveEntries();
    notifyListeners();
  }

  /// 批量加入一套长期方案的所有餐次，只写一次存储。
  Future<void> addMealEntries(Iterable<MealEntry> entries) async {
    final list = entries.toList(growable: false);
    if (list.isEmpty) return;
    _entries.addAll(list);
    await _saveEntries();
    notifyListeners();
  }

  Future<void> updateMealEntry(MealEntry entry) async {
    final index = _entries.indexWhere((e) => e.id == entry.id);
    if (index < 0) return;
    _entries[index] = entry;
    await _saveEntries();
    notifyListeners();
  }

  Future<void> deleteMealEntry(String id) async {
    _entries.removeWhere((e) => e.id == id);
    await _saveEntries();
    notifyListeners();
  }

  Future<void> deleteMealEntries(Iterable<String> ids) async {
    final set = ids.toSet();
    if (set.isEmpty) return;
    final before = _entries.length;
    _entries.removeWhere((e) => set.contains(e.id));
    if (_entries.length == before) return;
    await _saveEntries();
    notifyListeners();
  }

  Future<void> setEntryCompleted(String id, bool completed) async {
    final index = _entries.indexWhere((e) => e.id == id);
    if (index < 0) return;
    _entries[index] = _entries[index].copyWith(
      status: completed ? 'completed' : 'planned',
      completedAt: completed ? DateTime.now() : null,
    );
    await _saveEntries();
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // 喝水
  // ---------------------------------------------------------------------------

  List<WaterLog> waterFor(String date) {
    final result = _water.where((w) => w.date == date).toList();
    result.sort((a, b) => b.recordedAt.compareTo(a.recordedAt));
    return result;
  }

  int waterTotalFor(String date) =>
      _water.where((w) => w.date == date).fold(0, (sum, w) => sum + w.amountMl);

  Future<void> addWater(int amountMl, {DateTime? at}) async {
    final time = at ?? DateTime.now();
    _water.add(
      WaterLog(
        id: newId(),
        date: AppDate.key(time),
        amountMl: amountMl,
        recordedAt: time,
      ),
    );
    await _saveWater();
    notifyListeners();
  }

  Future<void> addWaterLog(WaterLog log) async {
    _water.add(log);
    await _saveWater();
    notifyListeners();
  }

  Future<void> deleteWater(String id) async {
    _water.removeWhere((w) => w.id == id);
    await _saveWater();
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // 运动
  // ---------------------------------------------------------------------------

  List<ExercisePlanEntry> exerciseEntriesFor(String date) {
    final result = _exerciseEntries
        .where((entry) => entry.date == date)
        .toList();
    result.sort((a, b) {
      final timeA = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final timeB = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return timeA.compareTo(timeB);
    });
    return result;
  }

  bool hasExerciseOnDate(String exerciseId, String date) => _exerciseEntries
      .any((entry) => entry.exerciseId == exerciseId && entry.date == date);

  Future<void> addExerciseEntry(ExercisePlanEntry entry) async {
    _exerciseEntries.add(entry);
    await _saveExercisePlan();
    notifyListeners();
  }

  Future<void> setExerciseCompleted(String id, bool completed) async {
    final index = _exerciseEntries.indexWhere((entry) => entry.id == id);
    if (index < 0) return;
    _exerciseEntries[index] = _exerciseEntries[index].copyWith(
      completed: completed,
      completedAt: completed ? DateTime.now() : null,
    );
    await _saveExercisePlan();
    notifyListeners();
  }

  Future<void> deleteExerciseEntry(String id) async {
    final before = _exerciseEntries.length;
    _exerciseEntries.removeWhere((entry) => entry.id == id);
    if (_exerciseEntries.length == before) return;
    await _saveExercisePlan();
    notifyListeners();
  }

  Future<void> toggleExerciseFavorite(String id) async {
    if (!_favoriteExercises.remove(id)) {
      _favoriteExercises.add(id);
    }
    await _saveExerciseFavorites();
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // 聚合
  // ---------------------------------------------------------------------------

  bool hasRecord(String date) =>
      _weights.any((w) => w.date == date) ||
      _entries.any((e) => e.date == date) ||
      _water.any((w) => w.date == date);

  int get streak {
    var day = AppDate.today();
    if (!hasRecord(AppDate.key(day))) {
      day = day.subtract(const Duration(days: 1));
    }
    var count = 0;
    while (hasRecord(AppDate.key(day))) {
      count++;
      day = day.subtract(const Duration(days: 1));
    }
    return count;
  }

  CaloriePlan get caloriePlan =>
      calculateCaloriePlan(profile: _profile, currentWeightKg: currentWeightKg);

  int get dailyBudget => caloriePlan.budget;

  int get waterGoal => _profile.waterGoalManual
      ? _profile.waterGoalMl
      : waterGoalFor(currentWeightKg);

  DaySummary summaryFor(String date) {
    return _buildSummary(
      date: date,
      entries: entriesFor(date),
      weightKg: weightForDate(date),
      waterMl: waterTotalFor(date),
    );
  }

  DaySummary _buildSummary({
    required String date,
    required List<MealEntry> entries,
    required double? weightKg,
    required int waterMl,
  }) {
    final byMeal = <String, List<MealEntry>>{};
    for (final entry in entries) {
      byMeal.putIfAbsent(entry.mealType, () => []).add(entry);
    }

    MealProgress progress(String type) {
      final list = byMeal[type] ?? const <MealEntry>[];
      return MealProgress(
        hasEntries: list.isNotEmpty,
        total: list.length,
        completed: list.where((e) => e.isCompleted).length,
      );
    }

    final completed = entries.where((e) => e.isCompleted).toList();
    return DaySummary(
      date: date,
      weightKg: weightKg,
      waterMl: waterMl,
      waterGoalMl: waterGoal,
      consumedKcal: completed.fold(0, (sum, e) => sum + e.calories),
      plannedKcal: entries.fold(0, (sum, e) => sum + e.calories),
      completedCount: completed.length,
      totalCount: entries.length,
      meals: {for (final type in _mealOrder) type: progress(type)},
    );
  }

  /// 一次性返回月历 42 天的摘要，避免每个单元格重复筛选。
  Map<String, DaySummary> summariesForMonth(DateTime month) {
    final weightsByDate = <String, WeightRecord>{};
    for (final record in _weights) {
      final existing = weightsByDate[record.date];
      if (existing == null || record.recordedAt.isAfter(existing.recordedAt)) {
        weightsByDate[record.date] = record;
      }
    }

    final entriesByDate = <String, List<MealEntry>>{};
    for (final entry in _entries) {
      entriesByDate.putIfAbsent(entry.date, () => []).add(entry);
    }

    final waterByDate = <String, int>{};
    for (final log in _water) {
      waterByDate[log.date] = (waterByDate[log.date] ?? 0) + log.amountMl;
    }

    final result = <String, DaySummary>{};
    for (final date in AppDate.monthGridDays(month, _profile.weekStart)) {
      final key = AppDate.key(date);
      result[key] = _buildSummary(
        date: key,
        entries: entriesByDate[key] ?? const <MealEntry>[],
        weightKg: weightsByDate[key]?.weightKg,
        waterMl: waterByDate[key] ?? 0,
      );
    }
    return result;
  }

  // ---------------------------------------------------------------------------
  // 导出与清理
  // ---------------------------------------------------------------------------

  String newId() => const Uuid().v4();

  String exportJson() {
    return const JsonEncoder.withIndent('  ').convert({
      'app': '小一二减肥记',
      'schemaVersion': 1,
      'exportedAt': DateTime.now().toIso8601String(),
      'profile': _profile.toJson(),
      'weights': _weights.map((e) => e.toJson()).toList(),
      'recipes': _recipes.map((e) => e.toJson()).toList(),
      'mealEntries': _entries.map((e) => e.toJson()).toList(),
      'waterLogs': _water.map((e) => e.toJson()).toList(),
      'customDietPlans': _customPlans.map((e) => e.toJson()).toList(),
      'exercisePlan': _exerciseEntries.map((e) => e.toJson()).toList(),
      'exerciseFavorites': _favoriteExercises.toList(growable: false),
    });
  }

  String exportWeightsCsv() {
    final rows = <List<Object?>>[
      ['日期', '时间', '体重(kg)', '体脂率(%)', '备注'],
      for (final record in _sortedWeights())
        [
          record.date,
          AppDate.timeLabel(record.recordedAt),
          record.weightKg.toStringAsFixed(1),
          record.bodyFatPct ?? '',
          record.note ?? '',
        ],
    ];
    return _csv(rows);
  }

  String exportMealsCsv() {
    final rows = <List<Object?>>[
      ['日期', '餐次', '名称', '热量(kcal)', '状态', '完成时间', '备注'],
      for (final entry in _entries)
        [
          entry.date,
          entry.mealType,
          entry.name,
          entry.calories,
          entry.status,
          entry.completedAt == null ? '' : entry.completedAt!.toIso8601String(),
          entry.note ?? '',
        ],
    ];
    rows.sort((a, b) => '${a[0]}'.compareTo('${b[0]}'));
    return _csv(rows);
  }

  String exportWaterCsv() {
    final rows = <List<Object?>>[
      ['日期', '时间', '水量(ml)'],
      for (final log in _water)
        [log.date, AppDate.timeLabel(log.recordedAt), log.amountMl],
    ];
    rows.sort((a, b) {
      final byDate = '${a[0]}'.compareTo('${b[0]}');
      if (byDate != 0) return byDate;
      return '${a[1]}'.compareTo('${b[1]}');
    });
    return _csv(rows);
  }

  String _csv(List<List<Object?>> rows) {
    final buffer = StringBuffer('﻿');
    for (final row in rows) {
      buffer.writeln(row.map(_csvCell).join(','));
    }
    return buffer.toString();
  }

  String _csvCell(Object? value) {
    final text = value == null ? '' : '$value';
    if (text.contains(',') || text.contains('"') || text.contains('\n')) {
      return '"${text.replaceAll('"', '""')}"';
    }
    return text;
  }

  Future<void> clearBusinessData() async {
    _weights.clear();
    _entries.clear();
    _water.clear();
    _exerciseEntries.clear();
    await _saveWeights();
    await _saveEntries();
    await _saveWater();
    await _saveExercisePlan();
    notifyListeners();
  }

  Future<void> factoryReset() async {
    _weights.clear();
    _entries.clear();
    _water.clear();
    _recipes.clear();
    _customPlans.clear();
    _exerciseEntries.clear();
    _favoriteExercises.clear();
    _profile = const Profile();
    await _prefs?.clear();
    await _prefs?.setInt(_kSeedVersion, 0);
    await _seedIfNeeded();
    await _saveProfile();
    notifyListeners();
  }
}
