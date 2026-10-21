import 'package:fluid_glass/fluid_glass.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'surface.dart';

Widget _host(Widget child, {bool reduce = false, bool rtl = false}) =>
    MediaQuery(
      data: MediaQueryData(disableAnimations: reduce),
      child: Directionality(
        textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
        child: SoftTheme(
          data: const SoftThemeData.light(),
          child: Center(child: child),
        ),
      ),
    );

CustomPainter _painter(WidgetTester tester) => tester
    .widget<CustomPaint>(
      find.descendant(
        of: find.byType(SoftSwitch),
        matching: find.byType(CustomPaint),
      ),
    )
    .painter!;

void main() {
  usePhoneSurface();

  for (final bool rtl in <bool>[false, true]) {
    testWidgets('thumb endpoints and touch target (rtl: $rtl)', (tester) async {
      for (final bool checked in <bool>[false, true]) {
        await tester.pumpWidget(
          _host(
            SoftSwitch(checked: checked, onChanged: (_) {}, haptics: false),
            rtl: rtl,
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.getSize(find.byType(SoftSwitch)), const Size(48, 48));
        expect(
          tester.getSize(
            find.descendant(
              of: find.byType(SoftSwitch),
              matching: find.byType(CustomPaint),
            ),
          ),
          const Size(38, 24),
        );
        final double left = checked != rtl ? 17 : 3;
        expect(
          (Canvas canvas) => _painter(tester).paint(canvas, const Size(38, 24)),
          paints
            ..rrect()
            ..rrect()
            ..rrect()
            ..rrect(
              rrect: RRect.fromRectAndRadius(
                Rect.fromLTWH(left, 3, 18, 18),
                const Radius.circular(9),
              ),
              color: const Color(0xFFFFFFFF),
            ),
        );
        expect(tester.binding.hasScheduledFrame, isFalse);
      }
    });
  }

  testWidgets('tap asks owner to toggle and the switch remains controlled', (
    tester,
  ) async {
    final List<bool> values = <bool>[];
    await tester.pumpWidget(
      _host(SoftSwitch(checked: false, onChanged: values.add, haptics: false)),
    );
    await tester.tap(find.byType(SoftSwitch));
    await tester.pumpAndSettle();
    expect(values, <bool>[true]);
    expect(tester.widget<SoftSwitch>(find.byType(SoftSwitch)).checked, isFalse);
    await tester.pumpWidget(
      _host(SoftSwitch(checked: true, onChanged: values.add, haptics: false)),
    );
    await tester.pump();
    expect(tester.binding.hasScheduledFrame, isTrue);
    await tester.pumpAndSettle();
    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  testWidgets('loading rotates, blocks input and stops after it is cleared', (
    tester,
  ) async {
    int taps = 0;
    Widget surface(bool loading) => SoftSwitch(
      checked: true,
      isLoading: loading,
      onChanged: (_) => taps++,
      haptics: false,
    );
    await tester.pumpWidget(_host(surface(true)));
    await tester.tap(find.byType(SoftSwitch));
    await tester.pump(const Duration(seconds: 1));
    expect(taps, 0);
    expect(tester.binding.hasScheduledFrame, isTrue);
    await tester.pumpWidget(_host(surface(false)));
    await tester.pumpAndSettle();
    expect(tester.binding.hasScheduledFrame, isFalse);
    await tester.tap(find.byType(SoftSwitch));
    expect(taps, 1);
  });

  testWidgets('reduced motion settles toggles and freezes the loading arc', (
    tester,
  ) async {
    Widget surface(bool checked, bool loading) => SoftSwitch(
      checked: checked,
      isLoading: loading,
      onChanged: (_) {},
      haptics: false,
    );
    await tester.pumpWidget(_host(surface(false, false), reduce: true));
    await tester.pumpWidget(_host(surface(true, true), reduce: true));
    await tester.pump();
    expect(tester.binding.hasScheduledFrame, isFalse);
    await tester.pumpWidget(_host(surface(true, true)));
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.binding.hasScheduledFrame, isTrue);
    await tester.pumpWidget(_host(surface(true, true), reduce: true));
    await tester.pump();
    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  testWidgets('disabled switch never toggles', (tester) async {
    int taps = 0;
    await tester.pumpWidget(
      _host(
        SoftSwitch(checked: false, enabled: false, onChanged: (_) => taps++),
      ),
    );
    await tester.tap(find.byType(SoftSwitch));
    await tester.pumpAndSettle();
    expect(taps, 0);
  });

  testWidgets('keyboard and semantics activate once', (tester) async {
    final SemanticsHandle semantics = tester.ensureSemantics();
    int taps = 0;
    await tester.pumpWidget(
      _host(
        SoftSwitch(
          checked: true,
          semanticLabel: 'Wi-Fi',
          onChanged: (_) => taps++,
          haptics: false,
        ),
      ),
    );
    expect(
      tester.getSemantics(find.byType(SoftSwitch)),
      matchesSemantics(
        label: 'Wi-Fi',
        hasEnabledState: true,
        isEnabled: true,
        hasToggledState: true,
        isToggled: true,
        hasTapAction: true,
        hasFocusAction: true,
        isFocusable: true,
      ),
    );
    Focus.of(tester.element(find.byType(GestureDetector))).requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    expect(taps, 1);
    final SemanticsNode node = tester.getSemantics(find.byType(SoftSwitch));
    node.owner!.performAction(node.id, SemanticsAction.tap);
    expect(taps, 2);
    await tester.pumpAndSettle();
    semantics.dispose();
  });

  testWidgets('rapid toggles and disposal leave no active animation', (
    tester,
  ) async {
    for (final bool checked in <bool>[false, true, false, true]) {
      await tester.pumpWidget(
        _host(SoftSwitch(checked: checked, onChanged: (_) {})),
      );
      await tester.pump(const Duration(milliseconds: 60));
    }
    await tester.pumpWidget(_host(const SizedBox.shrink()));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(tester.binding.hasScheduledFrame, isFalse);
  });
}
