import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ios_demo/main.dart';

void main() {
  testWidgets('counter increments and resets', (WidgetTester tester) async {
    await tester.pumpWidget(const IosDemoApp());

    expect(find.text('iOS Demo'), findsOneWidget);
    expect(
      tester.widget<Text>(find.byKey(const Key('counter-value'))).data,
      '0',
    );

    await tester.tap(find.text('加一'));
    await tester.pump();
    expect(
      tester.widget<Text>(find.byKey(const Key('counter-value'))).data,
      '1',
    );

    await tester.tap(find.text('归零'));
    await tester.pump();
    expect(
      tester.widget<Text>(find.byKey(const Key('counter-value'))).data,
      '0',
    );
  });

  testWidgets('greeting uses the entered name', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const IosDemoApp());

    await tester.enterText(find.byType(TextField), 'iPhone');
    await tester.tap(find.text('打招呼'));
    await tester.pump();

    expect(find.text('你好，iPhone！'), findsOneWidget);
  });
}
