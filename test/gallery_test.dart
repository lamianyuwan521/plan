import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xiaoyier/app.dart';
import 'package:xiaoyier/data/app_repository.dart';
import 'package:xiaoyier/features/gallery/gallery_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppRepository repository;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    repository = AppRepository();
    await repository.load();
    await repository.updateProfile(
      repository.profile.copyWith(onboardingDone: true, sidebarExpanded: true),
    );
  });

  testWidgets('图集页展示空状态和分类入口', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ChangeNotifierProvider<AppRepository>.value(
        value: repository,
        child: const MaterialApp(home: Scaffold(body: GalleryPage())),
      ),
    );
    await tester.pump();

    expect(find.text('图集'), findsOneWidget);
    expect(find.text('还没有图片'), findsOneWidget);
    expect(find.text('全部 · 0'), findsOneWidget);
    expect(find.text('新分类'), findsOneWidget);
    expect(find.text('上传'), findsOneWidget);
  });

  testWidgets('侧栏可以进入图集', (tester) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ChangeNotifierProvider<AppRepository>.value(
        value: repository,
        child: const XiaoyierApp(),
      ),
    );
    await tester.pump();

    expect(find.text('图集'), findsOneWidget);
    await tester.tap(find.text('图集'));
    await tester.pump();
    expect(find.text('还没有图片'), findsOneWidget);
    expect(find.text('新分类'), findsOneWidget);
  });
}
