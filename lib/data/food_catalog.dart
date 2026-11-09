/// 常见食物热量。g / ml 的 [FoodRef.kcal] 是每 100 单位，个 / 份是每 1 单位。
library;

class FoodCategory {
  const FoodCategory({required this.id, required this.name});

  final String id;
  final String name;
}

class FoodRef {
  const FoodRef({
    required this.name,
    required this.categoryId,
    required this.unit,
    required this.kcal,
  });

  final String name;
  final String categoryId;
  final String unit;
  final int kcal;

  bool get per100 => unit == 'g' || unit == 'ml';

  String get kcalLabel => per100 ? '$kcal kcal/100$unit' : '$kcal kcal/$unit';

  int caloriesFor(double amount) {
    if (amount <= 0 || kcal <= 0) return 0;
    if (per100) return (amount / 100 * kcal).round();
    return (amount * kcal).round();
  }
}

const String basketCategoryId = 'basket';

const List<FoodCategory> foodCategories = [
  FoodCategory(id: 'grain', name: '主食'),
  FoodCategory(id: 'meat', name: '肉禽'),
  FoodCategory(id: 'seafood', name: '水产'),
  FoodCategory(id: 'eggDairy', name: '蛋奶'),
  FoodCategory(id: 'soy', name: '豆制品'),
  FoodCategory(id: 'vegetable', name: '蔬菜'),
  FoodCategory(id: 'fruit', name: '水果'),
  FoodCategory(id: 'nut', name: '坚果'),
  FoodCategory(id: 'fungus', name: '菌藻'),
  FoodCategory(id: 'drink', name: '饮品'),
  FoodCategory(id: 'snack', name: '零食轻食'),
  FoodCategory(id: 'oil', name: '调料'),
];

const FoodCategory basketOtherCategory = FoodCategory(id: 'other', name: '其他');

const List<String> basketUnits = ['g', 'ml', '个', '份', '根', '片', '杯'];

int foodCategoryOrder(String id) {
  final index = foodCategories.indexWhere((item) => item.id == id);
  if (index >= 0) return index;
  return foodCategories.length + 1;
}

String foodCategoryName(String id) {
  for (final category in foodCategories) {
    if (category.id == id) return category.name;
  }
  if (id == basketOtherCategory.id) return basketOtherCategory.name;
  if (id == basketCategoryId) return '菜篮子';
  return basketOtherCategory.name;
}

const List<FoodRef> foodCatalog = [
  FoodRef(name: '米饭', categoryId: 'grain', unit: 'g', kcal: 116),
  FoodRef(name: '糙米', categoryId: 'grain', unit: 'g', kcal: 111),
  FoodRef(name: '燕麦', categoryId: 'grain', unit: 'g', kcal: 367),
  FoodRef(name: '面条（熟）', categoryId: 'grain', unit: 'g', kcal: 110),
  FoodRef(name: '全麦面包', categoryId: 'grain', unit: 'g', kcal: 246),
  FoodRef(name: '馒头', categoryId: 'grain', unit: 'g', kcal: 223),
  FoodRef(name: '红薯', categoryId: 'grain', unit: 'g', kcal: 86),
  FoodRef(name: '玉米', categoryId: 'grain', unit: 'g', kcal: 112),
  FoodRef(name: '藜麦（熟）', categoryId: 'grain', unit: 'g', kcal: 120),
  FoodRef(name: '意大利面（熟）', categoryId: 'grain', unit: 'g', kcal: 131),
  FoodRef(name: '鸡胸肉', categoryId: 'meat', unit: 'g', kcal: 133),
  FoodRef(name: '鸡腿肉', categoryId: 'meat', unit: 'g', kcal: 181),
  FoodRef(name: '瘦牛肉', categoryId: 'meat', unit: 'g', kcal: 125),
  FoodRef(name: '猪里脊', categoryId: 'meat', unit: 'g', kcal: 143),
  FoodRef(name: '瘦羊肉', categoryId: 'meat', unit: 'g', kcal: 118),
  FoodRef(name: '鸭胸肉', categoryId: 'meat', unit: 'g', kcal: 133),
  FoodRef(name: '三文鱼', categoryId: 'seafood', unit: 'g', kcal: 139),
  FoodRef(name: '鳕鱼', categoryId: 'seafood', unit: 'g', kcal: 82),
  FoodRef(name: '虾仁', categoryId: 'seafood', unit: 'g', kcal: 85),
  FoodRef(name: '带鱼', categoryId: 'seafood', unit: 'g', kcal: 127),
  FoodRef(name: '巴沙鱼', categoryId: 'seafood', unit: 'g', kcal: 90),
  FoodRef(name: '金枪鱼（水浸）', categoryId: 'seafood', unit: 'g', kcal: 116),
  FoodRef(name: '鸡蛋', categoryId: 'eggDairy', unit: '个', kcal: 70),
  FoodRef(name: '蛋白', categoryId: 'eggDairy', unit: '个', kcal: 17),
  FoodRef(name: '牛奶', categoryId: 'eggDairy', unit: 'ml', kcal: 54),
  FoodRef(name: '无糖酸奶', categoryId: 'eggDairy', unit: 'g', kcal: 62),
  FoodRef(name: '低脂奶酪', categoryId: 'eggDairy', unit: 'g', kcal: 250),
  FoodRef(name: '无糖豆浆', categoryId: 'eggDairy', unit: 'ml', kcal: 22),
  FoodRef(name: '北豆腐', categoryId: 'soy', unit: 'g', kcal: 98),
  FoodRef(name: '嫩豆腐', categoryId: 'soy', unit: 'g', kcal: 61),
  FoodRef(name: '千张', categoryId: 'soy', unit: 'g', kcal: 262),
  FoodRef(name: '毛豆仁', categoryId: 'soy', unit: 'g', kcal: 131),
  FoodRef(name: '鹰嘴豆（熟）', categoryId: 'soy', unit: 'g', kcal: 164),
  FoodRef(name: '腐竹', categoryId: 'soy', unit: 'g', kcal: 459),
  FoodRef(name: '西兰花', categoryId: 'vegetable', unit: 'g', kcal: 34),
  FoodRef(name: '菠菜', categoryId: 'vegetable', unit: 'g', kcal: 24),
  FoodRef(name: '番茄', categoryId: 'vegetable', unit: 'g', kcal: 18),
  FoodRef(name: '黄瓜', categoryId: 'vegetable', unit: 'g', kcal: 16),
  FoodRef(name: '生菜', categoryId: 'vegetable', unit: 'g', kcal: 15),
  FoodRef(name: '胡萝卜', categoryId: 'vegetable', unit: 'g', kcal: 37),
  FoodRef(name: '白菜', categoryId: 'vegetable', unit: 'g', kcal: 17),
  FoodRef(name: '茄子', categoryId: 'vegetable', unit: 'g', kcal: 23),
  FoodRef(name: '青椒', categoryId: 'vegetable', unit: 'g', kcal: 22),
  FoodRef(name: '小青菜', categoryId: 'vegetable', unit: 'g', kcal: 17),
  FoodRef(name: '苹果', categoryId: 'fruit', unit: 'g', kcal: 53),
  FoodRef(name: '香蕉', categoryId: 'fruit', unit: '个', kcal: 90),
  FoodRef(name: '蓝莓', categoryId: 'fruit', unit: 'g', kcal: 57),
  FoodRef(name: '橙子', categoryId: 'fruit', unit: '个', kcal: 60),
  FoodRef(name: '草莓', categoryId: 'fruit', unit: 'g', kcal: 32),
  FoodRef(name: '猕猴桃', categoryId: 'fruit', unit: '个', kcal: 45),
  FoodRef(name: '梨', categoryId: 'fruit', unit: 'g', kcal: 51),
  FoodRef(name: '葡萄', categoryId: 'fruit', unit: 'g', kcal: 69),
  FoodRef(name: '杏仁', categoryId: 'nut', unit: 'g', kcal: 578),
  FoodRef(name: '核桃仁', categoryId: 'nut', unit: 'g', kcal: 654),
  FoodRef(name: '花生', categoryId: 'nut', unit: 'g', kcal: 567),
  FoodRef(name: '腰果', categoryId: 'nut', unit: 'g', kcal: 552),
  FoodRef(name: '奇亚籽', categoryId: 'nut', unit: 'g', kcal: 486),
  FoodRef(name: '南瓜子', categoryId: 'nut', unit: 'g', kcal: 559),
  FoodRef(name: '香菇', categoryId: 'fungus', unit: 'g', kcal: 26),
  FoodRef(name: '金针菇', categoryId: 'fungus', unit: 'g', kcal: 32),
  FoodRef(name: '木耳（泡发）', categoryId: 'fungus', unit: 'g', kcal: 27),
  FoodRef(name: '海带', categoryId: 'fungus', unit: 'g', kcal: 13),
  FoodRef(name: '杏鲍菇', categoryId: 'fungus', unit: 'g', kcal: 31),
  FoodRef(name: '美式咖啡', categoryId: 'drink', unit: 'ml', kcal: 2),
  FoodRef(name: '无糖茶', categoryId: 'drink', unit: 'ml', kcal: 1),
  FoodRef(name: '脱脂牛奶', categoryId: 'drink', unit: 'ml', kcal: 35),
  FoodRef(name: '椰子水', categoryId: 'drink', unit: 'ml', kcal: 19),
  FoodRef(name: '海苔', categoryId: 'snack', unit: 'g', kcal: 180),
  FoodRef(name: '即食鸡胸', categoryId: 'snack', unit: 'g', kcal: 133),
  FoodRef(name: '蛋白粉', categoryId: 'snack', unit: 'g', kcal: 400),
  FoodRef(name: '全麦饼干', categoryId: 'snack', unit: 'g', kcal: 430),
  FoodRef(name: '牛肉干', categoryId: 'snack', unit: 'g', kcal: 313),
  FoodRef(name: '橄榄油', categoryId: 'oil', unit: 'g', kcal: 884),
  FoodRef(name: '花生油', categoryId: 'oil', unit: 'g', kcal: 899),
  FoodRef(name: '芝麻酱', categoryId: 'oil', unit: 'g', kcal: 615),
  FoodRef(name: '酱油', categoryId: 'oil', unit: 'ml', kcal: 63),
  FoodRef(name: '盐', categoryId: 'oil', unit: 'g', kcal: 0),
  FoodRef(name: '醋', categoryId: 'oil', unit: 'ml', kcal: 31),
  FoodRef(name: '蒜', categoryId: 'oil', unit: 'g', kcal: 126),
  FoodRef(name: '姜', categoryId: 'oil', unit: 'g', kcal: 80),
  FoodRef(name: '蚝油', categoryId: 'oil', unit: 'g', kcal: 80),
];

FoodRef? foodByName(String name) {
  final key = name.trim();
  if (key.isEmpty) return null;
  for (final food in foodCatalog) {
    if (food.name == key) return food;
  }
  return null;
}

List<FoodRef> foodSuggestions(String query, {int limit = 6}) {
  final key = query.trim();
  if (key.isEmpty) return const <FoodRef>[];
  final matched = <FoodRef>[];
  for (final food in foodCatalog) {
    if (food.name.contains(key)) matched.add(food);
    if (matched.length >= limit) break;
  }
  return matched;
}
