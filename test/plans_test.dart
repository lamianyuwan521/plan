import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xiaoyier/data/app_repository.dart';
import 'package:xiaoyier/data/seed_plans.dart';
import 'package:xiaoyier/features/recipes/plan_detail_page.dart';
import 'package:xiaoyier/features/recipes/plan_view.dart';
import 'package:xiaoyier/models/models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('内置长期方案', () {
    test('包含 5 套方案且天数正确', () {
      expect(seedPlans.length, 5);
      expect(seedPlans.map((plan) => plan.days.length).toList(), [
        7,
        7,
        5,
        5,
        43,
      ]);
      expect(seedPlans.map((plan) => plan.id).toSet().length, 5);
    });

    test('每天都有合法的餐次和正数热量', () {
      for (final plan in seedPlans) {
        expect(plan.name.trim(), isNotEmpty, reason: plan.id);
        expect(plan.days, isNotEmpty, reason: plan.id);
        for (final day in plan.days) {
          expect(day.meals, isNotEmpty, reason: plan.id);
          final types = day.meals.map((meal) => meal.mealType).toList();
          expect(types.toSet().length, types.length, reason: plan.id);
          for (final meal in day.meals) {
            expect(
              const ['breakfast', 'lunch', 'dinner'],
              contains(meal.mealType),
              reason: plan.id,
            );
            expect(meal.name.trim(), isNotEmpty, reason: plan.id);
            expect(meal.calories, greaterThan(0), reason: plan.id);
          }
        }
      }
    });

    test('7 天方案保留参考体重', () {
      final plan = planById('plan-7day')!;
      expect(plan.days.first.weightJin, 117.7);
      expect(plan.days[1].weightJin, 116.2);
    });

    test('110-100 覆盖率到 43 天，最后一天是一拳餐盘', () {
      final plan = planById('plan-110-100')!;
      expect(plan.days.length, 43);
      final last = plan.days.last;
      expect(last.mealOf('breakfast')!.name, contains('椰子水'));
      expect(last.mealOf('lunch')!.name, contains('一拳'));
      expect(last.mealOf('dinner'), isNull);
    });
  });

  group('批量安排饮食', () {
    late AppRepository repository;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      repository = AppRepository();
      await repository.load();
    });

    test('批量加入后按餐次排序，批量撤销后清空', () async {
      const date = '2026-10-28';
      final entries = [
        MealEntry(
          id: repository.newId(),
          date: date,
          mealType: 'lunch',
          name: '🥚 x2',
          calories: 140,
          sortOrder: 0,
        ),
        MealEntry(
          id: repository.newId(),
          date: date,
          mealType: 'breakfast',
          name: '冰美式 + 🥚',
          calories: 80,
          sortOrder: 0,
        ),
        MealEntry(
          id: repository.newId(),
          date: date,
          mealType: 'breakfast',
          name: '全冰奶酪 + 🥚',
          calories: 290,
          sortOrder: 1,
        ),
      ];

      await repository.addMealEntries(entries);
      final saved = repository.entriesFor(date);
      expect(saved.length, 3);
      expect(saved.first.mealType, 'breakfast');
      expect(saved[1].name, '全冰奶酪 + 🥚');
      expect(repository.summaryFor(date).plannedKcal, 510);

      await repository.deleteMealEntries(entries.map((entry) => entry.id));
      expect(repository.entriesFor(date), isEmpty);
    });
  });

  testWidgets('方案详情展示每日餐次并可以打开加入面板', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final repository = AppRepository();
    await repository.load();

    await tester.pumpWidget(
      ChangeNotifierProvider<AppRepository>.value(
        value: repository,
        child: const MaterialApp(home: PlanDetailPage(planId: 'plan-7day')),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('7天极速掉秤'), findsOneWidget);
    expect(find.text('第 1 天'), findsOneWidget);
    expect(find.text('体重 117.7 斤'), findsOneWidget);
    expect(find.text('2 个磨牙棒 + 2 小包辣条'), findsOneWidget);

    await tester.tap(find.text('加入计划'));
    await tester.pumpAndSettle();

    expect(find.text('开始日期'), findsOneWidget);
    expect(find.text('结束日期'), findsOneWidget);
    expect(find.text('加入 7 天计划'), findsOneWidget);
  });

  testWidgets('计划页在宽屏下展示全部长期方案', (tester) async {
    tester.view.physicalSize = const Size(1200, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    SharedPreferences.setMockInitialValues({});
    final repository = AppRepository();
    await repository.load();

    await tester.pumpWidget(
      ChangeNotifierProvider<AppRepository>.value(
        value: repository,
        child: const MaterialApp(home: Scaffold(body: PlanView())),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('长期食谱'), findsOneWidget);
    for (final plan in seedPlans) {
      expect(find.text(plan.name), findsOneWidget);
    }
    expect(tester.takeException(), isNull);
  });
}
