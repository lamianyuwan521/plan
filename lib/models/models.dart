/// 领域模型。全部模型都可序列化为 JSON，便于本地存储与导出。
library;

const Object _unset = Object();

double _asDouble(Object? value, [double fallback = 0]) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? fallback;
  return fallback;
}

int _asInt(Object? value, [int fallback = 0]) {
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? fallback;
  return fallback;
}

String _asString(Object? value, [String fallback = '']) {
  if (value is String) return value;
  if (value == null) return fallback;
  return '$value';
}

List<String> _asStringList(Object? value) {
  if (value is List) {
    return value.map((e) => '$e').toList(growable: false);
  }
  return const <String>[];
}

class Profile {
  const Profile({
    this.nickname = '小一二',
    this.gender = 'female',
    this.birthYear = 1998,
    this.heightCm = 165,
    this.activityLevel = 'light',
    this.weightUnit = 'kg',
    this.startWeightKg = 60,
    this.targetWeightKg,
    this.targetDate,
    this.weeklyRateKg = 0.5,
    this.calorieBudgetOverride,
    this.waterGoalMl = 2000,
    this.waterGoalManual = false,
    this.themeMode = 'system',
    this.weekStart = 1,
    this.startPage = 'today',
    this.sidebarExpanded = true,
    this.onboardingDone = false,
  });

  final String nickname;
  final String gender; // female / male / unknown
  final int birthYear;
  final double heightCm;
  final String activityLevel; // sedentary / light / moderate / active
  final String weightUnit; // kg / jin
  final double startWeightKg;
  final double? targetWeightKg;
  final String? targetDate;
  final double weeklyRateKg;
  final int? calorieBudgetOverride;
  final int waterGoalMl;
  final bool waterGoalManual;
  final String themeMode; // system / light / dark
  final int weekStart; // 1 = 周一, 7 = 周日
  final String startPage; // today / recipes
  final bool sidebarExpanded;
  final bool onboardingDone;

  int get age {
    final year = DateTime.now().year - birthYear;
    return year < 0 ? 0 : year;
  }

  Profile copyWith({
    String? nickname,
    String? gender,
    int? birthYear,
    double? heightCm,
    String? activityLevel,
    String? weightUnit,
    double? startWeightKg,
    Object? targetWeightKg = _unset,
    Object? targetDate = _unset,
    double? weeklyRateKg,
    Object? calorieBudgetOverride = _unset,
    int? waterGoalMl,
    bool? waterGoalManual,
    String? themeMode,
    int? weekStart,
    String? startPage,
    bool? sidebarExpanded,
    bool? onboardingDone,
  }) {
    return Profile(
      nickname: nickname ?? this.nickname,
      gender: gender ?? this.gender,
      birthYear: birthYear ?? this.birthYear,
      heightCm: heightCm ?? this.heightCm,
      activityLevel: activityLevel ?? this.activityLevel,
      weightUnit: weightUnit ?? this.weightUnit,
      startWeightKg: startWeightKg ?? this.startWeightKg,
      targetWeightKg: identical(targetWeightKg, _unset)
          ? this.targetWeightKg
          : (targetWeightKg as num?)?.toDouble(),
      targetDate:
          identical(targetDate, _unset) ? this.targetDate : targetDate as String?,
      weeklyRateKg: weeklyRateKg ?? this.weeklyRateKg,
      calorieBudgetOverride: identical(calorieBudgetOverride, _unset)
          ? this.calorieBudgetOverride
          : (calorieBudgetOverride as num?)?.toInt(),
      waterGoalMl: waterGoalMl ?? this.waterGoalMl,
      waterGoalManual: waterGoalManual ?? this.waterGoalManual,
      themeMode: themeMode ?? this.themeMode,
      weekStart: weekStart ?? this.weekStart,
      startPage: startPage ?? this.startPage,
      sidebarExpanded: sidebarExpanded ?? this.sidebarExpanded,
      onboardingDone: onboardingDone ?? this.onboardingDone,
    );
  }

  Map<String, dynamic> toJson() => {
        'nickname': nickname,
        'gender': gender,
        'birthYear': birthYear,
        'heightCm': heightCm,
        'activityLevel': activityLevel,
        'weightUnit': weightUnit,
        'startWeightKg': startWeightKg,
        'targetWeightKg': targetWeightKg,
        'targetDate': targetDate,
        'weeklyRateKg': weeklyRateKg,
        'calorieBudgetOverride': calorieBudgetOverride,
        'waterGoalMl': waterGoalMl,
        'waterGoalManual': waterGoalManual,
        'themeMode': themeMode,
        'weekStart': weekStart,
        'startPage': startPage,
        'sidebarExpanded': sidebarExpanded,
        'onboardingDone': onboardingDone,
      };

  factory Profile.fromJson(Map<String, dynamic> json) {
    return Profile(
      nickname: _asString(json['nickname'], '小一二'),
      gender: _asString(json['gender'], 'female'),
      birthYear: _asInt(json['birthYear'], 1998),
      heightCm: _asDouble(json['heightCm'], 165),
      activityLevel: _asString(json['activityLevel'], 'light'),
      weightUnit: _asString(json['weightUnit'], 'kg'),
      startWeightKg: _asDouble(json['startWeightKg'], 60),
      targetWeightKg: json['targetWeightKg'] == null
          ? null
          : _asDouble(json['targetWeightKg']),
      targetDate: json['targetDate'] as String?,
      weeklyRateKg: _asDouble(json['weeklyRateKg'], 0.5),
      calorieBudgetOverride: json['calorieBudgetOverride'] == null
          ? null
          : _asInt(json['calorieBudgetOverride']),
      waterGoalMl: _asInt(json['waterGoalMl'], 2000),
      waterGoalManual: json['waterGoalManual'] == true,
      themeMode: _asString(json['themeMode'], 'system'),
      weekStart: _asInt(json['weekStart'], 1),
      startPage: _asString(json['startPage'], 'today'),
      sidebarExpanded: json['sidebarExpanded'] != false,
      onboardingDone: json['onboardingDone'] == true,
    );
  }
}

class WeightRecord {
  const WeightRecord({
    required this.id,
    required this.date,
    required this.recordedAt,
    required this.weightKg,
    this.bodyFatPct,
    this.note,
  });

  final String id;
  final String date; // yyyy-MM-dd
  final DateTime recordedAt;
  final double weightKg;
  final double? bodyFatPct;
  final String? note;

  WeightRecord copyWith({
    String? date,
    DateTime? recordedAt,
    double? weightKg,
    Object? bodyFatPct = _unset,
    Object? note = _unset,
  }) {
    return WeightRecord(
      id: id,
      date: date ?? this.date,
      recordedAt: recordedAt ?? this.recordedAt,
      weightKg: weightKg ?? this.weightKg,
      bodyFatPct: identical(bodyFatPct, _unset)
          ? this.bodyFatPct
          : (bodyFatPct as num?)?.toDouble(),
      note: identical(note, _unset) ? this.note : note as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'date': date,
        'recordedAt': recordedAt.toIso8601String(),
        'weightKg': weightKg,
        'bodyFatPct': bodyFatPct,
        'note': note,
      };

  factory WeightRecord.fromJson(Map<String, dynamic> json) {
    return WeightRecord(
      id: _asString(json['id']),
      date: _asString(json['date']),
      recordedAt:
          DateTime.tryParse(_asString(json['recordedAt'])) ?? DateTime.now(),
      weightKg: _asDouble(json['weightKg']),
      bodyFatPct:
          json['bodyFatPct'] == null ? null : _asDouble(json['bodyFatPct']),
      note: json['note'] as String?,
    );
  }
}

class Ingredient {
  const Ingredient({
    required this.name,
    this.amount = 0,
    this.unit = 'g',
    this.kcal,
  });

  final String name;
  final double amount;
  final String unit;
  final int? kcal;

  Map<String, dynamic> toJson() => {
        'name': name,
        'amount': amount,
        'unit': unit,
        'kcal': kcal,
      };

  factory Ingredient.fromJson(Map<String, dynamic> json) {
    return Ingredient(
      name: _asString(json['name']),
      amount: _asDouble(json['amount']),
      unit: _asString(json['unit'], 'g'),
      kcal: json['kcal'] == null ? null : _asInt(json['kcal']),
    );
  }
}

class Recipe {
  const Recipe({
    required this.id,
    required this.name,
    required this.mealType,
    required this.calories,
    this.ingredients = const <Ingredient>[],
    this.steps = const <String>[],
    this.tags = const <String>[],
    this.isBuiltin = false,
    this.isFavorite = false,
  });

  final String id;
  final String name;
  final String mealType; // breakfast / lunch / dinner / snack / any
  final int calories;
  final List<Ingredient> ingredients;
  final List<String> steps;
  final List<String> tags;
  final bool isBuiltin;
  final bool isFavorite;

  Recipe copyWith({
    String? name,
    String? mealType,
    int? calories,
    List<Ingredient>? ingredients,
    List<String>? steps,
    List<String>? tags,
    bool? isBuiltin,
    bool? isFavorite,
  }) {
    return Recipe(
      id: id,
      name: name ?? this.name,
      mealType: mealType ?? this.mealType,
      calories: calories ?? this.calories,
      ingredients: ingredients ?? this.ingredients,
      steps: steps ?? this.steps,
      tags: tags ?? this.tags,
      isBuiltin: isBuiltin ?? this.isBuiltin,
      isFavorite: isFavorite ?? this.isFavorite,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'mealType': mealType,
        'calories': calories,
        'ingredients': ingredients.map((e) => e.toJson()).toList(),
        'steps': steps,
        'tags': tags,
        'isBuiltin': isBuiltin,
        'isFavorite': isFavorite,
      };

  factory Recipe.fromJson(Map<String, dynamic> json) {
    final rawIngredients = json['ingredients'];
    final ingredients = <Ingredient>[];
    if (rawIngredients is List) {
      for (final item in rawIngredients) {
        if (item is Map) {
          ingredients.add(Ingredient.fromJson(Map<String, dynamic>.from(item)));
        }
      }
    }
    return Recipe(
      id: _asString(json['id']),
      name: _asString(json['name']),
      mealType: _asString(json['mealType'], 'any'),
      calories: _asInt(json['calories']),
      ingredients: ingredients,
      steps: _asStringList(json['steps']),
      tags: _asStringList(json['tags']),
      isBuiltin: json['isBuiltin'] == true,
      isFavorite: json['isFavorite'] == true,
    );
  }
}

class MealEntry {
  const MealEntry({
    required this.id,
    required this.date,
    required this.mealType,
    required this.name,
    required this.calories,
    this.recipeId,
    this.portion = 1,
    this.status = 'planned',
    this.completedAt,
    this.note,
    this.sortOrder = 0,
  });

  final String id;
  final String date;
  final String mealType; // breakfast / lunch / dinner / snack
  final String? recipeId;
  final String name;
  final int calories;
  final double portion;
  final String status; // planned / completed
  final DateTime? completedAt;
  final String? note;
  final int sortOrder;

  bool get isCompleted => status == 'completed';

  MealEntry copyWith({
    String? date,
    String? mealType,
    Object? recipeId = _unset,
    String? name,
    int? calories,
    double? portion,
    String? status,
    Object? completedAt = _unset,
    Object? note = _unset,
    int? sortOrder,
  }) {
    return MealEntry(
      id: id,
      date: date ?? this.date,
      mealType: mealType ?? this.mealType,
      recipeId:
          identical(recipeId, _unset) ? this.recipeId : recipeId as String?,
      name: name ?? this.name,
      calories: calories ?? this.calories,
      portion: portion ?? this.portion,
      status: status ?? this.status,
      completedAt: identical(completedAt, _unset)
          ? this.completedAt
          : completedAt as DateTime?,
      note: identical(note, _unset) ? this.note : note as String?,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'date': date,
        'mealType': mealType,
        'recipeId': recipeId,
        'name': name,
        'calories': calories,
        'portion': portion,
        'status': status,
        'completedAt': completedAt?.toIso8601String(),
        'note': note,
        'sortOrder': sortOrder,
      };

  factory MealEntry.fromJson(Map<String, dynamic> json) {
    return MealEntry(
      id: _asString(json['id']),
      date: _asString(json['date']),
      mealType: _asString(json['mealType'], 'breakfast'),
      recipeId: json['recipeId'] as String?,
      name: _asString(json['name']),
      calories: _asInt(json['calories']),
      portion: _asDouble(json['portion'], 1),
      status: _asString(json['status'], 'planned'),
      completedAt: json['completedAt'] == null
          ? null
          : DateTime.tryParse(_asString(json['completedAt'])),
      note: json['note'] as String?,
      sortOrder: _asInt(json['sortOrder']),
    );
  }
}

class WaterLog {
  const WaterLog({
    required this.id,
    required this.date,
    required this.amountMl,
    required this.recordedAt,
  });

  final String id;
  final String date;
  final int amountMl;
  final DateTime recordedAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'date': date,
        'amountMl': amountMl,
        'recordedAt': recordedAt.toIso8601String(),
      };

  factory WaterLog.fromJson(Map<String, dynamic> json) {
    return WaterLog(
      id: _asString(json['id']),
      date: _asString(json['date']),
      amountMl: _asInt(json['amountMl']),
      recordedAt:
          DateTime.tryParse(_asString(json['recordedAt'])) ?? DateTime.now(),
    );
  }
}

/// 长期方案里的一餐。方案是内置模板，热量为估算值。
class PlanMeal {
  const PlanMeal({
    required this.mealType,
    required this.name,
    required this.calories,
  });

  final String mealType; // breakfast / lunch / dinner
  final String name;
  final int calories;
}

class PlanDay {
  const PlanDay({required this.meals, this.weightJin, this.note});

  final List<PlanMeal> meals;

  /// 方案记录里留下来的参考体重，单位为斤。
  final double? weightJin;
  final String? note;

  int get calories => meals.fold<int>(0, (sum, meal) => sum + meal.calories);

  PlanMeal? mealOf(String mealType) {
    for (final meal in meals) {
      if (meal.mealType == mealType) return meal;
    }
    return null;
  }
}

/// 内置的多日食谱方案，例如「7 天极速掉秤」。
class DietPlan {
  const DietPlan({
    required this.id,
    required this.name,
    required this.description,
    required this.tags,
    required this.days,
  });

  final String id;
  final String name;
  final String description;
  final List<String> tags;
  final List<PlanDay> days;

  int get totalCalories => days.fold<int>(0, (sum, day) => sum + day.calories);

  int get averageCalories =>
      days.isEmpty ? 0 : (totalCalories / days.length).round();

  int get mealCount => days.fold<int>(0, (sum, day) => sum + day.meals.length);
}

class MealProgress {
  const MealProgress({
    required this.hasEntries,
    required this.total,
    required this.completed,
  });

  final bool hasEntries;
  final int total;
  final int completed;

  bool get allDone => hasEntries && total > 0 && completed == total;
}

class DaySummary {
  const DaySummary({
    required this.date,
    required this.weightKg,
    required this.waterMl,
    required this.waterGoalMl,
    required this.consumedKcal,
    required this.plannedKcal,
    required this.completedCount,
    required this.totalCount,
    required this.meals,
  });

  final String date;
  final double? weightKg;
  final int waterMl;
  final int waterGoalMl;
  final int consumedKcal;
  final int plannedKcal;
  final int completedCount;
  final int totalCount;
  final Map<String, MealProgress> meals;

  bool get waterGoalMet => waterMl >= waterGoalMl && waterGoalMl > 0;

  bool get hasAny =>
      weightKg != null || totalCount > 0 || waterMl > 0;
}
