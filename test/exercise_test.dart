import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xiaoyier/data/app_repository.dart';
import 'package:xiaoyier/data/seed_exercises.dart';
import 'package:xiaoyier/data/seed_plans.dart';
import 'package:xiaoyier/features/exercise/exercise_page.dart';
import 'package:xiaoyier/features/recipes/plan_edit_page.dart';
import 'package:xiaoyier/models/exercise.dart';
import 'package:xiaoyier/models/models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('内置运动视频', () {
    test('分类和视频数据完整，封面已打包', () {
      expect(exerciseCategories.length, 7);
      expect(seedExercises.length, 42);
      final ids = seedExercises.map((video) => video.id).toSet();
      expect(ids.length, seedExercises.length);

      for (final video in seedExercises) {
        expect(video.title.trim(), isNotEmpty, reason: video.id);
        expect(video.uploader.trim(), isNotEmpty, reason: video.id);
        expect(video.bvid, startsWith('BV'), reason: video.id);
        expect(video.url, contains(video.bvid), reason: video.id);
        expect(video.durationSeconds, greaterThan(0), reason: video.id);
        expect(video.playCount, greaterThan(0), reason: video.id);
        expect(
          exerciseCategories.map((category) => category.id),
          contains(video.category),
          reason: video.id,
        );
        expect(video.coverAsset, isNotNull, reason: video.id);
        expect(
          File(video.coverAsset!).existsSync(),
          isTrue,
          reason: '${video.coverAsset} 不存在',
        );
      }
    });

    test('标题、UP 主和时长来自已校验的数据', () {
      final pamela = seedExercises.firstWhere(
        (video) => video.id == 'BV1R3411A7g4',
      );
      expect(pamela.uploader, '帕梅拉PamelaReif');
      expect(pamela.durationLabel, '11:27');
      expect(pamela.playLabel, '6417 万');
    });
  });

  group('运动收藏与计划', () {
    late AppRepository repository;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      repository = AppRepository();
      await repository.load();
    });

    test('收藏写入后重新加载仍在，取消后移除', () async {
      const id = 'BV1jhe3zhET3';
      expect(repository.isExerciseFavorite(id), isFalse);
      await repository.toggleExerciseFavorite(id);
      expect(repository.isExerciseFavorite(id), isTrue);
      expect(repository.favoriteExercises.single.id, id);

      final reloaded = AppRepository();
      await reloaded.load();
      expect(reloaded.isExerciseFavorite(id), isTrue);
      expect(reloaded.favoriteExercises.length, 1);

      await reloaded.toggleExerciseFavorite(id);
      final again = AppRepository();
      await again.load();
      expect(again.isExerciseFavorite(id), isFalse);
      expect(again.favoriteExercises, isEmpty);
    });

    test('加入计划、完成后持久化，可移除', () async {
      const date = '2026-10-28';
      const id = 'BV1QS4y1P7Yu';
      final entry = ExercisePlanEntry(
        id: repository.newId(),
        exerciseId: id,
        date: date,
        createdAt: DateTime(2026, 10, 27, 9),
      );
      await repository.addExerciseEntry(entry);
      expect(repository.hasExerciseOnDate(id, date), isTrue);
      expect(repository.exerciseEntriesFor(date).single.completed, isFalse);

      await repository.setExerciseCompleted(entry.id, true);
      final reloaded = AppRepository();
      await reloaded.load();
      final saved = reloaded.exerciseEntriesFor(date).single;
      expect(saved.completed, isTrue);
      expect(saved.completedAt, isNotNull);
      expect(reloaded.exerciseEntriesFor('2026-10-29'), isEmpty);

      await reloaded.deleteExerciseEntry(entry.id);
      expect(reloaded.exerciseEntriesFor(date), isEmpty);
    });
  });

  group('自定义长期食谱', () {
    late AppRepository repository;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      repository = AppRepository();
      await repository.load();
    });

    DietPlan buildPlan({String id = 'custom-1', String name = '我的轻断食'}) {
      return DietPlan(
        id: id,
        name: name,
        description: '自己搭的方案',
        tags: const ['长期', '控卡'],
        days: const [
          PlanDay(
            weightJin: 118,
            meals: [
              PlanMeal(mealType: 'breakfast', name: '冰美式 + 鸡蛋', calories: 180),
              PlanMeal(mealType: 'lunch', name: '鸡胸肉 + 糙米', calories: 520),
            ],
          ),
        ],
        isCustom: true,
      );
    }

    test('新增、改名、删除并持久化', () async {
      await repository.addDietPlan(buildPlan());
      expect(repository.customDietPlans.length, 1);
      expect(repository.dietPlans.length, seedPlans.length + 1);
      expect(repository.dietPlanById('custom-1')!.name, '我的轻断食');
      expect(repository.dietPlanById('custom-1')!.isCustom, isTrue);

      await repository.updateDietPlan(buildPlan(name: '我的 14 天轻断食'));
      final reloaded = AppRepository();
      await reloaded.load();
      expect(reloaded.dietPlanById('custom-1')!.name, '我的 14 天轻断食');
      expect(reloaded.dietPlanById('custom-1')!.days.single.calories, 700);

      await reloaded.deleteDietPlan('custom-1');
      expect(reloaded.customDietPlans, isEmpty);
      expect(reloaded.dietPlanById('custom-1'), isNull);
    });

    test('内置方案不可删除', () async {
      await repository.deleteDietPlan('plan-7day');
      expect(repository.dietPlanById('plan-7day'), isNotNull);
      expect(repository.customDietPlans, isEmpty);
    });

    testWidgets('新建长期食谱可以自定义名称并保存三餐', (tester) async {
      await tester.pumpWidget(
        ChangeNotifierProvider<AppRepository>.value(
          value: repository,
          child: MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: Center(
                  child: TextButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const PlanEditPage(),
                      ),
                    ),
                    child: const Text('打开'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('打开'));
      await tester.pumpAndSettle();
      expect(find.text('新建长期食谱'), findsOneWidget);

      await tester.enterText(find.byType(TextField).at(0), '我的 10 天轻断食');
      await tester.enterText(find.byType(TextField).at(1), '工作日晚餐少一点');
      await tester.enterText(find.byType(TextField).at(2), '长期，控卡');

      await tester.tap(find.text('还没有安排，点这里添加三餐'));
      await tester.pumpAndSettle();
      expect(find.text('第 1 天'), findsWidgets);

      // 弹层里的字段排在编辑页三个字段之后：体重、备注、早餐内容/热量……
      await tester.enterText(find.byType(TextField).at(3), '118');
      await tester.enterText(find.byType(TextField).at(5), '冰美式 + 鸡蛋');
      await tester.enterText(find.byType(TextField).at(6), '180');
      await tester.ensureVisible(find.text('完成'));
      await tester.tap(find.text('完成'));
      await tester.pumpAndSettle();
      expect(find.text('冰美式 + 鸡蛋'), findsOneWidget);

      await tester.ensureVisible(find.text('创建长期食谱'));
      await tester.tap(find.text('创建长期食谱'));
      await tester.pumpAndSettle();

      expect(repository.customDietPlans.length, 1);
      final plan = repository.customDietPlans.first;
      expect(plan.name, '我的 10 天轻断食');
      expect(plan.description, '工作日晚餐少一点');
      expect(plan.tags, ['长期', '控卡']);
      expect(plan.days.single.weightJin, 118);
      expect(plan.days.single.meals.single.name, '冰美式 + 鸡蛋');
      expect(plan.days.single.meals.single.calories, 180);
    });
  });

  testWidgets('运动页展示分类和热门视频', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final repository = AppRepository();
    await repository.load();

    await tester.pumpWidget(
      ChangeNotifierProvider<AppRepository>.value(
        value: repository,
        child: const MaterialApp(home: Scaffold(body: ExercisePage())),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('运动'), findsOneWidget);
    expect(find.text('推荐'), findsOneWidget);
    expect(find.text('收藏'), findsWidgets);
    expect(find.text('计划'), findsOneWidget);
    for (final category in exerciseCategories) {
      expect(find.text(category.name), findsWidgets);
    }
    expect(find.textContaining('MIZI 15分钟哑铃上半身锻炼'), findsOneWidget);
    expect(find.text('加入计划'), findsWidgets);
  });
}
