import 'dart:convert';

import '../data/food_catalog.dart';
import '../models/basket.dart';
import '../models/models.dart';

/// 生成食谱时，每天合计与目标热量允许的最大差距。
const int basketCalorieSlack = 100;

/// 按菜篮子和用户指定的天数、热量排出来的食谱。
class BasketPlanDraft {
  const BasketPlanDraft({
    required this.days,
    required this.shopping,
    required this.usages,
    required this.summary,
    required this.supportedDays,
    required this.calorieCap,
    required this.fromAi,
    this.note = '',
  });

  final List<PlanDay> days;
  final List<BasketShopping> shopping;
  final List<BasketUsage> usages;
  final String summary;

  /// 不额外购买时，菜篮子自己大约能撑满热量的天数。
  final int supportedDays;

  /// 用户要求的每日热量。
  final int calorieCap;
  final bool fromAi;
  final String note;

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
    String? note,
  }) {
    return BasketPlanDraft(
      days: days ?? this.days,
      shopping: shopping ?? this.shopping,
      usages: usages ?? this.usages,
      summary: summary ?? this.summary,
      supportedDays: supportedDays ?? this.supportedDays,
      calorieCap: calorieCap,
      fromAi: fromAi ?? this.fromAi,
      note: note ?? this.note,
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

int normalizeDayCount(int dayCount) => dayCount.clamp(1, 14);

bool dayCaloriesInBand(int calories, int target) =>
    (calories - target).abs() <= basketCalorieSlack;

/// 用家里现有的量排 [dayCount] 天食谱。每一天都尽量贴近目标热量，差距不超过 100 kcal。
/// 菜篮子不够时，用少量额外购买补齐，而不是把天数截短。
BasketPlanDraft buildLocalBasketPlan(
  List<BasketItem> items,
  int calorieCap, {
  int dayCount = 1,
  String note = '',
}) {
  final target = normalizeCalorieCap(calorieCap);
  final requested = normalizeDayCount(dayCount);
  final trimmedNote = note.trim();
  final pools = <_Pool>[
    for (final item in items)
      if (item.estimatedKcal > 0 && item.amount > 0) _Pool(item),
  ];
  final ignored =
      items.where((item) => item.amount > 0 && item.estimatedKcal <= 0).length;
  final days = <PlanDay>[];
  final usageMap = <String, _UsageAcc>{};
  final shoppingMap = <String, _ShopAcc>{};
  var supported = 0;

  for (var index = 0; index < requested; index++) {
    final before = {for (final pool in pools) pool.id: pool.left};
    final bites = _buildDay(pools, target);
    final shoppingBites = bites.where((bite) => bite.shopping).toList();
    if (shoppingBites.isEmpty && dayCaloriesInBand(_sumKcal(bites), target)) {
      supported++;
    }
    _collectUsage(usageMap, pools, before);
    for (final bite in shoppingBites) {
      final acc = shoppingMap.putIfAbsent(
        bite.name,
        () => _ShopAcc(bite.name, bite.unit, bite.reason),
      );
      acc.amount += bite.amount;
      acc.calories += bite.kcal;
    }
    final day = _dayFromBites(bites);
    if (day.meals.isNotEmpty) days.add(day);
  }

  final shopping = [
    for (final acc in shoppingMap.values)
      BasketShopping(
        name: acc.name,
        amount: acc.amount,
        unit: acc.unit,
        reason: acc.reason,
        calories: acc.calories,
      ),
  ];
  return BasketPlanDraft(
    days: days,
    shopping: shopping,
    usages: _usageList(usageMap),
    summary: _summary(
      target: target,
      requested: requested,
      supported: supported,
      ignored: ignored,
      note: trimmedNote,
    ),
    supportedDays: supported,
    calorieCap: target,
    fromAi: false,
    note: trimmedNote,
  );
}

String buildBasketPlanPrompt({
  required List<BasketItem> items,
  required int calorieCap,
  required int dayCount,
  String note = '',
}) {
  final target = normalizeCalorieCap(calorieCap);
  final days = normalizeDayCount(dayCount);
  final low = target - basketCalorieSlack;
  final high = target + basketCalorieSlack;
  final trimmed = note.trim();
  final buffer = StringBuffer()
    ..writeln('你是小一二减肥记里的食谱助手。根据用户菜篮子里的食材，生成能在家做的家常食谱。')
    ..writeln('只生成 $days 天，不要更多，也不要更少。')
    ..writeln(
      '每一天早餐、午餐、晚餐（必要时可加一顿加餐）的热量合计必须落在 $low 到 $high kcal 之间，尽量接近 $target kcal，相差不能大于 $basketCalorieSlack kcal。',
    )
    ..writeln(
      trimmed.isEmpty
          ? '用户没有额外备注。请自动按营养均衡来排：每一天都要有蛋白质、主食和蔬菜，水果可以做加餐，少油少盐。'
          : '用户备注：$trimmed。在热量和营养均衡的前提下尽量照做。',
    )
    ..writeln('优先使用菜篮子里的食材，用量不能超过余量。不够的部分才写进 shopping，每种只买够这几天要用的量。')
    ..writeln('每一餐都要写出具体做法、每种食材的用量、生重（克）和这一餐的热量。热量按生重估算。')
    ..writeln('菜篮子：');
  for (final item in items) {
    buffer.writeln(
      '- ${item.name}｜${item.amountLabel}｜${foodCategoryName(item.categoryId)}｜约 ${item.estimatedKcal} kcal｜id:${item.id}',
    );
  }
  buffer
    ..writeln('只输出一个 JSON 对象，不要 Markdown，不要解释。格式：')
    ..writeln(
      '{"summary":"一句话","shopping":[{"name":"西兰花","amount":200,"unit":"g","reason":"补蔬菜"}],"usages":[{"id":"食材id","amount":80}],"days":[{"meals":[{"mealType":"breakfast","name":"水煮蛋配燕麦","calories":320,"method":"燕麦按生重称好，加水煮 3 分钟。鸡蛋冷水下锅，水开后煮 8 分钟。","ingredients":[{"name":"燕麦","amount":40,"unit":"g","rawGrams":40},{"name":"鸡蛋","amount":1,"unit":"个","rawGrams":50}]}]}]}',
    )
    ..writeln(
      'mealType 只能是 breakfast、lunch、dinner、snack。days 长度必须是 $days。ingredients.amount 是用量，rawGrams 是生重克数。usages.amount 使用菜篮子里的单位，且不能超过该食材余量。',
    );
  return buffer.toString();
}

/// 把模型输出收成指定天数、且每天热量落在目标 ±100 kcal 内的食谱。解析失败时返回 null。
BasketPlanDraft? parseAiBasketPlan(
  String raw, {
  required List<BasketItem> items,
  required int calorieCap,
  required int dayCount,
  String note = '',
  required String fallbackSummary,
}) {
  final target = normalizeCalorieCap(calorieCap);
  final requested = normalizeDayCount(dayCount);
  final jsonText = _extractJsonObject(raw);
  if (jsonText == null) return null;
  final Object? decoded;
  try {
    decoded = _decodeJson(jsonText);
  } on FormatException {
    return null;
  }
  if (decoded is! Map) return null;
  final days = <PlanDay>[];
  final rawDays = decoded['days'];
  if (rawDays is List) {
    for (final item in rawDays) {
      if (days.length >= requested) break;
      if (item is! Map) continue;
      final meals = <PlanMeal>[];
      final rawMeals = item['meals'];
      if (rawMeals is List) {
        for (final meal in rawMeals) {
          if (meal is! Map) continue;
          final parsed = _parseMeal(Map<String, dynamic>.from(meal));
          if (parsed == null) continue;
          meals.add(parsed);
        }
      }
      if (meals.isEmpty) continue;
      final aligned = _alignDay(_orderedDay(meals), target);
      if (aligned.meals.isEmpty ||
          !dayCaloriesInBand(aligned.calories, target)) {
        return null;
      }
      days.add(aligned);
    }
  }
  if (days.length != requested) return null;

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
    supportedDays: 0,
    calorieCap: target,
    fromAi: true,
    note: note.trim(),
  );
}

PlanMeal? _parseMeal(Map<String, dynamic> meal) {
  final type = _normalizeMeal('${meal['mealType']}');
  final name = '${meal['name']}'.trim();
  final calories = _asInt(meal['calories']);
  if (type == null || name.isEmpty || calories <= 0) return null;
  final ingredients = <PlanIngredient>[];
  final rawIngredients = meal['ingredients'];
  if (rawIngredients is List) {
    for (final item in rawIngredients) {
      if (item is! Map) continue;
      final map = Map<String, dynamic>.from(item);
      final ingredientName = '${map['name']}'.trim();
      final amount = _asDouble(map['amount']);
      if (ingredientName.isEmpty || amount <= 0) continue;
      final unit = '${map['unit']}'.trim();
      final safeUnit = unit.isEmpty ? 'g' : unit;
      final rawGrams =
          map['rawGrams'] == null ? null : _asDouble(map['rawGrams']);
      ingredients.add(
        PlanIngredient(
          name: ingredientName.length > 20
              ? ingredientName.substring(0, 20)
              : ingredientName,
          amount: amount,
          unit: safeUnit,
          rawGrams: rawGrams != null && rawGrams > 0
              ? rawGrams
              : (safeUnit == 'g' ? amount : null),
        ),
      );
    }
  }
  if (ingredients.isEmpty) return null;
  var method = '${meal['method']}'.trim();
  if (method.isEmpty) method = _fallbackMethod(ingredients);
  if (method.length > 400) method = '${method.substring(0, 400)}…';
  return PlanMeal(
    mealType: type,
    name: name.length > 48 ? '${name.substring(0, 48)}…' : name,
    calories: calories > 2000 ? 2000 : calories,
    method: method,
    ingredients: ingredients,
  );
}

String _fallbackMethod(List<PlanIngredient> ingredients) {
  final names = ingredients.map((item) => item.detail).join('、');
  return '按生重备好$names。主食加水煮熟，肉和蛋完全做熟，蔬菜少油快炒或焯熟，最后按这一餐的用量装盘。';
}

PlanDay _alignDay(PlanDay day, int target) {
  final total = day.calories;
  if (total <= 0) return day;
  if (dayCaloriesInBand(total, target)) return day;
  final ratio = target / total;
  final meals = <PlanMeal>[];
  var used = 0;
  for (var index = 0; index < day.meals.length; index++) {
    final meal = day.meals[index];
    final isLast = index == day.meals.length - 1;
    final kcal = isLast ? target - used : (meal.calories * ratio).round();
    if (kcal <= 0) continue;
    used += kcal;
    final mealRatio = meal.calories <= 0 ? 1.0 : kcal / meal.calories;
    meals.add(
      PlanMeal(
        mealType: meal.mealType,
        name: meal.name,
        calories: kcal,
        method: meal.method,
        ingredients: [
          for (final item in meal.ingredients)
            PlanIngredient(
              name: item.name,
              amount: _roundAmount(item.amount * mealRatio, item.unit),
              unit: item.unit,
              rawGrams: item.rawGrams == null
                  ? null
                  : _roundAmount(item.rawGrams! * mealRatio, 'g'),
            ),
        ],
      ),
    );
  }
  return PlanDay(meals: meals);
}

double _roundAmount(double amount, String unit) {
  if (amount <= 0) return 0;
  if (unit == 'g' || unit == 'ml') {
    final rounded = amount.roundToDouble();
    return rounded < 1 ? 1 : rounded;
  }
  final stepped = (amount * 2).round() / 2;
  return stepped < 0.5 ? 0.5 : stepped;
}

PlanDay _orderedDay(List<PlanMeal> meals) {
  const order = ['breakfast', 'lunch', 'dinner', 'snack'];
  final copy = [...meals];
  copy.sort(
    (a, b) => order.indexOf(a.mealType).compareTo(order.indexOf(b.mealType)),
  );
  return PlanDay(meals: copy);
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
}

class _Bite {
  _Bite({
    required this.name,
    required this.categoryId,
    required this.unit,
    required this.amount,
    required this.kcal,
    required this.mealType,
    this.pool,
    this.rawGrams,
    this.shopping = false,
    this.reason = '',
  });

  final _Pool? pool;
  final String name;
  final String categoryId;
  final String unit;
  double amount;
  int kcal;
  String mealType;
  double? rawGrams;
  final bool shopping;
  final String reason;
}

class _UsageAcc {
  _UsageAcc(this.pool);

  final _Pool pool;
  double amount = 0;
}

class _ShopAcc {
  _ShopAcc(this.name, this.unit, this.reason);

  final String name;
  final String unit;
  final String reason;
  double amount = 0;
  int calories = 0;
}

double _kcalPerUnit(BasketItem item) {
  final basis = item.kcal ?? 0;
  if (basis <= 0) return 0;
  if (kcalIsPer100(item.unit)) return basis / 100;
  return basis.toDouble();
}

List<_Bite> _buildDay(List<_Pool> pools, int target) {
  final breakfastBudget = (target * 0.30).round();
  final lunchBudget = (target * 0.40).round();
  final dinnerBudget = target - breakfastBudget - lunchBudget;
  final bites = <_Bite>[
    ..._fill(pools, 'breakfast', _isEgg, (breakfastBudget * 0.45).round()),
    ..._fill(pools, 'breakfast', _isGrain, (breakfastBudget * 0.40).round()),
    ..._fill(pools, 'breakfast', _isFruit, (breakfastBudget * 0.15).round()),
    ..._fill(pools, 'lunch', _isProteinPool, (lunchBudget * 0.45).round()),
    ..._fill(pools, 'lunch', _isGrain, (lunchBudget * 0.35).round()),
    ..._fill(pools, 'lunch', _isVeg, (lunchBudget * 0.20).round()),
    ..._fill(pools, 'dinner', _isProteinPool, (dinnerBudget * 0.45).round()),
    ..._fill(pools, 'dinner', _isVeg, (dinnerBudget * 0.25).round()),
    ..._fill(pools, 'dinner', _isGrain, (dinnerBudget * 0.30).round()),
  ];
  _fillRemainder(bites, pools, target);
  _topUp(bites, target);
  final total = _sumKcal(bites);
  if (total > target + basketCalorieSlack && total > 0) {
    _rescale(bites, target / total);
  }
  _fixSum(bites, target);
  _tidy(bites);
  return bites;
}

void _fillRemainder(List<_Bite> bites, List<_Pool> pools, int target) {
  var guard = 0;
  while (target - _sumKcal(bites) > 30 && guard < 16) {
    guard++;
    final room = target - _sumKcal(bites);
    _Bite? taken;
    for (final pool in pools) {
      taken = _take(pool, room, _lightestMeal(bites));
      if (taken != null) break;
    }
    if (taken == null) break;
    bites.add(taken);
  }
}

void _topUp(List<_Bite> bites, int target) {
  var gap = target - _sumKcal(bites);
  if (gap <= basketCalorieSlack) return;
  final hasProtein = bites.any((bite) => _isProtein(bite.categoryId));
  final hasGrain = bites.any((bite) => bite.categoryId == 'grain');
  final hasVeg = bites.any((bite) => _isVegId(bite.categoryId));

  void add({
    required String name,
    required String categoryId,
    required int per100,
    required int wantKcal,
    required String reason,
    required String preferredMeal,
  }) {
    gap = target - _sumKcal(bites);
    if (wantKcal < 20 || gap < 20) return;
    final use = wantKcal > gap ? gap : wantKcal;
    var grams = use / per100 * 100;
    final rounded = (grams / 5).round() * 5;
    var amount = rounded < 5 ? grams : rounded.toDouble();
    var kcal = (amount / 100 * per100).round();
    if (kcal <= 0) return;
    if (kcal > gap) {
      amount = grams;
      kcal = gap;
    }
    if (amount <= 0 || kcal <= 0) return;
    bites.add(
      _Bite(
        name: name,
        categoryId: categoryId,
        unit: 'g',
        amount: amount,
        kcal: kcal,
        mealType: _place(bites, preferredMeal),
        rawGrams: amount,
        shopping: true,
        reason: reason,
      ),
    );
  }

  if (!hasVeg) {
    add(
      name: '西兰花',
      categoryId: 'vegetable',
      per100: 34,
      wantKcal: gap < 80 ? gap : 70,
      reason: '补蔬菜',
      preferredMeal: 'dinner',
    );
  }
  if (!hasProtein) {
    add(
      name: '鸡胸肉',
      categoryId: 'meat',
      per100: 133,
      wantKcal: (target * 0.28).round(),
      reason: '补蛋白质',
      preferredMeal: 'lunch',
    );
  }
  if (!hasGrain) {
    add(
      name: '糙米',
      categoryId: 'grain',
      per100: 111,
      wantKcal: (target * 0.32).round(),
      reason: '补主食',
      preferredMeal: 'breakfast',
    );
  }
  gap = target - _sumKcal(bites);
  if (gap > 15) {
    add(
      name: '糙米',
      categoryId: 'grain',
      per100: 111,
      wantKcal: gap,
      reason: '补足当天热量',
      preferredMeal: _lightestMeal(bites),
    );
  }
}

void _rescale(List<_Bite> bites, double ratio) {
  if (ratio <= 0) return;
  for (final bite in bites) {
    final next = bite.amount * ratio;
    final pool = bite.pool;
    if (pool != null && !bite.shopping) {
      pool.left += bite.amount - next;
      if (pool.left < 0) pool.left = 0;
    }
    bite.amount = next;
    if (bite.rawGrams != null) bite.rawGrams = bite.rawGrams! * ratio;
    bite.kcal = (bite.kcal * ratio).round();
  }
}

void _fixSum(List<_Bite> bites, int target) {
  if (bites.isEmpty) return;
  final diff = target - _sumKcal(bites);
  if (diff == 0) return;
  final last = bites.last;
  if (last.kcal + diff > 0) last.kcal += diff;
}

void _tidy(List<_Bite> bites) {
  for (final bite in bites) {
    if (bite.unit == 'g' || bite.unit == 'ml') {
      final rounded = bite.amount.roundToDouble();
      bite.amount = rounded < 1 ? 1 : rounded;
      if (bite.unit == 'g') bite.rawGrams = bite.amount;
    } else {
      final stepped = (bite.amount * 2).round() / 2;
      bite.amount = stepped < 0.5 ? 0.5 : stepped;
      if (bite.rawGrams != null) {
        bite.rawGrams = (bite.rawGrams! * 10).round() / 10;
      }
    }
  }
}

int _sumKcal(List<_Bite> bites) =>
    bites.fold<int>(0, (sum, bite) => sum + bite.kcal);

List<_Bite> _fill(
  List<_Pool> pools,
  String mealType,
  bool Function(_Pool pool) match,
  int budget,
) {
  final bites = <_Bite>[];
  var remain = budget;
  if (remain < 30) return bites;
  for (final pool in pools) {
    if (remain < 30) break;
    if (!match(pool)) continue;
    final bite = _take(pool, remain, mealType);
    if (bite == null) continue;
    bites.add(bite);
    remain -= bite.kcal;
  }
  return bites;
}

_Bite? _take(_Pool pool, int targetKcal, String mealType) {
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
  final raw = _estimateRawGrams(pool.name, amount, pool.unit);
  return _Bite(
    pool: pool,
    name: pool.name,
    categoryId: pool.categoryId,
    unit: pool.unit,
    amount: amount,
    kcal: kcal,
    mealType: mealType,
    rawGrams: raw,
  );
}

double? _estimateRawGrams(String name, double amount, String unit) {
  if (unit == 'g') return amount;
  const each = <String, double>{
    '鸡蛋': 50,
    '蛋白': 33,
    '香蕉': 100,
    '橙子': 180,
    '猕猴桃': 80,
  };
  final per = each[name];
  if (per == null) return null;
  return amount * per;
}

PlanDay _dayFromBites(List<_Bite> bites) {
  const order = ['breakfast', 'lunch', 'dinner', 'snack'];
  final meals = <PlanMeal>[];
  for (final type in order) {
    final group = bites.where((bite) => bite.mealType == type).toList();
    if (group.isEmpty) continue;
    final ingredients = [
      for (final bite in group)
        PlanIngredient(
          name: bite.name,
          amount: bite.amount,
          unit: bite.unit,
          rawGrams: bite.rawGrams,
        ),
    ];
    final name = _dishName(group);
    meals.add(
      PlanMeal(
        mealType: type,
        name: name,
        calories: group.fold<int>(0, (sum, bite) => sum + bite.kcal),
        method: _methodFor(group),
        ingredients: ingredients,
      ),
    );
  }
  return PlanDay(meals: meals);
}

String _dishName(List<_Bite> bites) {
  final names = <String>[];
  for (final bite in bites) {
    if (!names.contains(bite.name)) names.add(bite.name);
  }
  if (names.length <= 1) return names.isEmpty ? '家常一餐' : names.first;
  if (names.length == 2) return '${names[0]}配${names[1]}';
  final text = names.take(3).join('、');
  return text.length > 24 ? '${text.substring(0, 24)}…' : text;
}

String _methodFor(List<_Bite> bites) {
  final steps = <String>[];
  for (final bite in bites) {
    final step = _stepFor(bite);
    if (step.isNotEmpty) steps.add(step);
  }
  final text = steps.join();
  if (text.length <= 280) return text;
  return '${text.substring(0, 280)}…';
}

String _stepFor(_Bite bite) {
  final raw = bite.rawGrams == null
      ? '${formatAmount(bite.amount)}${bite.unit}'
      : '生重 ${formatAmount(bite.rawGrams!)}g';
  final name = bite.name;
  if (bite.categoryId == 'eggDairy' && name.contains('蛋')) {
    return '$name取$raw，冷水下锅，水开后煮 8 分钟，捞出过凉。';
  }
  if (bite.categoryId == 'grain') {
    return '$name按$raw洗净，加水没过食材，煮至熟透，热量按生重计。';
  }
  if (_isProtein(bite.categoryId) && bite.categoryId != 'eggDairy') {
    return '$name按$raw切片，少油中火煎或蒸 8 到 10 分钟，到完全熟。';
  }
  if (_isVegId(bite.categoryId)) {
    return '$name按$raw洗净，沸水焯 1 分钟，或少油快炒 2 分钟。';
  }
  if (bite.categoryId == 'fruit') {
    return '$name按$raw洗净，直接吃。';
  }
  if (bite.categoryId == 'oil') {
    return '$name按$raw在出锅前调味，不要额外加油。';
  }
  return '$name按$raw备好，少油少盐做熟。';
}

String _place(List<_Bite> bites, String preferred) {
  if (!bites.any((bite) => bite.mealType == preferred)) return preferred;
  for (final type in ['breakfast', 'lunch', 'dinner']) {
    if (!bites.any((bite) => bite.mealType == type)) return type;
  }
  return _lightestMeal(bites);
}

String _lightestMeal(List<_Bite> bites) {
  var best = 'lunch';
  var bestKcal = 1 << 30;
  for (final type in ['breakfast', 'lunch', 'dinner']) {
    final kcal = bites
        .where((bite) => bite.mealType == type)
        .fold<int>(0, (sum, bite) => sum + bite.kcal);
    if (kcal < bestKcal) {
      best = type;
      bestKcal = kcal;
    }
  }
  return best;
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

String _summary({
  required int target,
  required int requested,
  required int supported,
  required int ignored,
  required String note,
}) {
  final band = '按每天 $target kcal 来排，每天合计与目标相差不超过 $basketCalorieSlack kcal';
  final cover = supported >= requested
      ? '这 $requested 天都可以用家里的食材来做。'
      : supported <= 0
          ? '现有食材凑不齐这些天的热量，不够的部分建议额外购买。'
          : '家里的量大约能自己撑 $supported 天，其余需要再买一点。';
  final remark = note.isEmpty ? '没有额外备注，已按蛋白质、主食和蔬菜来搭配。' : '备注会在使用 AI 时写进做法。';
  final missing = ignored > 0 ? '有 $ignored 样没填热量，没有算进用量。' : '';
  return '$band。$cover$remark$missing';
}

bool _isProtein(String id) =>
    id == 'meat' || id == 'seafood' || id == 'eggDairy' || id == 'soy';

bool _isProteinPool(_Pool pool) => _isProtein(pool.categoryId);

bool _isEgg(_Pool pool) => pool.categoryId == 'eggDairy';

bool _isGrain(_Pool pool) => pool.categoryId == 'grain';

bool _isFruit(_Pool pool) => pool.categoryId == 'fruit';

bool _isVeg(_Pool pool) => _isVegId(pool.categoryId);

bool _isVegId(String id) => id == 'vegetable' || id == 'fungus';

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
