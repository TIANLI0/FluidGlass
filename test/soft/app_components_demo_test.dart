import 'package:fluid_glass/fluid_glass.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

// Exercise the separate example package with this library's regression suite.
// ignore: avoid_relative_lib_imports
import '../../example/lib/soft_demo/app_components_page.dart';

Widget _app({bool dark = false, double scale = 1}) => MaterialApp(
  builder: (BuildContext context, Widget? child) => SoftTheme(
    data: dark ? const SoftThemeData.dark() : const SoftThemeData.light(),
    child: MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: TextScaler.linear(scale)),
      child: DefaultTextStyle(
        style: const TextStyle(fontSize: 14, color: Colors.black),
        child: child!,
      ),
    ),
  ),
  home: const Scaffold(body: SoftAppComponentsPage()),
);

void main() {
  testWidgets(
    'birthday cancel preserves null; confirm commits the selected year',
    (tester) async {
      await tester.pumpWidget(_app());
      expect(find.text('生日：尚未选择'), findsOneWidget);
      await tester.tap(find.text('选择出生日期'));
      await tester.pumpAndSettle();
      expect(find.byType(SoftDatePicker), findsOneWidget);
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();
      expect(find.text('生日：尚未选择'), findsOneWidget);
      await tester.tap(find.text('选择出生日期'));
      await tester.pumpAndSettle();
      tester
          .widget<SoftNumberPicker>(
            find
                .descendant(
                  of: find.byType(SoftDatePicker),
                  matching: find.byType(SoftNumberPicker),
                )
                .first,
          )
          .onChanged!(2000);
      await tester.pump();
      await tester.tap(find.text('确定'));
      await tester.pumpAndSettle();
      expect(find.textContaining('生日：2000-'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('chat menu preserves the framework copy action', (tester) async {
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (MethodCall call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map<Object?, Object?>)['text'] as String?;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    await tester.pumpWidget(_app());
    await tester.scrollUntilVisible(
      find.byType(SelectableText),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.longPress(find.byType(SelectableText));
    await tester.pumpAndSettle();
    expect(find.byType(SoftTextSelectionMenu), findsOneWidget);
    await tester.tap(find.text('Copy'));
    await tester.pumpAndSettle();
    expect(copied, isNotEmpty);
    expect(find.byType(SoftTextSelectionMenu), findsNothing);
    expect(tester.takeException(), isNull);
  });

  for (final bool dark in <bool>[false, true]) {
    testWidgets(
      'component page scrolls and opens its menu with large text (dark: $dark)',
      (tester) async {
        await tester.pumpWidget(_app(dark: dark, scale: 2));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.scrollUntilVisible(
          find.text('更多操作'),
          250,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.tap(find.text('更多操作'));
        await tester.pumpAndSettle();
        expect(find.byType(SoftHorizontalPopupMenu), findsOneWidget);
        await tester.tap(find.text('分享'));
        await tester.pumpAndSettle();
        expect(find.byType(SoftHorizontalPopupMenu), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
