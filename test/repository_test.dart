import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xiaoyier/core/app_date.dart';
import 'package:xiaoyier/data/app_repository.dart';
import 'package:xiaoyier/models/models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppRepository repository;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    repository = AppRepository();
    await repository.load();
  });

  test('首次加载预置 22 道内置食谱', () {
    expect(repository.recipes.length, 22);
    expect(repository.recipes.every((recipe) => recipe.isBuiltin), isTrue);
    expect(repository.profile.onboardingDone, isFalse);
  });

  test('同一天多条体重，代表体重取最后一条', () async {
    final date = AppDate.todayKey();
    await repository.addWeight(
      WeightRecord(
        id: repository.newId(),
        date: date,
        recordedAt: DateTime.now().subtract(const Duration(hours: 2)),
        weightKg: 65.2,
      ),
    );
    await repository.addWeight(
      WeightRecord(
        id: repository.newId(),
        date: date,
        recordedAt: DateTime.now(),
        weightKg: 64.9,
      ),
    );
    expect(repository.weightForDate(date), 64.9);
    expect(repository.weightsForDate(date).length, 2);
  });

  test('打卡联动热量与完成度', () async {
    final date = AppDate.todayKey();
    await repository.addMealEntry(
      MealEntry(
        id: repository.newId(),
        date: date,
        mealType: 'breakfast',
        name: '燕麦牛奶碗',
        calories: 280,
      ),
    );
    await repository.addMealEntry(
      MealEntry(
        id: repository.newId(),
        date: date,
        mealType: 'lunch',
        name: '鸡胸肉糙米饭',
        calories: 420,
        status: 'completed',
        completedAt: DateTime.now(),
      ),
    );

    var summary = repository.summaryFor(date);
    expect(summary.plannedKcal, 700);
    expect(summary.consumedKcal, 420);
    expect(summary.completedCount, 1);
    expect(summary.meals['lunch']!.allDone, isTrue);

    final breakfast = repository.entriesFor(date, mealType: 'breakfast').first;
    await repository.setEntryCompleted(breakfast.id, true);
    summary = repository.summaryFor(date);
    expect(summary.consumedKcal, 700);
    expect(summary.completedCount, 2);
    expect(summary.meals['breakfast']!.allDone, isTrue);
  });

  test('喝水累计与连续打卡', () async {
    final today = AppDate.today();
    final yesterday = today.subtract(const Duration(days: 1));
    await repository.addWater(300);
    await repository.addWater(500);
    expect(repository.waterTotalFor(AppDate.key(today)), 800);

    await repository.addWeight(
      WeightRecord(
        id: repository.newId(),
        date: AppDate.key(yesterday),
        recordedAt: yesterday,
        weightKg: 65,
      ),
    );
    expect(repository.streak, 2);
  });

  test('清空业务数据保留资料与食谱', () async {
    await repository.updateProfile(
      repository.profile.copyWith(onboardingDone: true, nickname: '测试'),
    );
    await repository.addWater(300);
    await repository.addWeight(
      WeightRecord(
        id: repository.newId(),
        date: AppDate.todayKey(),
        recordedAt: DateTime.now(),
        weightKg: 65,
      ),
    );
    await repository.clearBusinessData();
    expect(repository.weightRecords, isEmpty);
    expect(repository.waterLogs, isEmpty);
    expect(repository.mealEntries, isEmpty);
    expect(repository.recipes.length, 22);
    expect(repository.profile.nickname, '测试');
  });

  test('导出 JSON 与 CSV 包含数据', () async {
    await repository.addWater(300);
    final json = repository.exportJson();
    expect(json, contains('小一二减肥记'));
    expect(json, contains('waterLogs'));
    expect(repository.exportWaterCsv(), contains('300'));
    expect(repository.exportWeightsCsv(), contains('日期'));
  });
}
