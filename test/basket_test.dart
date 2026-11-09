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

  test('热量库按分类覆盖主食、肉禽、水果等', () {
    expect(
      foodCategories.map((item) => item.name),
      containsAll(['主食谷物', '肉禽', '水产', '蔬菜', '水果', '菌藻']),
    );
    expect(foodByName('鸡胸肉')?.kcal, 133);
    expect(foodByName('鸡蛋')?.caloriesFor(2), 140);
    expect(foodByName('米饭')?.caloriesFor(150), 174);
  });

  test('食材不够一天时给出少量采购建议', () {
    final draft = buildLocalBasketPlan([
      item(
        id: 'apple',
        name: '苹果',
        categoryId: 'fruit',
        amount: 100,
        unit: 'g',
        kcal: 53,
      ),
    ], 1500);

    expect(draft.supportedDays, 0);
    expect(draft.days, hasLength(1));
    expect(draft.days.single.calories, lessThanOrEqualTo(1500));
    expect(draft.shopping, isNotEmpty);
    expect(draft.summary, contains('凑不齐'));
    expect(draft.canSave, isTrue);
  });

  test('余量够吃几天就只排几天，且不超过热量上限', () {
    final oneDay = buildLocalBasketPlan(stock(), 1200);
    expect(oneDay.supportedDays, 1);
    expect(oneDay.days, hasLength(1));
    expect(oneDay.days.single.calories, lessThanOrEqualTo(1200));

    final longer = buildLocalBasketPlan(stock(scale: 4), 1200);
    expect(longer.supportedDays, greaterThanOrEqualTo(3));
    expect(longer.days, hasLength(longer.supportedDays));
    for (final day in longer.days) {
      expect(day.calories, lessThanOrEqualTo(1200));
      expect(day.meals, isNotEmpty);
    }
    final usedEggs = longer.usages
        .firstWhere((usage) => usage.itemId == 'egg')
        .amount;
    expect(usedEggs, lessThanOrEqualTo(16));
  });

  test('解析 AI 食谱时按余量截断天数', () {
    const raw = '''
```json
{
  "summary": "两天够吃",
  "shopping": [{"name": "西兰花", "amount": 200, "unit": "g", "reason": "可选，补蔬菜"}],
  "usages": [{"id": "egg", "amount": 4}],
  "days": [
    {"meals": [{"mealType": "breakfast", "name": "水煮蛋", "calories": 140}, {"mealType": "lunch", "name": "鸡胸糙米", "calories": 500}, {"mealType": "dinner", "name": "西兰花鸡胸", "calories": 400}]},
    {"meals": [{"mealType": "lunch", "name": "第二天", "calories": 600}]},
    {"meals": [{"mealType": "dinner", "name": "不该出现", "calories": 500}]}
  ]
}
```
''';
    final draft = parseAiBasketPlan(
      raw,
      items: stock(),
      calorieCap: 1200,
      supportedDays: 1,
      fallbackSummary: '本地',
    );

    expect(draft, isNotNull);
    expect(draft!.fromAi, isTrue);
    expect(draft.days, hasLength(1));
    expect(draft.days.single.calories, lessThanOrEqualTo(1200));
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
