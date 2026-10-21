import 'dart:ui' show CheckedState;

import 'package:fluid_glass/fluid_glass.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
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
        child: ColoredBox(
          color: theme.colors.surface,
          child: Center(child: child),
        ),
      ),
    ),
  );
}

/// Every haptic the platform channel was asked for.
List<String> _recordHaptics(WidgetTester tester) {
  final List<String> calls = <String>[];
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    SystemChannels.platform,
    (MethodCall call) async {
      if (call.method == 'HapticFeedback.vibrate') {
        calls.add(call.arguments as String);
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
  return calls;
}

/// Pumps a fixed time and checks nothing is still animating.
Future<void> _expectSettles(WidgetTester tester) async {
  // One frame to start whatever the last event kicked off, then long past
  // the longest spring.
  await tester.pump();
  await tester.pump(const Duration(seconds: 2));
  expect(tester.binding.hasScheduledFrame, isFalse);
}

/// The control's own semantics node, under its touch-target wrapper.
Finder _semanticsOf(Type control) => find
    .descendant(of: find.byType(control), matching: find.byType(Semantics))
    .first;

const double _sliderWidth = 300;

/// The x of [fraction] on a 300 × 20 slider whose left edge is at [left].
double _xAt(double left, double fraction) {
  const double cap = 14; // 20 × 1.4 / 2
  return left + cap + fraction * (_sliderWidth - 2 * cap);
}

void main() {
  usePhoneSurface();

  group('SoftCheckbox', () {
    for (final bool dark in <bool>[false, true]) {
      testWidgets('lays out 24 square in ${dark ? 'dark' : 'light'}', (
        WidgetTester tester,
      ) async {
        await tester.pumpWidget(
          _host(
            const Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                SoftCheckbox(state: SoftCheckboxState.off, onTap: null),
                SoftCheckbox(state: SoftCheckboxState.on, onTap: null),
                SoftCheckbox(
                  state: SoftCheckboxState.indeterminate,
                  onTap: null,
                ),
                SoftCheckbox(
                  state: SoftCheckboxState.on,
                  onTap: null,
                  enabled: false,
                ),
              ],
            ),
            dark: dark,
          ),
        );
        for (final Element e in find.byType(SoftCheckbox).evaluate()) {
          expect(tester.getSize(find.byWidget(e.widget)), const Size(24, 24));
        }
        expect(tester.takeException(), isNull);
        await _expectSettles(tester);
      });
    }

    testWidgets('a tap toggles, plays a haptic and the animation settles', (
      WidgetTester tester,
    ) async {
      final List<String> haptics = _recordHaptics(tester);
      bool checked = false;
      await tester.pumpWidget(
        _host(
          StatefulBuilder(
            builder: (BuildContext context, StateSetter setState) =>
                SoftCheckbox.value(
                  checked: checked,
                  onTap: () => setState(() => checked = !checked),
                ),
          ),
        ),
      );
      await tester.tap(find.byType(SoftCheckbox));
      await tester.pump();
      expect(checked, isTrue);
      expect(haptics, isNotEmpty);
      // Mid-transition something is still moving.
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.binding.hasScheduledFrame, isTrue);
      await _expectSettles(tester);
    });

    testWidgets('the touch area reaches 48 around the 24 square', (
      WidgetTester tester,
    ) async {
      int taps = 0;
      await tester.pumpWidget(
        _host(
          SizedBox(
            width: 100,
            height: 100,
            child: Center(
              child: SoftCheckbox(
                state: SoftCheckboxState.off,
                onTap: () => taps++,
              ),
            ),
          ),
        ),
      );
      final Offset centre = tester.getCenter(find.byType(SoftCheckbox));
      await tester.tapAt(centre + const Offset(22, 0));
      await tester.pump();
      expect(taps, 1);
      await tester.tapAt(centre + const Offset(30, 0));
      await tester.pump();
      expect(taps, 1);
      await _expectSettles(tester);
    });

    testWidgets('a disabled checkbox ignores taps', (
      WidgetTester tester,
    ) async {
      int taps = 0;
      await tester.pumpWidget(
        _host(
          SoftCheckbox(
            state: SoftCheckboxState.off,
            onTap: () => taps++,
            enabled: false,
          ),
        ),
      );
      await tester.tap(find.byType(SoftCheckbox), warnIfMissed: false);
      await tester.pump();
      expect(taps, 0);
      await _expectSettles(tester);
    });

    testWidgets('cycles through the indeterminate state', (
      WidgetTester tester,
    ) async {
      SoftCheckboxState state = SoftCheckboxState.off;
      await tester.pumpWidget(
        _host(
          StatefulBuilder(
            builder: (BuildContext context, StateSetter setState) =>
                SoftCheckbox(
                  state: state,
                  onTap: () => setState(() {
                    state = switch (state) {
                      SoftCheckboxState.off => SoftCheckboxState.indeterminate,
                      SoftCheckboxState.indeterminate => SoftCheckboxState.on,
                      SoftCheckboxState.on => SoftCheckboxState.off,
                    };
                  }),
                ),
          ),
        ),
      );
      for (final SoftCheckboxState expected in <SoftCheckboxState>[
        SoftCheckboxState.indeterminate,
        SoftCheckboxState.on,
        SoftCheckboxState.off,
      ]) {
        await tester.tap(find.byType(SoftCheckbox));
        // Retargets mid-flight as well as from rest.
        await tester.pump(const Duration(milliseconds: 120));
        expect(state, expected);
      }
      expect(tester.takeException(), isNull);
      await _expectSettles(tester);
    });

    testWidgets('reports checked and mixed to accessibility', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _host(
          SoftCheckbox(state: SoftCheckboxState.indeterminate, onTap: () {}),
        ),
      );
      final SemanticsNode node = tester.getSemantics(
        _semanticsOf(SoftCheckbox),
      );
      expect(node.flagsCollection.isChecked, CheckedState.mixed);
      expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
      handle.dispose();
    });
  });

  group('SoftRadioButton', () {
    for (final bool dark in <bool>[false, true]) {
      testWidgets('lays out 24 square in ${dark ? 'dark' : 'light'}', (
        WidgetTester tester,
      ) async {
        await tester.pumpWidget(
          _host(
            const Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                SoftRadioButton(selected: false, onTap: null),
                SoftRadioButton(selected: true, onTap: null),
                SoftRadioButton(selected: true, onTap: null, enabled: false),
              ],
            ),
            dark: dark,
          ),
        );
        expect(
          tester.getSize(find.byType(SoftRadioButton).first),
          const Size(24, 24),
        );
        expect(tester.takeException(), isNull);
        await _expectSettles(tester);
      });
    }

    testWidgets('a tap selects, and the animation settles', (
      WidgetTester tester,
    ) async {
      final List<String> haptics = _recordHaptics(tester);
      int selected = 0;
      await tester.pumpWidget(
        _host(
          StatefulBuilder(
            builder: (BuildContext context, StateSetter setState) => Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                for (int i = 0; i < 3; i++)
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: SoftRadioButton(
                      key: ValueKey<int>(i),
                      selected: selected == i,
                      onTap: () => setState(() => selected = i),
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
      await tester.tap(find.byKey(const ValueKey<int>(2)));
      await tester.pump();
      expect(selected, 2);
      expect(haptics, isNotEmpty);
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.binding.hasScheduledFrame, isTrue);
      await _expectSettles(tester);
    });

    testWidgets('is a checked member of an exclusive group', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _host(SoftRadioButton(selected: true, onTap: () {})),
      );
      final SemanticsNode node = tester.getSemantics(
        _semanticsOf(SoftRadioButton),
      );
      expect(node.flagsCollection.isChecked, CheckedState.isTrue);
      expect(node.flagsCollection.isInMutuallyExclusiveGroup, isTrue);
      handle.dispose();
    });
  });

  group('SoftSlider', () {
    Widget slider({
      required double value,
      required ValueChanged<double> onChanged,
      VoidCallback? onChangeEnd,
      int steps = 0,
      double max = 1,
      bool enabled = true,
      List<double>? keyPoints,
      bool dark = false,
    }) {
      return _host(
        SizedBox(
          width: _sliderWidth,
          child: SoftSlider(
            value: value,
            onChanged: onChanged,
            onChangeEnd: onChangeEnd,
            steps: steps,
            max: max,
            enabled: enabled,
            keyPoints: keyPoints,
            showKeyPoints: keyPoints != null || steps > 0,
            secondaryProgress: 0.75,
          ),
        ),
        dark: dark,
      );
    }

    for (final bool dark in <bool>[false, true]) {
      testWidgets('lays out 20 tall in ${dark ? 'dark' : 'light'}', (
        WidgetTester tester,
      ) async {
        await tester.pumpWidget(
          slider(value: 0.3, onChanged: (_) {}, steps: 4, dark: dark),
        );
        expect(
          tester.getSize(find.byType(SoftSlider)),
          const Size(_sliderWidth, 20),
        );
        expect(tester.takeException(), isNull);
        await _expectSettles(tester);
      });
    }

    testWidgets('a drag moves the value to the finger, a tap does not', (
      WidgetTester tester,
    ) async {
      double value = 0.2;
      int ends = 0;
      await tester.pumpWidget(
        StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) => slider(
            value: value,
            onChanged: (double v) => setState(() => value = v),
            onChangeEnd: () => ends++,
          ),
        ),
      );
      final double left = tester.getTopLeft(find.byType(SoftSlider)).dx;
      final double y = tester.getCenter(find.byType(SoftSlider)).dy;

      await tester.tapAt(Offset(_xAt(left, 0.8), y));
      await tester.pump();
      expect(value, 0.2);
      expect(ends, 0);

      final TestGesture gesture = await tester.startGesture(
        Offset(_xAt(left, 0.2), y),
      );
      await gesture.moveBy(const Offset(40, 0));
      await tester.pump();
      await gesture.moveTo(Offset(_xAt(left, 0.6), y));
      await tester.pump();
      expect(value, closeTo(0.6, 1e-6));
      // Past the end the value pins to the maximum.
      await gesture.moveTo(Offset(left + _sliderWidth + 50, y));
      await tester.pump();
      expect(value, 1);
      await gesture.up();
      await tester.pump();
      expect(ends, 1);
      await _expectSettles(tester);
    });

    testWidgets('steps snap the reported value', (WidgetTester tester) async {
      final List<double> reported = <double>[];
      double value = 0;
      await tester.pumpWidget(
        StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) => slider(
            value: value,
            max: 8,
            steps: 7,
            onChanged: (double v) => setState(() {
              value = v;
              reported.add(v);
            }),
          ),
        ),
      );
      final double left = tester.getTopLeft(find.byType(SoftSlider)).dx;
      final double y = tester.getCenter(find.byType(SoftSlider)).dy;
      final TestGesture gesture = await tester.startGesture(
        Offset(_xAt(left, 0), y),
      );
      for (int i = 1; i <= 20; i++) {
        await gesture.moveTo(Offset(_xAt(left, i / 20 * 0.7), y));
        await tester.pump(const Duration(milliseconds: 16));
      }
      await gesture.up();
      expect(reported, isNotEmpty);
      for (final double v in reported) {
        expect(v, v.roundToDouble());
      }
      expect(value, closeTo(0.7 * 8, 0.5));
      await _expectSettles(tester);
    });

    testWidgets('custom key points pull the value within the magnet', (
      WidgetTester tester,
    ) async {
      double value = 0;
      await tester.pumpWidget(
        StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) => slider(
            value: value,
            max: 100,
            keyPoints: const <double>[0, 25, 50, 75, 100],
            onChanged: (double v) => setState(() => value = v),
          ),
        ),
      );
      final double left = tester.getTopLeft(find.byType(SoftSlider)).dx;
      final double y = tester.getCenter(find.byType(SoftSlider)).dy;
      final TestGesture gesture = await tester.startGesture(
        Offset(_xAt(left, 0), y),
      );
      await gesture.moveTo(Offset(_xAt(left, 0.26), y));
      await tester.pump();
      expect(value, 25);
      await gesture.moveTo(Offset(_xAt(left, 0.4), y));
      await tester.pump();
      expect(value, closeTo(40, 0.01));
      await gesture.up();
      await _expectSettles(tester);
    });

    testWidgets('a disabled slider ignores drags', (WidgetTester tester) async {
      double value = 0.7;
      await tester.pumpWidget(
        slider(
          value: value,
          onChanged: (double v) => value = v,
          enabled: false,
        ),
      );
      await tester.drag(find.byType(SoftSlider), const Offset(-120, 0));
      await tester.pump();
      expect(value, 0.7);
      await _expectSettles(tester);
    });

    testWidgets('inside a list a sideways drag is the slider\'s', (
      WidgetTester tester,
    ) async {
      final ScrollController controller = ScrollController();
      addTearDown(controller.dispose);
      double value = 0.5;
      await tester.pumpWidget(
        _host(
          SizedBox(
            width: _sliderWidth,
            height: 400,
            child: StatefulBuilder(
              builder: (BuildContext context, StateSetter setState) => ListView(
                controller: controller,
                children: <Widget>[
                  const SizedBox(height: 100),
                  SoftSlider(
                    value: value,
                    onChanged: (double v) => setState(() => value = v),
                  ),
                  const SizedBox(height: 1000),
                ],
              ),
            ),
          ),
        ),
      );
      final Offset centre = tester.getCenter(find.byType(SoftSlider));

      // Mostly sideways: the slider takes it, the list stays put.
      TestGesture gesture = await tester.startGesture(centre);
      for (int i = 0; i < 10; i++) {
        await gesture.moveBy(const Offset(10, 3));
        await tester.pump();
      }
      await gesture.up();
      await tester.pump();
      expect(controller.offset, 0);
      expect(value, greaterThan(0.6));

      // Mostly vertical: the list scrolls, the value stays.
      final double before = value;
      gesture = await tester.startGesture(centre);
      for (int i = 0; i < 10; i++) {
        await gesture.moveBy(const Offset(3, -10));
        await tester.pump();
      }
      await gesture.up();
      await tester.pump();
      expect(controller.offset, greaterThan(0));
      expect(value, before);
      await _expectSettles(tester);
    });

    testWidgets('accessibility actions step the value', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      double value = 0.5;
      await tester.pumpWidget(
        slider(value: value, onChanged: (double v) => value = v),
      );
      final SemanticsNode node = tester.getSemantics(_semanticsOf(SoftSlider));
      expect(node.flagsCollection.isSlider, isTrue);
      expect(node.value, '50%');
      node.owner!.performAction(node.id, SemanticsAction.increase);
      expect(value, closeTo(0.55, 1e-9));
      handle.dispose();
    });
  });

  group('SoftRangeSlider', () {
    Widget range({
      required SoftRangeValues values,
      required ValueChanged<SoftRangeValues> onChanged,
      bool dark = false,
      int steps = 0,
    }) {
      return _host(
        SizedBox(
          width: _sliderWidth,
          child: SoftRangeSlider(
            values: values,
            onChanged: onChanged,
            steps: steps,
            showKeyPoints: steps > 0,
          ),
        ),
        dark: dark,
      );
    }

    for (final bool dark in <bool>[false, true]) {
      testWidgets('lays out 20 tall in ${dark ? 'dark' : 'light'}', (
        WidgetTester tester,
      ) async {
        await tester.pumpWidget(
          range(
            values: const SoftRangeValues(0.2, 0.8),
            onChanged: (_) {},
            steps: 7,
            dark: dark,
          ),
        );
        expect(
          tester.getSize(find.byType(SoftRangeSlider)),
          const Size(_sliderWidth, 20),
        );
        expect(tester.takeException(), isNull);
        await _expectSettles(tester);
      });
    }

    testWidgets('a drag takes the nearer thumb', (WidgetTester tester) async {
      SoftRangeValues values = const SoftRangeValues(0.2, 0.8);
      await tester.pumpWidget(
        StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) => range(
            values: values,
            onChanged: (SoftRangeValues v) => setState(() => values = v),
          ),
        ),
      );
      final double left = tester.getTopLeft(find.byType(SoftRangeSlider)).dx;
      final double y = tester.getCenter(find.byType(SoftRangeSlider)).dy;

      TestGesture gesture = await tester.startGesture(
        Offset(_xAt(left, 0.75), y),
      );
      await gesture.moveBy(const Offset(-30, 0));
      await tester.pump();
      await gesture.moveTo(Offset(_xAt(left, 0.6), y));
      await tester.pump();
      await gesture.up();
      await tester.pump();
      expect(values.start, 0.2);
      expect(values.end, closeTo(0.6, 1e-6));

      gesture = await tester.startGesture(Offset(_xAt(left, 0.2), y));
      await gesture.moveBy(const Offset(30, 0));
      await tester.pump();
      await gesture.moveTo(Offset(_xAt(left, 0.3), y));
      await tester.pump();
      await gesture.up();
      await tester.pump();
      expect(values.start, closeTo(0.3, 1e-6));
      expect(values.end, closeTo(0.6, 1e-6));
      await _expectSettles(tester);
    });

    testWidgets('the thumbs never cross', (WidgetTester tester) async {
      SoftRangeValues values = const SoftRangeValues(0.4, 0.6);
      final List<SoftRangeValues> reported = <SoftRangeValues>[];
      await tester.pumpWidget(
        StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) => range(
            values: values,
            onChanged: (SoftRangeValues v) => setState(() {
              values = v;
              reported.add(v);
            }),
          ),
        ),
      );
      final double left = tester.getTopLeft(find.byType(SoftRangeSlider)).dx;
      final double y = tester.getCenter(find.byType(SoftRangeSlider)).dy;
      final TestGesture gesture = await tester.startGesture(
        Offset(_xAt(left, 0.4), y),
      );
      for (int i = 1; i <= 20; i++) {
        await gesture.moveTo(Offset(_xAt(left, 0.4 + i * 0.025), y));
        await tester.pump(const Duration(milliseconds: 16));
      }
      await gesture.up();
      await tester.pump();
      expect(reported, isNotEmpty);
      for (final SoftRangeValues v in reported) {
        expect(v.start, lessThanOrEqualTo(v.end));
      }
      // The drag pushed the start thumb into the end one and carried on with
      // it.
      expect(values.end, closeTo(0.9, 1e-6));
      expect(values.start, closeTo(0.6, 1e-6));
      await _expectSettles(tester);
    });
  });
}
