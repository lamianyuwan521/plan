import '../models/models.dart';

/// 内置的长期食谱方案。
///
/// 方案来自本人实际执行的记录，日期不绑定具体年份；加入日历时由用户选择
/// 起始日期。热量为估算值，用于日历里的计划热量统计。
PlanMeal _b(String name, int kcal) =>
    PlanMeal(mealType: 'breakfast', name: name, calories: kcal);

PlanMeal _l(String name, int kcal) =>
    PlanMeal(mealType: 'lunch', name: name, calories: kcal);

PlanMeal _d(String name, int kcal) =>
    PlanMeal(mealType: 'dinner', name: name, calories: kcal);

PlanDay _day({
  PlanMeal? breakfast,
  PlanMeal? lunch,
  PlanMeal? dinner,
  double? weightJin,
  String? note,
}) {
  return PlanDay(
    meals: [
      if (breakfast != null) breakfast,
      if (lunch != null) lunch,
      if (dinner != null) dinner,
    ],
    weightJin: weightJin,
    note: note,
  );
}

const String _oneFistMeal = '双吉汉堡 / 一拳藜麦饭 + 两拳蔬菜 + 一拳肉';

final List<DietPlan> seedPlans = [
  DietPlan(
    id: 'plan-7day',
    name: '7天极速掉秤',
    description: '冰美式 + 鸡蛋打底的一周极简方案，前两天留下了参考体重。',
    tags: ['极速', '7 天', '低碳'],
    days: [
      _day(
        weightJin: 117.7,
        breakfast: _b('冰美式 + 🥚', 80),
        lunch: _l('🥚 x2', 140),
        dinner: _d('2 个磨牙棒 + 2 小包辣条', 280),
      ),
      _day(
        weightJin: 116.2,
        breakfast: _b('冰美式 + 🥚', 80),
        lunch: _l('🥚 x2', 140),
      ),
      _day(breakfast: _b('全冰奶酪 + 🥚', 290), lunch: _l('🥚 x2', 140)),
      _day(breakfast: _b('冰美式 + 🥚', 80), lunch: _l('🥚 x2', 140)),
      _day(breakfast: _b('全冰奶酪 + 🥚', 290), lunch: _l('🥚 x2', 140)),
      _day(breakfast: _b('冰美式 + 🥚', 80), lunch: _l('🥚 x2', 140)),
      _day(breakfast: _b('冰美式 + 🥚', 80), lunch: _l('🥚 x2', 140)),
    ],
  ),
  DietPlan(
    id: 'plan-5-2',
    name: '5+2掉秤',
    description: '5 天正常吃、2 天轻断食的节奏，蛋白和粗粮交替。',
    tags: ['轻断食', '7 天'],
    days: [
      _day(
        breakfast: _b('冰美式 + 🥚 x2', 150),
        lunch: _l('三明治 + 温水', 350),
        dinner: _d('🌽 + 温水', 120),
      ),
      _day(
        breakfast: _b('🍌 x1 + 🥚 x1 + 椰子水', 205),
        lunch: _l('牛奶🥛 + 🥚 x2', 270),
        dinner: _d('🍌 x1 + 🥚 x1 + 温水', 160),
      ),
      _day(
        breakfast: _b('牛奶🥛 + 🥚 x2', 270),
        lunch: _l('沙县鸡腿饭', 650),
        dinner: _d('白面馒头 + 温水', 230),
      ),
      _day(
        breakfast: _b('椰子水 + 🥚 x2', 185),
        lunch: _l('椰子水 + 双吉堡', 485),
        dinner: _d('白面馒头 + 温水', 230),
      ),
      _day(
        breakfast: _b('牛奶 + 冰美式', 140),
        lunch: _l('三明治 + 椰子水', 395),
        dinner: _d('🥚 x1 + 🍌 x1', 160),
      ),
      _day(
        breakfast: _b('牛奶 + 🥚 x2', 270),
        lunch: _l('麻辣烫', 500),
        dinner: _d('白面馒头 + 温水', 230),
      ),
      _day(
        breakfast: _b('椰子水 + 🥚 x2', 185),
        lunch: _l('沙县鸡腿饭', 650),
        dinner: _d('白面馒头 + 温水', 230),
      ),
    ],
  ),
  DietPlan(
    id: 'plan-baiguo',
    name: '一只白+郭敬明',
    description: '五天高蛋白 + 水果的短周期方案。',
    tags: ['高蛋白', '5 天'],
    days: [
      _day(
        breakfast: _b('冰美式 + 🥚 x1', 80),
        lunch: _l('牛奶🥛 + 🥚 x2', 270),
        dinner: _d('🍌 x1', 90),
      ),
      _day(
        breakfast: _b('牛奶🥛 + 🥚 x1', 200),
        lunch: _l('🍌 x1 + 白面馒头', 320),
        dinner: _d('🍌 x1 + 🥚 x1', 160),
      ),
      _day(
        breakfast: _b('椰子水 + 🍌 x1', 135),
        lunch: _l('🍌 x1 + 🥚 x1', 160),
        dinner: _d('🥚 x1 + 白面馒头', 300),
      ),
      _day(
        breakfast: _b('冰美式', 10),
        lunch: _l('牛肉', 250),
        dinner: _d('牛肉', 250),
      ),
      _day(
        breakfast: _b('牛奶🥛 + 🥚 x1', 200),
        lunch: _l('牛肉 + 蔬菜', 300),
        dinner: _d('牛肉', 250),
      ),
    ],
  ),
  DietPlan(
    id: 'plan-5day-12jin',
    name: '5天12斤',
    description: '五天低热量方案，适合短期集中执行。',
    tags: ['极速', '5 天'],
    days: [
      _day(breakfast: _b('冰美式', 10), lunch: _l('🥚 x1 + 🌽', 190)),
      _day(
        breakfast: _b('🥚 x1', 70),
        lunch: _l('🌽 半根', 60),
        dinner: _d('苹果', 90),
      ),
      _day(breakfast: _b('冰美式 + 🥚 x1', 80), lunch: _l('荞麦面', 350)),
      _day(
        breakfast: _b('牛奶🥛 + 🥚 x1', 200),
        lunch: _l('三明治', 350),
        dinner: _d('酸奶 + 桃子', 150),
      ),
      _day(
        breakfast: _b('🥚 x1 + 🌽', 190),
        lunch: _l('鸡胸肉', 200),
        dinner: _d('🌽', 120),
      ),
    ],
  ),
  DietPlan(
    id: 'plan-110-100',
    name: '110-100',
    description: '43 天的长周期方案，前段是极简餐，后段用「一拳主食 + 两拳蔬菜 + 一拳肉」收尾。',
    tags: ['长期', '43 天', '控卡'],
    days: [
      _day(
        breakfast: _b('冰美式', 10),
        lunch: _l('奥尔良鸡腿三明治', 450),
        dinner: _d('🍌 x1', 90),
      ),
      _day(
        breakfast: _b('🍌 x1', 90),
        lunch: _l('200g 鸡胸 or 牛肉', 300),
        dinner: _d('🥚 x1', 70),
      ),
      _day(
        breakfast: _b('🥚 x1 + 🍌 x1', 160),
        lunch: _l('🥚 x2 + 牛奶🥛', 270),
        dinner: _d('🍌 x1', 90),
      ),
      _day(
        breakfast: _b('🥚 x2', 140),
        lunch: _l('板烧鸡腿堡', 500),
        dinner: _d('🍌 x1', 90),
      ),
      _day(
        lunch: _l('窑鸡半只（早/午合并）', 600),
        dinner: _d('🥚 x1', 70),
        note: '早午餐合并成一餐。',
      ),
      _day(lunch: _l('椰子鸡，只吃鸡肉（椰子肉热量高）', 350), note: '椰子肉热量很高，只吃鸡肉。'),
      _day(lunch: _l('牛肉（早/午合并）', 250), dinner: _d('🍌 x1', 90)),
      _day(
        breakfast: _b('冰美式 + 🥚 x1', 80),
        lunch: _l('牛肉', 250),
        dinner: _d('苹果醋', 20),
      ),
      _day(
        breakfast: _b('🍌 x1 + 🥚 x1', 160),
        lunch: _l('茉莉绿茶 + 🥚 x1 + 🍌', 165),
        dinner: _d('🍌 x1 + 🥚 x1', 160),
      ),
      _day(
        breakfast: _b('冰美式', 10),
        lunch: _l('小黄油美式', 80),
        dinner: _d('椰子水 + 羽衣甘蓝', 85),
      ),
      _day(
        breakfast: _b('🍌 x1 + 🥚 x1', 160),
        lunch: _l('椰子水 + 抹茶 + 羽衣甘蓝 + 牛奶', 220),
        dinner: _d('白面馒头', 230),
      ),
      _day(
        breakfast: _b('冰美式 + 🥚 x1', 80),
        lunch: _l('🍌 x1 + 🥚 x1', 160),
        dinner: _d('🌽 x1', 120),
      ),
      _day(
        breakfast: _b('燕麦拿铁（燕麦奶减半）+ 🥚 x1', 220),
        lunch: _l('🍌 x1 + 🥚 x1', 160),
      ),
      _day(
        breakfast: _b('瑞之抹茶', 200),
        lunch: _l('🍌 x1', 90),
        dinner: _d('紫薯', 150),
      ),
      _day(breakfast: _b('☕️ + 🥚 x1', 80), lunch: _l(_oneFistMeal, 550)),
      _day(breakfast: _b('☕️ + 🥚 x1', 80), lunch: _l(_oneFistMeal, 550)),
      _day(breakfast: _b('☕️ + 🍌 x1', 100), lunch: _l(_oneFistMeal, 550)),
      _day(breakfast: _b('☕️ + 🥚 x1', 80), lunch: _l(_oneFistMeal, 550)),
      _day(breakfast: _b('☕️ + 🌽 x1', 130), lunch: _l(_oneFistMeal, 550)),
      _day(breakfast: _b('☕️ + 🥚 x1', 80), lunch: _l(_oneFistMeal, 550)),
      for (var index = 0; index < 23; index++)
        _day(
          breakfast: _b('☕️ / 椰子水 + 🥚 / 🌽 / 🍌', 110),
          lunch: _l(_oneFistMeal, 550),
        ),
    ],
  ),
];

DietPlan? planById(String id) {
  for (final plan in seedPlans) {
    if (plan.id == id) return plan;
  }
  return null;
}
