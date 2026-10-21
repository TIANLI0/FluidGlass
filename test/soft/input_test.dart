import 'package:fluid_glass/fluid_glass.dart';
import 'package:fluid_glass/src/soft/components/input/soft_input_shared.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'surface.dart';

Widget _harness(Widget child, {bool dark = false}) {
  return WidgetsApp(
    color: const Color(0xFF000000),
    pageRouteBuilder: <T>(RouteSettings settings, WidgetBuilder builder) =>
        PageRouteBuilder<T>(
          settings: settings,
          pageBuilder:
              (
                BuildContext context,
                Animation<double> animation,
                Animation<double> secondary,
              ) => builder(context),
        ),
    home: SoftTheme(
      data: dark ? const SoftThemeData.dark() : const SoftThemeData.light(),
      child: Align(
        alignment: Alignment.topCenter,
        child: SizedBox(width: 360, child: child),
      ),
    ),
  );
}

/// Pumps past every timed animation of the group without pumpAndSettle.
Future<void> _settle(WidgetTester tester) async {
  for (int i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  expect(tester.binding.transientCallbackCount, 0);
}

const double _bodyLine = 16 * 1.158;

void main() {
  usePhoneSurface();

  group('SoftTextField', () {
    for (final bool dark in <bool>[false, true]) {
      testWidgets('lays out each mode (${dark ? 'dark' : 'light'})', (
        WidgetTester tester,
      ) async {
        await tester.pumpWidget(
          _harness(
            const Column(
              children: <Widget>[
                SoftTextField(key: Key('line'), label: '设备名称'),
                SoftTextField(
                  key: Key('rect'),
                  label: '矩形',
                  mode: SoftTextFieldMode.rectangle,
                ),
                SoftTextField(
                  key: Key('none'),
                  label: '无装饰',
                  mode: SoftTextFieldMode.none,
                ),
              ],
            ),
            dark: dark,
          ),
        );
        expect(
          tester.getSize(find.byKey(const Key('line'))).height,
          moreOrLessEquals(_bodyLine + 30, epsilon: 0.5),
        );
        expect(
          tester.getSize(find.byKey(const Key('rect'))).height,
          moreOrLessEquals(_bodyLine + 24, epsilon: 0.5),
        );
        expect(
          tester.getSize(find.byKey(const Key('none'))).height,
          moreOrLessEquals(_bodyLine + 18, epsilon: 0.5),
        );
        expect(tester.getSize(find.byKey(const Key('line'))).width, 360);
        final EditableText rect = tester.widget<EditableText>(
          find.descendant(
            of: find.byKey(const Key('rect')),
            matching: find.byType(EditableText),
          ),
        );
        expect(rect.style.fontWeight, FontWeight.w700);
        expect(
          rect.style.color,
          dark
              ? const SoftColors.dark().onBackground
              : const SoftColors.light().onBackground,
        );
        expect(tester.binding.transientCallbackCount, 0);
      });
    }

    testWidgets('the placeholder hides once there is text', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_harness(const SoftTextField(label: '设备名称')));
      expect(find.text('设备名称'), findsOneWidget);
      await tester.enterText(find.byType(EditableText), 'abc');
      await tester.pump();
      expect(find.text('设备名称'), findsNothing);
      await _settle(tester);
    });

    testWidgets('the clear button shows while focused and clears', (
      WidgetTester tester,
    ) async {
      final TextEditingController controller = TextEditingController();
      addTearDown(controller.dispose);
      String? changed;
      await tester.pumpWidget(
        _harness(
          SoftTextField(
            controller: controller,
            label: '设备名称',
            showClearButton: true,
            clearButtonSemanticLabel: '清除',
            onChanged: (String v) => changed = v,
          ),
        ),
      );
      expect(find.byType(SoftInputIconButton), findsNothing);
      await tester.enterText(find.byType(EditableText), 'abc');
      await _settle(tester);
      expect(find.byType(SoftInputIconButton), findsOneWidget);
      expect(find.bySemanticsLabel('清除'), findsOneWidget);

      await tester.tap(find.byType(SoftInputIconButton));
      await tester.pump();
      expect(controller.text, isEmpty);
      expect(changed, '');
      await _settle(tester);
      expect(find.byType(SoftInputIconButton), findsNothing);
    });

    testWidgets('maxCount truncates and counts', (WidgetTester tester) async {
      final TextEditingController controller = TextEditingController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        _harness(
          SoftTextField(controller: controller, label: '最多', maxCount: 10),
        ),
      );
      expect(find.text('0/10'), findsOneWidget);
      await tester.enterText(find.byType(EditableText), '0123456789abc');
      await tester.pump();
      expect(controller.text, '0123456789');
      expect(find.text('10/10'), findsOneWidget);
      await _settle(tester);
      final Text counter = tester.widget<Text>(find.text('10/10'));
      expect(counter.style!.color, const SoftColors.light().error);
      expect(counter.style!.fontSize, 10);
    });

    testWidgets('the eye toggles the mask', (WidgetTester tester) async {
      await tester.pumpWidget(
        _harness(
          const SoftTextField(
            label: '密码',
            showPasswordToggle: true,
            showPasswordSemanticLabel: '显示密码',
            hidePasswordSemanticLabel: '隐藏密码',
          ),
        ),
      );
      EditableText editable() =>
          tester.widget<EditableText>(find.byType(EditableText));
      expect(editable().obscureText, isTrue);
      expect(find.bySemanticsLabel('显示密码'), findsOneWidget);
      await tester.tap(find.byType(SoftInputIconButton));
      await tester.pump(const Duration(milliseconds: 400));
      expect(editable().obscureText, isFalse);
      expect(find.bySemanticsLabel('隐藏密码'), findsOneWidget);
      await _settle(tester);
    });

    testWidgets('an error shakes the text and settles', (
      WidgetTester tester,
    ) async {
      Widget field(bool error) =>
          _harness(SoftTextField(label: '仅数字', isError: error));
      await tester.pumpWidget(field(false));
      await tester.pumpWidget(field(true));
      Offset textOffset() => tester.getTopLeft(find.byType(EditableText));
      final Offset rest = textOffset();
      await tester.pump(const Duration(milliseconds: 83));
      expect(textOffset().dx, lessThan(rest.dx - 4));
      await tester.pump(const Duration(milliseconds: 133));
      expect(textOffset().dx, greaterThan(rest.dx + 2));
      await _settle(tester);
      expect(textOffset().dx, rest.dx);
      final Text label = tester.widget<Text>(find.text('仅数字'));
      expect(label.style!.color, const SoftColors.light().error);
    });

    testWidgets('the label floats while focused', (WidgetTester tester) async {
      await tester.pumpWidget(
        _harness(
          const SoftTextField(
            label: '浮动标签',
            useLabelAsPlaceholder: false,
            mode: SoftTextFieldMode.rectangle,
          ),
        ),
      );
      final Rect resting = tester.getRect(find.text('浮动标签'));
      expect(resting.height, moreOrLessEquals(_bodyLine, epsilon: 0.5));
      await tester.showKeyboard(find.byType(EditableText));
      await tester.pump(const Duration(milliseconds: 100));
      expect(
        tester.getRect(find.text('浮动标签')).height,
        lessThan(resting.height),
      );
      await _settle(tester);
      final Rect floating = tester.getRect(find.text('浮动标签'));
      expect(
        floating.height,
        moreOrLessEquals(_bodyLine * 10 / 16, epsilon: 0.5),
      );
      expect(floating.top, moreOrLessEquals(resting.top - 6, epsilon: 0.5));
      // The label stays up while there is text.
      await tester.enterText(find.byType(EditableText), 'a');
      FocusManager.instance.primaryFocus?.unfocus();
      await _settle(tester);
      expect(find.text('浮动标签'), findsOneWidget);
      expect(
        tester.getRect(find.text('浮动标签')).height,
        moreOrLessEquals(floating.height, epsilon: 0.5),
      );
    });

    testWidgets('a disabled field cannot be focused', (
      WidgetTester tester,
    ) async {
      final FocusNode node = FocusNode();
      addTearDown(node.dispose);
      await tester.pumpWidget(
        _harness(SoftTextField(focusNode: node, label: '已禁用', enabled: false)),
      );
      await tester.tap(find.byType(SoftTextField), warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 400));
      expect(node.hasFocus, isFalse);
      final Text label = tester.widget<Text>(find.text('已禁用'));
      expect(label.style!.color, const SoftColors.light().disabledOnSurface);
    });

    testWidgets('the line form grows its focus line and settles', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_harness(const SoftTextField(label: '设备名称')));
      await tester.tap(find.byType(SoftTextField));
      await tester.pump();
      expect(tester.binding.transientCallbackCount, greaterThan(0));
      await _settle(tester);
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pump();
      await _settle(tester);
    });
  });

  group('SoftInputView', () {
    for (final bool dark in <bool>[false, true]) {
      testWidgets('lays out the title card (${dark ? 'dark' : 'light'})', (
        WidgetTester tester,
      ) async {
        await tester.pumpWidget(
          _harness(
            const SoftInputView(title: '昵称', label: '输入昵称'),
            dark: dark,
          ),
        );
        final double title = 16 * 1.158 < 22 ? 22 : 16 * 1.158;
        expect(
          tester.getSize(find.byType(SoftInputView)).height,
          moreOrLessEquals(12 + title + 4 + _bodyLine + 12, epsilon: 0.5),
        );
        final DecoratedBox card = tester.widget<DecoratedBox>(
          find
              .descendant(
                of: find.byType(SoftInputView),
                matching: find.byType(DecoratedBox),
              )
              .first,
        );
        expect(
          (card.decoration as ShapeDecoration).color,
          dark
              ? const SoftColors.dark().surfaceContainer
              : const SoftColors.light().surfaceContainer,
        );
      });
    }

    testWidgets('the error caption fades in and out', (
      WidgetTester tester,
    ) async {
      Widget view(String error) =>
          _harness(SoftInputView(title: '昵称', errorMessage: error));
      await tester.pumpWidget(view(''));
      final double rest = tester.getSize(find.byType(SoftInputView)).height;
      await tester.pumpWidget(view('昵称不能包含空格'));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('昵称不能包含空格'), findsOneWidget);
      await _settle(tester);
      expect(
        tester.getSize(find.byType(SoftInputView)).height,
        greaterThan(rest),
      );
      await tester.pumpWidget(view(''));
      await tester.pump(const Duration(milliseconds: 100));
      // Still fading out with the old message.
      expect(find.text('昵称不能包含空格'), findsOneWidget);
      await _settle(tester);
      expect(find.text('昵称不能包含空格'), findsNothing);
      expect(tester.getSize(find.byType(SoftInputView)).height, rest);
    });

    testWidgets('the multi-line card counts at its corner', (
      WidgetTester tester,
    ) async {
      final TextEditingController controller = TextEditingController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        _harness(
          SoftInputView(
            controller: controller,
            label: '签名（多行）',
            showCount: true,
            maxCount: 5,
            singleLine: false,
          ),
        ),
      );
      expect(find.text('0/5'), findsOneWidget);
      await tester.enterText(find.byType(EditableText), 'abcdefg');
      await tester.pump();
      expect(controller.text, 'abcde');
      expect(find.text('5/5'), findsOneWidget);
      await _settle(tester);
      final Text count = tester.widget<Text>(find.text('5/5'));
      expect(count.style!.color, const SoftColors.light().error);
      expect(count.style!.fontSize, 12);
    });
  });

  group('SoftSearchBar', () {
    Widget bar({
      required ValueNotifier<bool> expanded,
      required TextEditingController controller,
      bool dark = false,
    }) {
      void onExpanded(bool v) => expanded.value = v;
      return _harness(
        ValueListenableBuilder<bool>(
          valueListenable: expanded,
          builder: (BuildContext context, bool value, Widget? _) =>
              SoftSearchBar(
                expanded: value,
                onExpandedChange: onExpanded,
                inputField: SoftSearchField(
                  controller: controller,
                  label: '搜索',
                  expanded: value,
                  onExpandedChange: onExpanded,
                  clearButtonSemanticLabel: '清除',
                ),
                outsideEndAction: SoftSearchBarCancelAction(
                  label: '取消',
                  onTap: () => onExpanded(false),
                ),
                content: const SizedBox(height: 120, child: Text('历史')),
              ),
        ),
        dark: dark,
      );
    }

    for (final bool dark in <bool>[false, true]) {
      testWidgets('lays out collapsed (${dark ? 'dark' : 'light'})', (
        WidgetTester tester,
      ) async {
        final TextEditingController controller = TextEditingController();
        addTearDown(controller.dispose);
        await tester.pumpWidget(
          bar(
            expanded: ValueNotifier<bool>(false),
            controller: controller,
            dark: dark,
          ),
        );
        expect(tester.getSize(find.byType(SoftSearchBar)), const Size(360, 52));
        expect(
          tester.getSize(find.byType(SoftSearchField)),
          const Size(328, 40),
        );
        expect(find.text('搜索'), findsOneWidget);
        expect(find.text('取消'), findsNothing);
        expect(find.text('历史'), findsNothing);
        final DecoratedBox capsule = tester.widget<DecoratedBox>(
          find
              .descendant(
                of: find.byType(SoftSearchField),
                matching: find.byType(DecoratedBox),
              )
              .first,
        );
        expect(
          (capsule.decoration as ShapeDecoration).color,
          dark
              ? SoftSearchBarDefaults.noBlurSolidDark
              : SoftSearchBarDefaults.noBlurSolidLight,
        );
      });
    }

    testWidgets('expands on focus and collapses through cancel', (
      WidgetTester tester,
    ) async {
      final TextEditingController controller = TextEditingController();
      addTearDown(controller.dispose);
      final ValueNotifier<bool> expanded = ValueNotifier<bool>(false);
      addTearDown(expanded.dispose);
      await tester.pumpWidget(bar(expanded: expanded, controller: controller));
      await tester.tap(find.byType(SoftSearchField));
      await tester.pump();
      expect(expanded.value, isTrue);
      expect(find.text('取消'), findsOneWidget);
      expect(find.text('搜索'), findsNothing);
      await tester.pump(const Duration(milliseconds: 40));
      final double midWidth = tester
          .getSize(find.byType(SoftSearchField))
          .width;
      expect(midWidth, lessThan(328));
      await _settle(tester);
      final double openWidth = tester
          .getSize(find.byType(SoftSearchField))
          .width;
      expect(openWidth, lessThan(midWidth));
      expect(find.text('历史'), findsOneWidget);
      expect(tester.getSize(find.byType(SoftSearchBar)).height, 52 + 120);

      await tester.enterText(find.byType(EditableText), 'abc');
      await _settle(tester);
      expect(find.bySemanticsLabel('清除'), findsOneWidget);

      await tester.tap(find.text('取消'));
      await tester.pump();
      expect(expanded.value, isFalse);
      // 100 ms later the query fades out and clears.
      await tester.pump(const Duration(milliseconds: 150));
      await _settle(tester);
      expect(controller.text, isEmpty);
      expect(FocusManager.instance.primaryFocus is FocusScopeNode, isTrue);
      expect(find.text('取消'), findsNothing);
      expect(find.text('历史'), findsNothing);
      expect(find.text('搜索'), findsOneWidget);
      expect(tester.getSize(find.byType(SoftSearchField)).width, 328);
    });

    testWidgets('the clear button clears the query', (
      WidgetTester tester,
    ) async {
      final TextEditingController controller = TextEditingController(
        text: 'abc',
      );
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        bar(expanded: ValueNotifier<bool>(false), controller: controller),
      );
      expect(find.byType(SoftInputIconButton), findsOneWidget);
      await tester.tap(find.byType(SoftInputIconButton));
      await tester.pump();
      expect(controller.text, isEmpty);
      await _settle(tester);
      expect(find.byType(SoftInputIconButton), findsNothing);
    });

    testWidgets('back collapses an expanded bar', (WidgetTester tester) async {
      final TextEditingController controller = TextEditingController();
      addTearDown(controller.dispose);
      final ValueNotifier<bool> expanded = ValueNotifier<bool>(true);
      addTearDown(expanded.dispose);
      await tester.pumpWidget(bar(expanded: expanded, controller: controller));
      await _settle(tester);
      await tester.binding.handlePopRoute();
      await tester.pump();
      expect(expanded.value, isFalse);
      await _settle(tester);
      expect(find.text('取消'), findsNothing);
    });
  });
}
