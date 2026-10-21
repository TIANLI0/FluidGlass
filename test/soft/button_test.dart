import 'package:fluid_glass/fluid_glass.dart';
import 'package:fluid_glass/src/soft/components/button/soft_button_press.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'surface.dart';

Widget _host(Widget child, {bool dark = false}) {
  final SoftThemeData theme = dark
      ? const SoftThemeData.dark()
      : const SoftThemeData.light();
  return MediaQuery(
    data: const MediaQueryData(size: Size(400, 800)),
    child: Directionality(
      textDirection: TextDirection.ltr,
      child: SoftTheme(
        data: theme,
        child: DefaultTextStyle(
          style: theme.textStyles.body1.copyWith(
            color: theme.colors.onBackground,
          ),
          child: ColoredBox(
            color: theme.colors.surface,
            child: Center(child: child),
          ),
        ),
      ),
    ),
  );
}

Color? _textColor(WidgetTester tester, String text) {
  final RichText rich = tester.widget<RichText>(
    find.descendant(of: find.text(text), matching: find.byType(RichText)).first,
  );
  return rich.text.style?.color;
}

void main() {
  usePhoneSurface();

  for (final bool dark in <bool>[false, true]) {
    final String mode = dark ? 'dark' : 'light';
    final SoftColors colors = dark
        ? const SoftColors.dark()
        : const SoftColors.light();

    group('SoftButton ($mode)', () {
      testWidgets('size tiers keep their minimum metrics', (
        WidgetTester tester,
      ) async {
        for (final SoftButtonSize size in SoftButtonSize.values) {
          await tester.pumpWidget(
            _host(
              SoftTextButton(text: 'A', size: size, onPressed: () {}),
              dark: dark,
            ),
          );
          final Size box = tester.getSize(find.byType(SoftTextButton));
          expect(box.width, size.minWidth, reason: '$size width');
          expect(box.height, greaterThanOrEqualTo(size.minHeight));
        }
        await tester.pumpWidget(
          _host(
            SoftTextButton(text: 'A', onPressed: () {}),
            dark: dark,
          ),
        );
        expect(tester.getSize(find.byType(SoftTextButton)), const Size(58, 44));
      });

      testWidgets('variants colour the label from the theme', (
        WidgetTester tester,
      ) async {
        await tester.pumpWidget(
          _host(
            Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                SoftTextButton(text: 'n', onPressed: () {}),
                SoftTextButton(
                  text: 'p',
                  variant: SoftButtonVariant.primary,
                  onPressed: () {},
                ),
                SoftTextButton(
                  text: 'b',
                  variant: SoftButtonVariant.borderless,
                  onPressed: () {},
                ),
                SoftTextButton(text: 'd', enabled: false, onPressed: () {}),
                const SoftTextButton(
                  text: 'dp',
                  variant: SoftButtonVariant.primary,
                  onPressed: null,
                ),
              ],
            ),
            dark: dark,
          ),
        );
        expect(_textColor(tester, 'n'), colors.onSecondaryVariant);
        expect(_textColor(tester, 'p'), colors.onPrimary);
        expect(_textColor(tester, 'b'), colors.primary);
        expect(_textColor(tester, 'd'), colors.disabledOnSecondaryVariant);
        expect(_textColor(tester, 'dp'), colors.disabledOnPrimaryButton);
        expect(
          SoftButtonColors.of(SoftButtonVariant.primary, colors).color,
          colors.primary,
        );
        expect(
          SoftButtonColors.of(SoftButtonVariant.normal, colors).disabledColor,
          colors.disabledSecondaryVariant,
        );
      });

      testWidgets('fills an expanded slot and centres the label', (
        WidgetTester tester,
      ) async {
        await tester.pumpWidget(
          _host(
            SizedBox(
              width: 300,
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: SoftTextButton(text: 'go', onPressed: () {}),
                  ),
                ],
              ),
            ),
            dark: dark,
          ),
        );
        final Rect button = tester.getRect(find.byType(SoftTextButton));
        final Rect label = tester.getRect(find.text('go'));
        expect(button.width, 300);
        expect(label.center.dx, moreOrLessEquals(button.center.dx));
        expect(label.center.dy, moreOrLessEquals(button.center.dy));
      });
    });
  }

  group('SoftButton interaction', () {
    testWidgets('taps call onPressed; disabled ones do not', (
      WidgetTester tester,
    ) async {
      int taps = 0;
      await tester.pumpWidget(
        _host(
          Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              SoftTextButton(text: 'on', onPressed: () => taps++),
              SoftTextButton(
                text: 'off',
                enabled: false,
                onPressed: () => taps += 100,
              ),
            ],
          ),
        ),
      );
      await tester.tap(find.text('on'));
      await tester.tap(find.text('off'));
      await tester.pumpAndSettle();
      expect(taps, 1);
    });

    testWidgets('press sinks to the area scale and settles back', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _host(SoftTextButton(text: 'press', onPressed: () {})),
      );
      final Finder inner = find.byType(SoftPressable);
      final Rect rest = tester.getRect(inner);
      final TestGesture gesture = await tester.startGesture(rest.center);
      // Stay under the long-press deadline.
      await tester.pump(const Duration(milliseconds: 160));
      await tester.pump(const Duration(milliseconds: 300));
      final Rect pressed = tester.getRect(inner);
      final double expected = SoftButtonPressDefaults.endScale(rest.size);
      expect(
        pressed.width / rest.width,
        moreOrLessEquals(expected, epsilon: 3e-3),
      );
      expect(pressed.center, rest.center);
      await gesture.up();
      await tester.pumpAndSettle();
      expect(tester.getRect(inner), rest);
      expect(tester.binding.hasScheduledFrame, isFalse);
    });

    testWidgets('pressScaleEnabled false keeps the size', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _host(
          SoftTextButton(
            text: 'flat',
            pressScaleEnabled: false,
            onPressed: () {},
          ),
        ),
      );
      final Rect rest = tester.getRect(find.byType(SoftPressable));
      final TestGesture gesture = await tester.startGesture(rest.center);
      await tester.pump(const Duration(milliseconds: 500));
      expect(tester.getRect(find.byType(SoftPressable)), rest);
      await gesture.up();
      await tester.pumpAndSettle();
    });

    test('end scale follows the area', () {
      expect(SoftButtonPressDefaults.endScale(const Size(40, 40)), 0.92);
      expect(SoftButtonPressDefaults.endScale(const Size(400, 300)), 0.98);
      final double mid = SoftButtonPressDefaults.endScale(const Size(160, 44));
      expect(mid, greaterThan(0.92));
      expect(mid, lessThan(0.98));
    });

    testWidgets('announces a button, enabled or not', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _host(
          Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              SoftTextButton(text: 'yes', onPressed: () {}),
              const SoftTextButton(text: 'no', onPressed: null),
            ],
          ),
        ),
      );
      expect(
        tester.getSemantics(find.text('yes')),
        isSemantics(
          label: 'yes',
          isButton: true,
          hasEnabledState: true,
          isEnabled: true,
          hasTapAction: true,
        ),
      );
      final SemanticsNode off = tester.getSemantics(find.text('no'));
      expect(
        off,
        isSemantics(isButton: true, hasEnabledState: true, isEnabled: false),
      );
      handle.dispose();
    });
  });

  group('SoftLoadingButton', () {
    test('dot alpha follows the staggered keyframes', () {
      double a(int i, int ms) =>
          SoftLoadingButtonDefaults.dotAlpha(i, Duration(milliseconds: ms));
      expect(a(0, 0), 0.2);
      expect(a(0, 133), moreOrLessEquals(0.5));
      expect(a(0, 300), 1);
      expect(a(0, 534), moreOrLessEquals(0.5));
      expect(a(0, 1000), 0.2);
      expect(a(1, 200), 0.2);
      expect(a(1, 333 + 300), 1);
      expect(a(0, 1332 + 300), 1);
    });

    for (final bool dark in <bool>[false, true]) {
      testWidgets('keeps its size and swallows taps while loading '
          '(${dark ? 'dark' : 'light'})', (WidgetTester tester) async {
        int taps = 0;
        Widget build(bool loading) => _host(
          SoftLoadingButton(
            text: 'Download',
            loading: loading,
            variant: SoftButtonVariant.primary,
            onPressed: () => taps++,
          ),
          dark: dark,
        );
        await tester.pumpWidget(build(false));
        final Size idle = tester.getSize(find.byType(SoftLoadingButton));
        await tester.tap(find.byType(SoftLoadingButton));
        await tester.pumpAndSettle();
        expect(taps, 1);

        await tester.pumpWidget(build(true));
        await tester.pump(const Duration(milliseconds: 500));
        expect(tester.getSize(find.byType(SoftLoadingButton)), idle);
        expect(tester.binding.hasScheduledFrame, isTrue);
        await tester.tap(find.byType(SoftLoadingButton));
        await tester.pump(const Duration(milliseconds: 500));
        expect(taps, 1);

        await tester.pumpWidget(build(false));
        await tester.pumpAndSettle();
        expect(tester.binding.hasScheduledFrame, isFalse);
      });
    }

    testWidgets('shows the loading text with three pulsing stops', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _host(
          SoftLoadingButton(
            text: 'Sign in',
            loadingText: 'Signing in',
            loading: true,
            onPressed: () {},
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Signing in'), findsOneWidget);
      expect(find.text('.'), findsNWidgets(3));
      final List<FadeTransition> fades = tester
          .widgetList<FadeTransition>(
            find.ancestor(
              of: find.text('.'),
              matching: find.byType(FadeTransition),
            ),
          )
          .toList();
      expect(fades.first.opacity.value, greaterThan(0.2));
      expect(fades.last.opacity.value, 0.2);
      await tester.pumpWidget(_host(const SizedBox()));
    });
  });

  group('SoftIconButton', () {
    for (final bool dark in <bool>[false, true]) {
      testWidgets('is 48 square and taps (${dark ? 'dark' : 'light'})', (
        WidgetTester tester,
      ) async {
        int taps = 0;
        await tester.pumpWidget(
          _host(
            SoftIconButton(
              backgroundColor: const Color(0x14000000),
              semanticLabel: 'Search',
              onPressed: () => taps++,
              child: const SizedBox.square(dimension: 24),
            ),
            dark: dark,
          ),
        );
        expect(tester.getSize(find.byType(SoftIconButton)), const Size(48, 48));
        await tester.tap(find.byType(SoftIconButton));
        await tester.pumpAndSettle();
        expect(taps, 1);
      });
    }

    testWidgets('disabled does not tap; holdDown settles', (
      WidgetTester tester,
    ) async {
      int taps = 0;
      Widget build(bool hold) => _host(
        SoftIconButton(
          enabled: false,
          holdDown: hold,
          onPressed: () => taps++,
          child: const SizedBox.square(dimension: 24),
        ),
      );
      await tester.pumpWidget(build(false));
      await tester.tap(find.byType(SoftIconButton));
      await tester.pumpWidget(build(true));
      await tester.pumpAndSettle();
      expect(taps, 0);
      expect(tester.binding.hasScheduledFrame, isFalse);
    });
  });

  group('SoftFloatingActionButton', () {
    for (final bool dark in <bool>[false, true]) {
      testWidgets('is a raised 56 circle that sinks to 0.92 '
          '(${dark ? 'dark' : 'light'})', (WidgetTester tester) async {
        int taps = 0;
        await tester.pumpWidget(
          _host(
            SoftFloatingActionButton(
              onPressed: () => taps++,
              child: const SizedBox.square(dimension: 24),
            ),
            dark: dark,
          ),
        );
        final Finder fab = find.byType(PhysicalShape);
        expect(tester.getSize(fab), const Size(56, 56));
        final PhysicalShape shape = tester.widget<PhysicalShape>(fab);
        expect(shape.elevation, 12);
        expect(
          shape.color,
          dark
              ? const SoftColors.dark().primary
              : const SoftColors.light().primary,
        );
        final TestGesture gesture = await tester.startGesture(
          tester.getCenter(fab),
        );
        await tester.pump(const Duration(milliseconds: 160));
        await tester.pump(const Duration(milliseconds: 300));
        expect(
          tester.getRect(fab).width,
          moreOrLessEquals(56 * 0.92, epsilon: 0.2),
        );
        await gesture.up();
        await tester.pumpAndSettle();
        expect(tester.getSize(fab), const Size(56, 56));
        expect(taps, 1);
      });
    }
  });

  group('SoftChip', () {
    for (final bool dark in <bool>[false, true]) {
      final SoftColors colors = dark
          ? const SoftColors.dark()
          : const SoftColors.light();
      testWidgets('toggles and cross-fades its colours '
          '(${dark ? 'dark' : 'light'})', (WidgetTester tester) async {
        bool selected = false;
        await tester.pumpWidget(
          _host(
            StatefulBuilder(
              builder: (BuildContext context, StateSetter setState) => SoftChip(
                selected: selected,
                label: 'Nearby',
                onPressed: () => setState(() => selected = !selected),
              ),
            ),
            dark: dark,
          ),
        );
        final Size size = tester.getSize(find.byType(SoftChip));
        expect(size.height, 32);
        expect(size.width, greaterThanOrEqualTo(52));
        expect(_textColor(tester, 'Nearby'), colors.onSurface);

        await tester.tap(find.byType(SoftChip));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 40));
        final Color? mid = _textColor(tester, 'Nearby');
        expect(mid, isNot(colors.onSurface));
        expect(mid, isNot(colors.onPrimary));
        await tester.pumpAndSettle();
        expect(selected, isTrue);
        expect(_textColor(tester, 'Nearby'), colors.onPrimary);
        expect(tester.binding.hasScheduledFrame, isFalse);
      });
    }

    testWidgets('disabled chips use the disabled colours and do not toggle', (
      WidgetTester tester,
    ) async {
      int taps = 0;
      await tester.pumpWidget(
        _host(
          Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              SoftChip(
                selected: false,
                enabled: false,
                label: 'off',
                onPressed: () => taps++,
              ),
              SoftChip(
                selected: true,
                enabled: false,
                label: 'off on',
                onPressed: () => taps++,
              ),
            ],
          ),
        ),
      );
      const SoftColors c = SoftColors.light();
      expect(_textColor(tester, 'off'), c.disabledOnSecondaryVariant);
      expect(_textColor(tester, 'off on'), c.disabledOnPrimaryButton);
      await tester.tap(find.text('off'));
      await tester.pumpAndSettle();
      expect(taps, 0);
    });

    testWidgets('dismiss is its own button and keeps the chip width', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      int taps = 0;
      int dismissed = 0;
      Widget build({required bool dismissible}) => _host(
        SoftChip(
          selected: false,
          label: 'Tag',
          dismissSemanticLabel: 'Remove',
          onPressed: () => taps++,
          onDismiss: dismissible ? () => dismissed++ : null,
        ),
      );
      await tester.pumpWidget(build(dismissible: false));
      final double plain = tester.getSize(find.byType(SoftChip)).width;
      await tester.pumpWidget(build(dismissible: true));
      final double withDismiss = tester.getSize(find.byType(SoftChip)).width;
      // 12 end padding becomes 8 + 14 + 9.
      expect(withDismiss - plain, moreOrLessEquals(31 - 12));
      expect(tester.getSize(find.byType(SoftChip)).height, 32);

      await tester.tap(find.bySemanticsLabel('Remove'));
      await tester.pumpAndSettle();
      expect(dismissed, 1);
      expect(taps, 0);
      await tester.tap(find.text('Tag'));
      await tester.pumpAndSettle();
      expect(taps, 1);
      handle.dispose();
    });

    testWidgets('announces a checkable item', (WidgetTester tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _host(SoftChip(selected: true, label: 'All', onPressed: () {})),
      );
      final SemanticsNode node = tester.getSemantics(find.text('All'));
      expect(node, isSemantics(hasCheckedState: true, isChecked: true));
      handle.dispose();
    });

    testWidgets('long labels ellipsize within the width caps', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _host(
          SoftChip(
            selected: false,
            label: 'A very long chip label ' * 10,
            icon: const SizedBox.square(dimension: 16),
            onPressed: () {},
          ),
        ),
      );
      final Size size = tester.getSize(find.byType(SoftChip));
      expect(size.width, lessThanOrEqualTo(SoftChipDefaults.maxWidth));
      expect(size.width, 12 + 16 + 4 + 200 + 12);
      expect(size.height, 32);
      expect(tester.takeException(), isNull);
    });
  });
}
