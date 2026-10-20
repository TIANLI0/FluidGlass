import 'package:fluid_glass/fluid_glass.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(Widget child, {TextDirection direction = TextDirection.ltr}) =>
    MaterialApp(
      home: Directionality(
        textDirection: direction,
        child: Scaffold(body: Center(child: child)),
      ),
    );

void main() {
  for (final bool interactive in <bool>[true, false]) {
    testWidgets('button activates once per keyboard press ($interactive)', (
      WidgetTester tester,
    ) async {
      int calls = 0;
      final FocusNode focus = FocusNode();
      addTearDown(focus.dispose);
      await tester.pumpWidget(
        _host(
          LiquidButton(
            backdrop: emptyBackdrop,
            onPressed: () => calls++,
            isInteractive: interactive,
            focusNode: focus,
            child: const Text('Save'),
          ),
        ),
      );
      focus.requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pumpAndSettle();
      expect(calls, 2);
    });
  }

  testWidgets('Tab skips a disabled button and focus has a visible border', (
    WidgetTester tester,
  ) async {
    final FocusNode first = FocusNode();
    final FocusNode disabled = FocusNode();
    final FocusNode last = FocusNode();
    addTearDown(first.dispose);
    addTearDown(disabled.dispose);
    addTearDown(last.dispose);
    final FocusHighlightStrategy strategy =
        FocusManager.instance.highlightStrategy;
    FocusManager.instance.highlightStrategy =
        FocusHighlightStrategy.alwaysTraditional;
    addTearDown(() => FocusManager.instance.highlightStrategy = strategy);
    await tester.pumpWidget(
      _host(
        Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            LiquidButton(
              backdrop: emptyBackdrop,
              onPressed: () {},
              focusNode: first,
              child: const Text('First'),
            ),
            LiquidButton(
              backdrop: emptyBackdrop,
              onPressed: null,
              focusNode: disabled,
              child: const Text('Disabled'),
            ),
            LiquidButton(
              backdrop: emptyBackdrop,
              onPressed: () {},
              focusNode: last,
              child: const Text('Last'),
            ),
          ],
        ),
      ),
    );
    first.requestFocus();
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pumpAndSettle();
    expect(last.hasPrimaryFocus, isTrue);
    expect(disabled.hasFocus, isFalse);
    final Finder border = find.descendant(
      of: find.ancestor(
        of: find.text('Last'),
        matching: find.byType(LiquidButton),
      ),
      matching: find.byWidgetPredicate(
        (Widget widget) =>
            widget is DecoratedBox &&
            widget.decoration is BoxDecoration &&
            (widget.decoration as BoxDecoration).border != null,
      ),
    );
    expect(border, findsOneWidget);
  });

  testWidgets('an icon button exposes its tooltip to accessibility', (
    WidgetTester tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      _host(
        LiquidButton(
          backdrop: emptyBackdrop,
          onPressed: () {},
          tooltip: 'Add item',
          child: const Icon(Icons.add),
        ),
      ),
    );
    expect(find.byTooltip('Add item'), findsOneWidget);
    expect(tester.getSemantics(find.byIcon(Icons.add)).tooltip, 'Add item');
    handle.dispose();
  });

  testWidgets('toggle track and knob each toggle once', (
    WidgetTester tester,
  ) async {
    final List<bool> selected = <bool>[];
    await tester.pumpWidget(
      _host(
        LiquidToggle(
          selected: false,
          onSelect: selected.add,
          backdrop: emptyBackdrop,
        ),
      ),
    );
    final Rect box = tester.getRect(find.byType(LiquidToggle));
    await tester.tapAt(Offset(box.right - 3, box.center.dy));
    await tester.pumpAndSettle();
    expect(selected, <bool>[true]);
    await tester.tapAt(Offset(box.left + 15, box.center.dy));
    await tester.pumpAndSettle();
    expect(selected, <bool>[true, true]);
  });

  testWidgets('toggle cancels a pointer without committing', (
    WidgetTester tester,
  ) async {
    final List<bool> selected = <bool>[];
    await tester.pumpWidget(
      _host(
        LiquidToggle(
          selected: false,
          onSelect: selected.add,
          backdrop: emptyBackdrop,
        ),
      ),
    );
    final TestGesture gesture = await tester.startGesture(
      tester.getTopLeft(find.byType(LiquidToggle)) + const Offset(20, 14),
    );
    await gesture.moveBy(const Offset(20, 0));
    await gesture.cancel();
    await tester.pumpAndSettle();
    expect(selected, isEmpty);
    expect(tester.binding.transientCallbackCount, 0);
  });

  testWidgets('toggle can be disabled under a finger and enabled again', (
    WidgetTester tester,
  ) async {
    bool enabled = true;
    int calls = 0;
    late StateSetter update;
    await tester.pumpWidget(
      _host(
        StatefulBuilder(
          builder: (context, setState) {
            update = setState;
            return LiquidToggle(
              selected: false,
              backdrop: emptyBackdrop,
              onSelect: enabled ? (_) => calls++ : null,
            );
          },
        ),
      ),
    );
    final TestGesture gesture = await tester.startGesture(
      tester.getTopLeft(find.byType(LiquidToggle)) + const Offset(20, 14),
    );
    update(() => enabled = false);
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();
    expect(calls, 0);
    expect(tester.binding.transientCallbackCount, 0);
    update(() => enabled = true);
    await tester.pump();
    await tester.tap(find.byType(LiquidToggle));
    await tester.pumpAndSettle();
    expect(calls, 1);
  });

  testWidgets('toggle accepts keyboard activation', (
    WidgetTester tester,
  ) async {
    final FocusNode focus = FocusNode();
    addTearDown(focus.dispose);
    final List<bool> selected = <bool>[];
    await tester.pumpWidget(
      _host(
        LiquidToggle(
          selected: true,
          backdrop: emptyBackdrop,
          onSelect: selected.add,
          focusNode: focus,
          semanticLabel: 'Notifications',
        ),
      ),
    );
    focus.requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    expect(selected, <bool>[false]);
  });

  for (final String control in <String>['slider', 'toggle', 'segments']) {
    testWidgets(
      '$control does not resume a cancelled pointer after re-enabling',
      (WidgetTester tester) async {
        bool enabled = true;
        int calls = 0;
        late StateSetter update;
        await tester.pumpWidget(
          _host(
            SizedBox(
              width: control == 'toggle' ? 64 : 300,
              child: StatefulBuilder(
                builder: (context, setState) {
                  update = setState;
                  return switch (control) {
                    'toggle' => LiquidToggle(
                      selected: false,
                      backdrop: emptyBackdrop,
                      onSelect: enabled ? (_) => calls++ : null,
                    ),
                    'segments' => LiquidSegmentedControl(
                      selectedIndex: 0,
                      backdrop: emptyBackdrop,
                      onSelected: enabled ? (_) => calls++ : null,
                      segments: const <Widget>[Text('A'), Text('B')],
                    ),
                    _ => LiquidSlider(
                      value: 0.5,
                      backdrop: emptyBackdrop,
                      onValueChanged: enabled ? (_) => calls++ : null,
                    ),
                  };
                },
              ),
            ),
          ),
        );
        final Finder thumb = find.byType(DrawBackdrop).last;
        final TestGesture gesture = await tester.startGesture(
          tester.getCenter(thumb),
        );
        update(() => enabled = false);
        await tester.pump();
        update(() => enabled = true);
        await tester.pump();
        await gesture.moveBy(const Offset(40, 0));
        await gesture.up();
        await tester.pumpAndSettle();
        expect(calls, 0);
        expect(tester.binding.transientCallbackCount, 0);
      },
    );
  }

  for (final TextDirection direction in TextDirection.values) {
    testWidgets('slider keyboard steps and endpoints ($direction)', (
      tester,
    ) async {
      final FocusNode focus = FocusNode();
      addTearDown(focus.dispose);
      double value = 0.5;
      final List<String> events = <String>[];
      await tester.pumpWidget(
        _host(
          StatefulBuilder(
            builder: (context, setState) => SizedBox(
              width: 300,
              child: LiquidSlider(
                value: value,
                backdrop: emptyBackdrop,
                focusNode: focus,
                divisions: 10,
                onChangeStart: (v) => events.add('start'),
                onValueChanged: (v) {
                  events.add('change');
                  setState(() => value = v);
                },
                onChangeEnd: (v) => events.add('end'),
              ),
            ),
          ),
          direction: direction,
        ),
      );
      focus.requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      expect(value, closeTo(direction == TextDirection.ltr ? 0.6 : 0.4, 1e-9));
      expect(events, <String>['start', 'change', 'end']);
      await tester.sendKeyEvent(LogicalKeyboardKey.home);
      await tester.pumpAndSettle();
      expect(value, 0);
      await tester.sendKeyEvent(LogicalKeyboardKey.end);
      await tester.pumpAndSettle();
      expect(value, 1);
      final int before = events.length;
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pumpAndSettle();
      expect(events.length, before, reason: 'an endpoint is a no-op');
    });
  }

  testWidgets('slider accepts taps outside the six-pixel visible track', (
    tester,
  ) async {
    final List<double> changed = <double>[];
    await tester.pumpWidget(
      _host(
        SizedBox(
          width: 300,
          child: LiquidSlider(
            value: 0.5,
            backdrop: emptyBackdrop,
            onValueChanged: changed.add,
          ),
        ),
      ),
    );
    final Rect target = tester.getRect(find.byType(LiquidSlider));
    expect(target.height, 48);
    await tester.tapAt(Offset(target.left + target.width / 4, target.top + 3));
    await tester.pumpAndSettle();
    expect(changed, <double>[0.25]);
  });

  testWidgets('disabled controls expose state without accessibility actions', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      _host(
        Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const LiquidToggle(
              selected: true,
              onSelect: null,
              backdrop: emptyBackdrop,
              semanticLabel: 'Notifications',
            ),
            const SizedBox(
              width: 300,
              child: LiquidSlider(
                value: 0.5,
                onValueChanged: null,
                backdrop: emptyBackdrop,
                semanticLabel: 'Volume',
              ),
            ),
          ],
        ),
      ),
    );
    final SemanticsNode toggle = tester.getSemantics(find.byType(LiquidToggle));
    expect(toggle.getSemanticsData().hasAction(SemanticsAction.tap), isFalse);
    expect(toggle.label, 'Notifications');
    final SemanticsNode slider = tester.getSemantics(find.byType(LiquidSlider));
    expect(
      slider.getSemanticsData().hasAction(SemanticsAction.increase),
      isFalse,
    );
    expect(
      slider.getSemanticsData().hasAction(SemanticsAction.decrease),
      isFalse,
    );
    expect(slider.getSemanticsData().hasAction(SemanticsAction.focus), isFalse);
    expect(slider.value, '50%');
    handle.dispose();
  });

  testWidgets('slider describes values in application units', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      _host(
        SizedBox(
          width: 300,
          child: LiquidSlider(
            value: 8,
            valueRange: (start: 0, end: 16),
            divisions: 16,
            backdrop: emptyBackdrop,
            onValueChanged: (_) {},
            semanticLabel: 'Volume',
            semanticFormatterCallback: (v) => '${v.round()} dB',
          ),
        ),
      ),
    );
    final SemanticsNode node = tester.getSemantics(find.byType(LiquidSlider));
    expect(node.label, 'Volume');
    expect(node.value, '8 dB');
    expect(node.increasedValue, '9 dB');
    handle.dispose();
  });

  testWidgets(
    'slider suppresses duplicate snapped values and cancels end writes',
    (tester) async {
      final List<double> changes = <double>[];
      final List<double> starts = <double>[];
      final List<double> ends = <double>[];
      await tester.pumpWidget(
        _host(
          SizedBox(
            width: 300,
            child: LiquidSlider(
              value: 0.5,
              divisions: 10,
              backdrop: emptyBackdrop,
              onValueChanged: changes.add,
              onChangeStart: starts.add,
              onChangeEnd: ends.add,
            ),
          ),
        ),
      );
      final TestGesture gesture = await tester.startGesture(
        tester.getCenter(find.byType(DrawBackdrop)),
      );
      for (int i = 0; i < 20; i++) {
        await gesture.moveBy(const Offset(1, 0));
        await tester.pump(const Duration(milliseconds: 16));
      }
      await gesture.cancel();
      await tester.pumpAndSettle();
      expect(starts, <double>[0.5]);
      expect(changes, hasLength(1));
      expect(changes.single, closeTo(0.6, 1e-9));
      expect(ends, isEmpty);
      expect(tester.binding.transientCallbackCount, 0);
    },
  );

  testWidgets(
    'segment control fits in an unconstrained Row and supports keys',
    (tester) async {
      int index = 0;
      final FocusNode focus = FocusNode();
      addTearDown(focus.dispose);
      await tester.pumpWidget(
        _host(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              StatefulBuilder(
                builder: (context, setState) => LiquidSegmentedControl(
                  selectedIndex: index,
                  onSelected: (v) => setState(() => index = v),
                  backdrop: emptyBackdrop,
                  focusNode: focus,
                  segments: const <Widget>[
                    Text('Day'),
                    Text('Week'),
                    Text('Month'),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(tester.getSize(find.byType(LiquidSegmentedControl)).width, 306);
      focus.requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      expect(index, 1);
      await tester.sendKeyEvent(LogicalKeyboardKey.end);
      await tester.pumpAndSettle();
      expect(index, 2);
    },
  );
}
