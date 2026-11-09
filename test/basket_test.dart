import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xiaoyier/data/app_repository.dart';
import 'package:xiaoyier/data/food_catalog.dart';
import 'package:xiaoyier/models/basket.dart';
import 'package:xiaoyier/services/basket_planner.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  BasketItem item({
    required String id,
    required String name,
    required String categoryId,
    required double amount,
    required String unit,
    required int kcal,
  }) {
    return BasketItem(
      id: id,
      name: name,
      categoryId: categoryId,
      amount: amount,
      unit: unit,
      kcal: kcal,
    );
  }

  List<BasketItem> stock({double scale = 1}) {
    return [
      item(
        id: 'egg',
        name: '鸡蛋',
        categoryId: 'eggDairy',
        amount: 4 * scale,
        unit: '个',
        kcal: 70,
      ),
      item(
        id: 'chicken',
        name: '鸡胸肉',
        categoryId: 'meat',
        amount: 400 * scale,
        unit: 'g',
        kcal: 133,
      ),
      item(
        id: 'rice',
        name: '糙米',
        categoryId: 'grain',
        amount: 400 * scale,
        unit: 'g',
        kcal: 111,
      ),
      item(
        id: 'broccoli',
        name: '西兰花',
        categoryId: 'vegetable',
        amount: 400 * scale,
        unit: 'g',
        kcal: 34,
      ),
    ];
  }

  test('热量库按分类覆盖主食、蔬菜、水果、调料等', () {
    expect(
      foodCategories.map((item) => item.name),
      containsAll(['主食', '肉禽', '水产', '蔬菜', '水果', '调料', '菌藻']),
    );
    expect(foodByName('鸡胸肉')?.kcal, 133);
    expect(foodByName('鸡蛋')?.caloriesFor(2), 140);
    expect(foodByName('米饭')?.caloriesFor(150), 174);
  });

  test('食材不够时仍按目标热量排满，并给出采购建议', () {
    final draft = buildLocalBasketPlan([
      item(
        id: 'apple',
        name: '苹果',
        categoryId: 'fruit',
        amount: 100,
        unit: 'g',
        kcal: 53,
      ),
    ], 1500, dayCount: 1);

    expect(draft.supportedDays, 0);
    expect(draft.days, hasLength(1));
    expect((draft.days.single.calories - 1500).abs(), lessThanOrEqualTo(100));
    expect(draft.shopping, isNotEmpty);
    expect(draft.summary, contains('凑不齐'));
    expect(draft.canSave, isTrue);
    for (final meal in draft.days.single.meals) {
      expect(meal.calories, greaterThan(0));
      expect(meal.method, isNotEmpty);
      expect(meal.ingredients, isNotEmpty);
    }
  });

  test('按指定天数生成，每天热量差不超过 100', () {
    final oneDay = buildLocalBasketPlan(stock(), 1200, dayCount: 1);
    expect(oneDay.days, hasLength(1));
    expect((oneDay.days.single.calories - 1200).abs(), lessThanOrEqualTo(100));

    final longer = buildLocalBasketPlan(stock(scale: 4), 1200, dayCount: 3);
    expect(longer.days, hasLength(3));
    for (final day in longer.days) {
      expect((day.calories - 1200).abs(), lessThanOrEqualTo(100));
      expect(day.meals, isNotEmpty);
      for (final meal in day.meals) {
        expect(meal.method, isNotEmpty);
        expect(meal.ingredients, isNotEmpty);
        expect(
          meal.ingredients.any((ingredient) => ingredient.rawGrams != null),
          isTrue,
        );
      }
    }
    final usedEggs =
        longer.usages.firstWhere((usage) => usage.itemId == 'egg').amount;
    expect(usedEggs, lessThanOrEqualTo(16));
  });

  test('没有备注时提示词要求营养均衡，并限定热量差', () {
    final prompt = buildBasketPlanPrompt(
      items: stock(),
      calorieCap: 1500,
      dayCount: 2,
    );
    expect(prompt, contains('没有额外备注'));
    expect(prompt, contains('营养均衡'));
    expect(prompt, contains('只生成 2 天'));
    expect(prompt, contains('1400'));
    expect(prompt, contains('1600'));
    expect(prompt, contains('生重'));

    final noted = buildBasketPlanPrompt(
      items: stock(),
      calorieCap: 1500,
      dayCount: 1,
      note: '午餐要能带饭',
    );
    expect(noted, contains('午餐要能带饭'));
  });

  test('解析 AI 食谱时按指定天数截断，并把热量收到目标附近', () {
    const raw = '''
```json
{
  "summary": "两天够吃",
  "shopping": [{"name": "西兰花", "amount": 200, "unit": "g", "reason": "可选，补蔬菜"}],
  "usages": [{"id": "egg", "amount": 4}],
  "days": [
    {"meals": [
      {"mealType": "breakfast", "name": "水煮蛋", "calories": 140, "method": "冷水下锅煮 8 分钟。", "ingredients": [{"name": "鸡蛋", "amount": 2, "unit": "个", "rawGrams": 100}]},
      {"mealType": "lunch", "name": "鸡胸糙米", "calories": 500, "method": "鸡胸煎熟，糙米按生重煮熟。", "ingredients": [{"name": "鸡胸肉", "amount": 120, "unit": "g", "rawGrams": 120}, {"name": "糙米", "amount": 80, "unit": "g", "rawGrams": 80}]},
      {"mealType": "dinner", "name": "西兰花鸡胸", "calories": 400, "method": "西兰花焯熟，鸡胸煎熟。", "ingredients": [{"name": "西兰花", "amount": 200, "unit": "g", "rawGrams": 200}]}
    ]},
    {"meals": [{"mealType": "lunch", "name": "第二天", "calories": 600, "method": "煮熟。", "ingredients": [{"name": "糙米", "amount": 80, "unit": "g", "rawGrams": 80}]}]},
    {"meals": [{"mealType": "dinner", "name": "不该出现", "calories": 500, "method": "煮熟。", "ingredients": [{"name": "鸡蛋", "amount": 1, "unit": "个", "rawGrams": 50}]}]}
  ]
}
```
''';
    final draft = parseAiBasketPlan(
      raw,
      items: stock(),
      calorieCap: 1200,
      dayCount: 1,
      fallbackSummary: '本地',
    );

    expect(draft, isNotNull);
    expect(draft!.fromAi, isTrue);
    expect(draft.days, hasLength(1));
    expect(draft.days.single.calories, 1200);
    expect(draft.days.single.meals.first.method, contains('煮'));
    expect(
        draft.days.single.meals.first.ingredients.single.rawGrams, isNotNull);
    expect(draft.shopping.single.name, '西兰花');
    expect(draft.usages.single.itemId, 'egg');
    expect(draft.usages.single.amount, 4);
    expect(draft.summary, '两天够吃');
  });

  test('菜篮子保存在本机，清空业务数据时一起清掉', () async {
    SharedPreferences.setMockInitialValues({});
    final repository = AppRepository();
    await repository.load();
    await repository.addBasketItem(
      item(
        id: 'apple',
        name: '苹果',
        categoryId: 'fruit',
        amount: 2,
        unit: '个',
        kcal: 53,
      ),
    );

    final again = AppRepository();
    await again.load();
    expect(again.basketItems, hasLength(1));
    expect(again.basketItems.single.name, '苹果');
    expect(again.exportJson(), contains('basketItems'));

    await again.applyBasketUsage(
      again.basketItems.map((entry) {
        return BasketUsage(
          itemId: entry.id,
          name: entry.name,
          amount: 1,
          unit: entry.unit,
        );
      }).toList(),
    );
    expect(again.basketItems.single.amount, 1);

    await again.clearBusinessData();
    expect(again.basketItems, isEmpty);
    expect(again.recipes, isNotEmpty);
  });
}
