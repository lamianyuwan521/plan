import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xiaoyier/core/app_date.dart';
import 'package:xiaoyier/data/app_repository.dart';
import 'package:xiaoyier/models/gallery.dart';
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

  test('图集可以自行分类，删除分类后图片留在未分类', () async {
    final food = await repository.addGalleryCategory('饮食');
    final body = await repository.addGalleryCategory('身材');
    expect(food, isNotNull);
    expect(body, isNotNull);
    expect(await repository.addGalleryCategory('饮食'), isNull);
    expect(await repository.addGalleryCategory('  '), isNull);
    expect(await repository.renameGalleryCategory(body!.id, '饮食'), isFalse);
    expect(await repository.renameGalleryCategory(body.id, '体态'), isTrue);

    final saved = await repository.addGalleryPhotos(
      categoryId: food!.id,
      photos: [
        GalleryPhotoInput(
          bytes: Uint8List.fromList(const [1, 2, 3, 4]),
          width: 400,
          height: 800,
        ),
        GalleryPhotoInput(
          bytes: Uint8List.fromList(const [5, 6]),
          width: 800,
          height: 400,
        ),
      ],
    );
    expect(saved, 2);
    expect(repository.galleryPhotos.first.categoryId, food.id);
    expect(repository.galleryPhotos.first.width, 400);
    final bytes = await repository.loadGalleryPhoto(
      repository.galleryPhotos.first.id,
    );
    expect(bytes, [1, 2, 3, 4]);
    expect(repository.exportJson(), contains('galleryPhotos'));
    expect(repository.exportJson(), contains('饮食'));

    await repository.deleteGalleryCategory(food.id);
    expect(repository.galleryCategories.map((item) => item.name), ['体态']);
    expect(
      repository.galleryPhotos.every((photo) => photo.categoryId == null),
      isTrue,
    );

    await repository.setGalleryPhotoCategory(
      repository.galleryPhotos.first.id,
      body.id,
    );
    expect(
      repository.galleryPhotos.where((photo) => photo.categoryId == body.id),
      hasLength(1),
    );

    final removedId = repository.galleryPhotos.last.id;
    await repository.deleteGalleryPhoto(removedId);
    expect(await repository.loadGalleryPhoto(removedId), isNull);
    expect(repository.galleryPhotos, hasLength(1));

    await repository.clearBusinessData();
    expect(repository.galleryPhotos, isEmpty);
    expect(repository.galleryCategories, isEmpty);
    expect(repository.recipes, hasLength(22));
    expect(repository.profile.nickname, isNotEmpty);
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
