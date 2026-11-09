import 'dart:convert';

import '../data/food_catalog.dart';
import '../models/basket.dart';
import '../models/models.dart';

/// 按菜篮子余量估出来的一份多日食谱。天数由余量热量决定，不由模型随意加长。
class BasketPlanDraft {
  const BasketPlanDraft({
    required this.days,
    required this.shopping,
    required this.usages,
    required this.summary,
    required this.supportedDays,
    required this.calorieCap,
    required this.fromAi,
  });

  final List<PlanDay> days;
  final List<BasketShopping> shopping;
  final List<BasketUsage> usages;
  final String summary;
  final int supportedDays;
  final int calorieCap;
  final bool fromAi;

  bool get canSave => days.any((day) => day.meals.isNotEmpty);

  String get description {
    if (shopping.isEmpty) return summary;
    final lines = shopping.map((item) => item.label).join('、');
    return '$summary\n建议额外购买：$lines';
  }

  BasketPlanDraft copyWith({
    List<PlanDay>? days,
    List<BasketShopping>? shopping,
    List<BasketUsage>? usages,
    String? summary,
    int? supportedDays,
    bool? fromAi,
  }) {
    return BasketPlanDraft(
      days: days ?? this.days,
      shopping: shopping ?? this.shopping,
      usages: usages ?? this.usages,
      summary: summary ?? this.summary,
      supportedDays: supportedDays ?? this.supportedDays,
      calorieCap: calorieCap,
      fromAi: fromAi ?? this.fromAi,
    );
  }
}

class BasketShopping {
  const BasketShopping({
    required this.name,
    required this.amount,
    required this.unit,
    required this.reason,
    required this.calories,
  });

  final String name;
  final double amount;
  final String unit;
  final String reason;
  final int calories;

  String get label => '$name ${formatAmount(amount)}$unit（$reason）';
}

int normalizeCalorieCap(int calorieCap) => calorieCap.clamp(500, 4000);

/// 用家里现有的量排食谱。凑不满一天时，只建议额外买一点，而不是把热量硬填满。
BasketPlanDraft buildLocalBasketPlan(List<BasketItem> items, int calorieCap) {
  final cap = normalizeCalorieCap(calorieCap);
  final pools = <_Pool>[
    for (final item in items)
      if (item.estimatedKcal > 0 && item.amount > 0) _Pool(item),
  ];
  final ignored = items
      .where((item) => item.amount > 0 && item.estimatedKcal <= 0)
      .length;
  final stockKcal = pools.fold<int>(0, (sum, pool) => sum + pool.leftKcal);
  final days = <PlanDay>[];
  final usageMap = <String, _UsageAcc>{};
  var supported = 0;

  for (var index = 0; index < 14; index++) {
    final before = {for (final pool in pools) pool.id: pool.left};
    final built = _buildDay(pools, cap);
    final full =
        built.day.meals.isNotEmpty && built.day.calories >= (cap * 0.8).round();
    if (full) {
      supported++;
      days.add(built.day);
      _collectUsage(usageMap, pools, before);
      continue;
    }
    if (days.isEmpty) {
      final shopping = _modestShopping(built, cap);
      final meals = _mergeShopping(built.day.meals, shopping, cap);
      _collectUsage(usageMap, pools, before);
      return BasketPlanDraft(
        days: meals.isEmpty ? const <PlanDay>[] : [PlanDay(meals: meals)],
        shopping: shopping,
        usages: _usageList(usageMap),
        summary: _shortSummary(stockKcal, cap, ignored),
        supportedDays: 0,
        calorieCap: cap,
        fromAi: false,
      );
    }
    _restore(pools, before);
    break;
  }

  final shopping = _optionalShopping(days);
  return BasketPlanDraft(
    days: days,
    shopping: shopping,
    usages: _usageList(usageMap),
    summary: _fullSummary(supported, cap, ignored, shopping.isNotEmpty),
    supportedDays: supported,
    calorieCap: cap,
    fromAi: false,
  );
}

String buildBasketPlanPrompt({
  required List<BasketItem> items,
  required int calorieCap,
  required int supportedDays,
}) {
  final cap = normalizeCalorieCap(calorieCap);
  final buffer = StringBuffer()
    ..writeln('你是小一二减肥记里的食谱助手。根据用户菜篮子的余量，生成家常、能在家做的减脂食谱。')
    ..writeln('每天三餐合计必须不超过 $cap kcal，可以低于这个数，不能超过。')
    ..writeln(
      supportedDays <= 0
          ? '现有食材凑不齐 1 天。只生成 1 天：优先用完已有食材，不够的部分在 shopping 里建议少量额外购买（每种大约一餐的量），并写进当天菜名。'
          : '现有食材大约能支撑 $supportedDays 天。只生成 $supportedDays 天，不要更多。各天用量加起来不能超过余量。只有某一类完全没有（例如没有蔬菜）时，才在 shopping 里写可选补充，reason 以「可选」开头。',
    )
    ..writeln('菜篮子：');
  for (final item in items) {
    buffer.writeln(
      '- ${item.name}｜${item.amountLabel}｜${foodCategoryName(item.categoryId)}｜约 ${item.estimatedKcal} kcal｜id:${item.id}',
    );
  }
  buffer
    ..writeln('只输出一个 JSON 对象，不要 Markdown，不要解释。格式：')
    ..writeln(
      '{"summary":"一句话","shopping":[{"name":"西兰花","amount":200,"unit":"g","reason":"补一点蔬菜"}],"usages":[{"id":"食材id","amount":80}],"days":[{"meals":[{"mealType":"breakfast","name":"菜名","calories":300},{"mealType":"lunch","name":"菜名","calories":450},{"mealType":"dinner","name":"菜名","calories":450}]}]}',
    )
    ..writeln(
      'mealType 只能是 breakfast、lunch、dinner、snack。usages.amount 使用菜篮子里的单位，且不能超过该食材余量。热量是估算。',
    );
  return buffer.toString();
}

/// 把模型输出收成一份不超过余量天数、且每天不超热量上限的食谱。解析失败时返回 null。
BasketPlanDraft? parseAiBasketPlan(
  String raw, {
  required List<BasketItem> items,
  required int calorieCap,
  required int supportedDays,
  required String fallbackSummary,
}) {
  final cap = normalizeCalorieCap(calorieCap);
  final jsonText = _extractJsonObject(raw);
  if (jsonText == null) return null;
  final Object? decoded;
  try {
    decoded = _decodeJson(jsonText);
  } on FormatException {
    return null;
  }
  if (decoded is! Map) return null;
  final maxDays = supportedDays <= 0 ? 1 : supportedDays;
  final days = <PlanDay>[];
  final rawDays = decoded['days'];
  if (rawDays is List) {
    for (final item in rawDays) {
      if (days.length >= maxDays) break;
      if (item is! Map) continue;
      final meals = <PlanMeal>[];
      final rawMeals = item['meals'];
      if (rawMeals is List) {
        for (final meal in rawMeals) {
          if (meal is! Map) continue;
          final type = _normalizeMeal('${meal['mealType']}');
          final name = '${meal['name']}'.trim();
          final calories = _asInt(meal['calories']);
          if (type == null || name.isEmpty || calories <= 0) continue;
          meals.add(
            PlanMeal(
              mealType: type,
              name: name.length > 48 ? '${name.substring(0, 48)}…' : name,
              calories: calories > 2000 ? 2000 : calories,
            ),
          );
        }
      }
      if (meals.isEmpty) continue;
      days.add(PlanDay(meals: _fitCap(_ordered(meals), cap)));
    }
  }
  if (days.isEmpty) return null;

  final shopping = <BasketShopping>[];
  final rawShopping = decoded['shopping'];
  if (rawShopping is List) {
    for (final item in rawShopping) {
      if (item is! Map) continue;
      final name = '${item['name']}'.trim();
      final unit = '${item['unit']}'.trim();
      final reason = '${item['reason']}'.trim();
      final amount = _asDouble(item['amount']);
      if (name.isEmpty || amount <= 0) continue;
      shopping.add(
        BasketShopping(
          name: name,
          amount: amount,
          unit: unit.isEmpty ? 'g' : unit,
          reason: reason.isEmpty ? '额外购买' : reason,
          calories: 0,
        ),
      );
    }
  }

  final byId = {for (final item in items) item.id: item};
  final usages = <BasketUsage>[];
  final rawUsages = decoded['usages'];
  if (rawUsages is List) {
    for (final item in rawUsages) {
      if (item is! Map) continue;
      final id = '${item['id']}'.trim();
      final source = byId[id];
      if (source == null) continue;
      var amount = _asDouble(item['amount']);
      if (amount <= 0) continue;
      if (amount > source.amount) amount = source.amount;
      usages.add(
        BasketUsage(
          itemId: source.id,
          name: source.name,
          amount: amount,
          unit: source.unit,
        ),
      );
    }
  }

  final summary = '${decoded['summary']}'.trim();
  return BasketPlanDraft(
    days: days,
    shopping: shopping,
    usages: usages,
    summary: summary.isEmpty ? fallbackSummary : summary,
    supportedDays: supportedDays < 0 ? 0 : supportedDays,
    calorieCap: cap,
    fromAi: true,
  );
}

String? _extractJsonObject(String raw) {
  final trimmed = raw.trim();
  final start = trimmed.indexOf('{');
  final end = trimmed.lastIndexOf('}');
  if (start < 0 || end <= start) return null;
  return trimmed.substring(start, end + 1);
}

Object? _decodeJson(String raw) => jsonDecode(raw);

class _Pool {
  _Pool(BasketItem item)
    : id = item.id,
      name = item.name,
      categoryId = item.categoryId,
      unit = item.unit,
      kcalPerUnit = _kcalPerUnit(item),
      left = item.amount;

  final String id;
  final String name;
  final String categoryId;
  final String unit;
  final double kcalPerUnit;
  double left;

  int get leftKcal => kcalPerUnit <= 0 ? 0 : (left * kcalPerUnit).round();
}

class _Bite {
  const _Bite({required this.pool, required this.amount, required this.kcal});

  final _Pool pool;
  final double amount;
  final int kcal;

  String get label => '${pool.name} ${formatAmount(amount)}${pool.unit}';
}

class _DayBuild {
  const _DayBuild({required this.day, required this.bites});

  final PlanDay day;
  final List<_Bite> bites;
}

class _UsageAcc {
  _UsageAcc(this.pool);

  final _Pool pool;
  double amount = 0;
}

double _kcalPerUnit(BasketItem item) {
  final basis = item.kcal ?? 0;
  if (basis <= 0) return 0;
  if (kcalIsPer100(item.unit)) return basis / 100;
  return basis.toDouble();
}

_DayBuild _buildDay(List<_Pool> pools, int cap) {
  final breakfast = <_Bite>[
    ..._fill(
      pools,
      (pool) => pool.categoryId == 'eggDairy',
      (cap * 0.10).round(),
    ),
    ..._fill(pools, _isGrain, (cap * 0.14).round()),
    ..._fill(pools, _isFruit, (cap * 0.06).round()),
  ];
  final lunch = <_Bite>[
    ..._fill(pools, _isProteinPool, (cap * 0.16).round()),
    ..._fill(pools, _isGrain, (cap * 0.12).round()),
    ..._fill(pools, _isVeg, (cap * 0.06).round()),
  ];
  final dinner = <_Bite>[
    ..._fill(pools, _isProteinPool, (cap * 0.14).round()),
    ..._fill(pools, _isVeg, (cap * 0.06).round()),
    ..._fill(pools, _isGrain, (cap * 0.06).round()),
  ];
  final used = [
    ...breakfast,
    ...lunch,
    ...dinner,
  ].fold<int>(0, (sum, bite) => sum + bite.kcal);
  final snack = _fill(pools, (_) => true, cap - used);
  final bites = [...breakfast, ...lunch, ...dinner, ...snack];
  final meals = _fitCap(
    _ordered(
      [
        if (breakfast.isNotEmpty) _meal('breakfast', breakfast),
        if (lunch.isNotEmpty) _meal('lunch', lunch),
        if (dinner.isNotEmpty) _meal('dinner', dinner),
        if (snack.isNotEmpty) _meal('snack', snack),
      ].whereType<PlanMeal>().toList(),
    ),
    cap,
  );
  return _DayBuild(
    day: PlanDay(meals: meals),
    bites: bites,
  );
}

PlanMeal? _meal(String type, List<_Bite> bites) {
  if (bites.isEmpty) return null;
  final name = bites.map((bite) => bite.label).join('、');
  return PlanMeal(
    mealType: type,
    name: name.length > 48 ? '${name.substring(0, 48)}…' : name,
    calories: bites.fold<int>(0, (sum, bite) => sum + bite.kcal),
  );
}

List<_Bite> _fill(
  List<_Pool> pools,
  bool Function(_Pool pool) match,
  int target,
) {
  final bites = <_Bite>[];
  var remain = target;
  if (remain < 30) return bites;
  for (final pool in pools) {
    if (remain < 30) break;
    if (!match(pool)) continue;
    final bite = _take(pool, remain);
    if (bite == null) continue;
    bites.add(bite);
    remain -= bite.kcal;
  }
  return bites;
}

_Bite? _take(_Pool pool, int targetKcal) {
  if (targetKcal < 20 || pool.left <= 0 || pool.kcalPerUnit <= 0) return null;
  var amount = targetKcal / pool.kcalPerUnit;
  if (pool.unit == 'g' || pool.unit == 'ml') {
    amount = (amount / 5).floor() * 5;
    if (amount < 10) amount = pool.left >= 10 ? 10 : pool.left;
  } else {
    amount = (amount * 2).floor() / 2;
    if (amount < 0.5) amount = pool.left >= 0.5 ? 0.5 : pool.left;
  }
  if (amount > pool.left) amount = pool.left;
  if (amount <= 0) return null;
  var kcal = (amount * pool.kcalPerUnit).round();
  if (kcal > targetKcal) {
    amount = targetKcal / pool.kcalPerUnit;
    if (amount > pool.left) amount = pool.left;
    kcal = (amount * pool.kcalPerUnit).round();
  }
  if (kcal < 15 || amount <= 0) return null;
  pool.left = (pool.left - amount).clamp(0, double.infinity);
  return _Bite(pool: pool, amount: amount, kcal: kcal);
}

List<BasketShopping> _modestShopping(_DayBuild built, int cap) {
  final shopping = <BasketShopping>[];
  final hasProtein = built.bites.any(
    (bite) => _isProtein(bite.pool.categoryId),
  );
  final hasGrain = built.bites.any((bite) => _isGrain(bite.pool));
  final hasVeg = built.bites.any((bite) => _isVeg(bite.pool));
  var extra = 0;

  void add({
    required String name,
    required double amount,
    required String unit,
    required int calories,
    required String reason,
  }) {
    final room = cap - built.day.calories - extra;
    if (room < 40) return;
    var nextAmount = amount;
    var nextKcal = calories;
    if (nextKcal > room) {
      nextAmount = amount * room / calories;
      nextKcal = room;
    }
    if (nextKcal < 20 || nextAmount <= 0) return;
    extra += nextKcal;
    shopping.add(
      BasketShopping(
        name: name,
        amount: nextAmount,
        unit: unit,
        reason: reason,
        calories: nextKcal,
      ),
    );
  }

  if (!hasGrain) {
    add(name: '糙米', amount: 80, unit: 'g', calories: 89, reason: '补一点主食');
  }
  if (!hasProtein) {
    add(name: '鸡胸肉', amount: 120, unit: 'g', calories: 160, reason: '补一点蛋白质');
  }
  if (!hasVeg) {
    add(name: '西兰花', amount: 200, unit: 'g', calories: 68, reason: '补一点蔬菜');
  }
  return shopping;
}

List<BasketShopping> _optionalShopping(List<PlanDay> days) {
  if (days.isEmpty) return const <BasketShopping>[];
  final text = days
      .expand((day) => day.meals)
      .map((meal) => meal.name)
      .join(' ');
  final shopping = <BasketShopping>[];
  const proteins = ['鸡胸', '牛肉', '猪肉', '羊肉', '鱼', '虾', '蛋', '豆腐', '豆浆'];
  const vegetables = ['西兰花', '菠菜', '番茄', '黄瓜', '生菜', '菜', '菇', '木耳', '海带'];
  final hasProtein = proteins.any(text.contains);
  final hasVeg = vegetables.any(text.contains);
  if (!hasProtein) {
    shopping.add(
      const BasketShopping(
        name: '鸡胸肉',
        amount: 120,
        unit: 'g',
        reason: '可选，补一点蛋白质',
        calories: 160,
      ),
    );
  }
  if (!hasVeg) {
    shopping.add(
      const BasketShopping(
        name: '西兰花',
        amount: 200,
        unit: 'g',
        reason: '可选，热量够用也可以再买一点蔬菜',
        calories: 68,
      ),
    );
  }
  return shopping;
}

List<PlanMeal> _mergeShopping(
  List<PlanMeal> meals,
  List<BasketShopping> shopping,
  int cap,
) {
  final result = [...meals];
  for (final item in shopping) {
    if (item.calories <= 0) continue;
    final type = item.reason.contains('主食')
        ? 'breakfast'
        : item.reason.contains('蛋白')
        ? 'lunch'
        : 'dinner';
    final piece = '${item.name} ${formatAmount(item.amount)}${item.unit}';
    final index = result.indexWhere((meal) => meal.mealType == type);
    if (index < 0) {
      result.add(
        PlanMeal(mealType: type, name: piece, calories: item.calories),
      );
    } else {
      final meal = result[index];
      final name = '${meal.name}、$piece';
      result[index] = PlanMeal(
        mealType: type,
        name: name.length > 48 ? '${name.substring(0, 48)}…' : name,
        calories: meal.calories + item.calories,
      );
    }
  }
  return _fitCap(_ordered(result), cap);
}

List<PlanMeal> _fitCap(List<PlanMeal> meals, int cap) {
  final total = meals.fold<int>(0, (sum, meal) => sum + meal.calories);
  if (total <= cap || total == 0) return meals;
  final ratio = cap / total;
  final scaled = <PlanMeal>[];
  var used = 0;
  for (var index = 0; index < meals.length; index++) {
    final meal = meals[index];
    final kcal = index == meals.length - 1
        ? cap - used
        : (meal.calories * ratio).round();
    if (kcal <= 0) continue;
    used += kcal;
    scaled.add(
      PlanMeal(mealType: meal.mealType, name: meal.name, calories: kcal),
    );
  }
  return scaled;
}

List<PlanMeal> _ordered(List<PlanMeal> meals) {
  const order = ['breakfast', 'lunch', 'dinner', 'snack'];
  final copy = [...meals];
  copy.sort(
    (a, b) => order.indexOf(a.mealType).compareTo(order.indexOf(b.mealType)),
  );
  return copy;
}

void _collectUsage(
  Map<String, _UsageAcc> usages,
  List<_Pool> pools,
  Map<String, double> before,
) {
  for (final pool in pools) {
    final used = (before[pool.id] ?? pool.left) - pool.left;
    if (used <= 0.05) continue;
    final acc = usages.putIfAbsent(pool.id, () => _UsageAcc(pool));
    acc.amount += used;
  }
}

void _restore(List<_Pool> pools, Map<String, double> before) {
  for (final pool in pools) {
    pool.left = before[pool.id] ?? pool.left;
  }
}

List<BasketUsage> _usageList(Map<String, _UsageAcc> usages) {
  return [
    for (final acc in usages.values)
      BasketUsage(
        itemId: acc.pool.id,
        name: acc.pool.name,
        amount: acc.amount,
        unit: acc.pool.unit,
      ),
  ];
}

String _shortSummary(int stockKcal, int cap, int ignored) {
  final missing = ignored > 0 ? '有 $ignored 样没填热量，没有算进天数。' : '';
  return '现有食材大约 $stockKcal kcal，凑不齐 $cap kcal 的一天。下面先排了能做的部分，并建议额外买一点补齐。$missing';
}

String _fullSummary(int days, int cap, int ignored, bool optional) {
  final missing = ignored > 0 ? '有 $ignored 样没填热量，没有算进天数。' : '';
  final extra = optional ? '蛋白质或蔬菜偏少，可以再额外买一点。' : '';
  return '按每天不超过 $cap kcal，现有食材大约能安排 $days 天。$extra$missing';
}

bool _isProtein(String id) =>
    id == 'meat' || id == 'seafood' || id == 'eggDairy' || id == 'soy';

bool _isProteinPool(_Pool pool) => _isProtein(pool.categoryId);

bool _isGrain(_Pool pool) => pool.categoryId == 'grain';

bool _isFruit(_Pool pool) => pool.categoryId == 'fruit';

bool _isVeg(_Pool pool) =>
    pool.categoryId == 'vegetable' || pool.categoryId == 'fungus';

String? _normalizeMeal(String raw) {
  return switch (raw.trim().toLowerCase()) {
    'breakfast' || '早餐' || '早' => 'breakfast',
    'lunch' || '午餐' || '午' => 'lunch',
    'dinner' || '晚餐' || '晚' => 'dinner',
    'snack' || '加餐' || '加' => 'snack',
    _ => null,
  };
}

int _asInt(Object? value) {
  if (value is num) return value.round();
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}

double _asDouble(Object? value) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? 0;
  return 0;
}
