import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xiaoyier/app.dart';
import 'package:xiaoyier/data/app_repository.dart';
import 'package:xiaoyier/features/recipes/recipe_edit_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<AppRepository> buildRepository({
    bool onboardingDone = false,
  }) async {
    SharedPreferences.setMockInitialValues({});
    final repository = AppRepository();
    await repository.load();
    if (onboardingDone) {
      await repository.updateProfile(
        repository.profile.copyWith(
          onboardingDone: true,
          nickname: '小一二',
          startWeightKg: 65,
          heightCm: 165,
          birthYear: 1998,
          targetWeightKg: 58,
          waterGoalMl: 2200,
        ),
      );
    }
    return repository;
  }

  testWidgets('首次启动展示引导页', (tester) async {
    final repository = await buildRepository();
    await tester.pumpWidget(
      ChangeNotifierProvider<AppRepository>.value(
        value: repository,
        child: const XiaoyierApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('小一二减肥记'), findsWidgets);
    expect(find.text('开始使用'), findsOneWidget);
    expect(find.text('数据只属于你'), findsOneWidget);
  });

  testWidgets('完成引导后进入今日页', (tester) async {
    final repository = await buildRepository(onboardingDone: true);
    await tester.pumpWidget(
      ChangeNotifierProvider<AppRepository>.value(
        value: repository,
        child: const XiaoyierApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('今日体重'), findsOneWidget);
    expect(find.text('今日热量'), findsOneWidget);
    expect(find.text('今日餐单'), findsOneWidget);
    expect(find.text('记录体重'), findsWidgets);
  });

  testWidgets('完成引导后写入资料和初始体重', (tester) async {
    final repository = await buildRepository();
    await tester.pumpWidget(
      ChangeNotifierProvider<AppRepository>.value(
        value: repository,
        child: const XiaoyierApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('开始使用'));
    await tester.pumpAndSettle();
    expect(find.text('先认识一下你'), findsOneWidget);

    await tester.tap(find.text('下一步'));
    await tester.pumpAndSettle();
    expect(find.text('想到达哪里？'), findsOneWidget);

    await tester.tap(find.text('下一步'));
    await tester.pumpAndSettle();
    expect(find.text('平时活动多吗？'), findsOneWidget);

    await tester.tap(find.text('完成'));
    await tester.pumpAndSettle();

    expect(repository.profile.onboardingDone, isTrue);
    expect(repository.profile.startWeightKg, 65);
    expect(repository.weightRecords.length, 1);
    expect(find.text('今日体重'), findsOneWidget);
  });

  testWidgets('新增自定义食谱并保存', (tester) async {
    final repository = await buildRepository(onboardingDone: true);
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
                      builder: (_) => const RecipeEditPage(),
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
    expect(find.text('新增食谱'), findsOneWidget);

    await tester.enterText(find.byType(TextField).at(0), '测试鸡胸肉');
    await tester.enterText(find.byType(TextField).at(1), '320');
    await tester.dragUntilVisible(
      find.text('添加食谱'),
      find.byType(ListView),
      const Offset(0, -300),
    );
    await tester.tap(find.text('添加食谱'));
    await tester.pumpAndSettle();

    expect(repository.customRecipes.length, 1);
    final recipe = repository.customRecipes.first;
    expect(recipe.name, '测试鸡胸肉');
    expect(recipe.calories, 320);
    expect(recipe.isBuiltin, isFalse);
  });
}
