import 'package:fluid_glass/fluid_glass.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

// What a screen reader hears, and can do, on each control. Every one of these
// was either silent or said what it was with no way to act on it.

Widget _host(Widget child) {
  return MaterialApp(
    home: Scaffold(body: Center(child: child)),
  );
}

void _perform(WidgetTester tester, Finder finder, SemanticsAction action) {
  final SemanticsNode node = tester.getSemantics(finder);
  node.owner!.performAction(node.id, action);
}

void main() {
  testWidgets('a bottom tab is a selectable button of a set', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    final List<int> tapped = <int>[];
    await tester.pumpWidget(
      _host(
        SizedBox(
          width: 360,
          child: LiquidBottomTabs(
            selectedTabIndex: 0,
            onTabSelected: (_) {},
            backdrop: emptyBackdrop,
            tabsCount: 3,
            children: <Widget>[
              for (int i = 0; i < 3; i++)
                LiquidBottomTab(
                  onPressed: () => tapped.add(i),
                  children: <Widget>[Text('Tab $i')],
                ),
            ],
          ),
        ),
      ),
    );
    expect(
      tester.getSemantics(find.text('Tab 0').first),
      matchesSemantics(
        label: 'Tab 0',
        isButton: true,
        hasSelectedState: true,
        isSelected: true,
        isInMutuallyExclusiveGroup: true,
        hasTapAction: true,
      ),
    );
    expect(
      tester.getSemantics(find.text('Tab 1').first),
      matchesSemantics(
        label: 'Tab 1',
        isButton: true,
        hasSelectedState: true,
        isInMutuallyExclusiveGroup: true,
        hasTapAction: true,
      ),
    );
    _perform(tester, find.text('Tab 2').first, SemanticsAction.tap);
    expect(tapped, <int>[2]);
    handle.dispose();
  });

  testWidgets('a segment is a selectable button of a set', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    final List<int> selected = <int>[];
    await tester.pumpWidget(
      _host(
        SizedBox(
          width: 300,
          child: LiquidSegmentedControl(
            selectedIndex: 0,
            onSelected: selected.add,
            backdrop: emptyBackdrop,
            segments: const <Widget>[Text('Day'), Text('Week')],
          ),
        ),
      ),
    );
    expect(
      tester.getSemantics(find.text('Day')),
      matchesSemantics(
        label: 'Day',
        hasEnabledState: true,
        isEnabled: true,
        isButton: true,
        hasSelectedState: true,
        isSelected: true,
        isInMutuallyExclusiveGroup: true,
        hasTapAction: true,
      ),
    );
    _perform(tester, find.text('Week'), SemanticsAction.tap);
    await tester.pumpAndSettle();
    expect(selected, <int>[1]);
    handle.dispose();
  });

  testWidgets('a toggle says it is on and can be flipped', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    final List<bool> flips = <bool>[];
    await tester.pumpWidget(
      _host(
        LiquidToggle(
          selected: true,
          onSelect: flips.add,
          backdrop: emptyBackdrop,
        ),
      ),
    );
    expect(
      tester.getSemantics(find.byType(LiquidToggle)),
      matchesSemantics(
        hasToggledState: true,
        isToggled: true,
        hasEnabledState: true,
        isEnabled: true,
        isFocusable: true,
        hasFocusAction: true,
        hasTapAction: true,
      ),
    );
    _perform(tester, find.byType(LiquidToggle), SemanticsAction.tap);
    expect(flips, <bool>[false]);
    await tester.pumpAndSettle();
    handle.dispose();
  });

  testWidgets('a slider reports its value and steps either way', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    final List<double> changed = <double>[];
    await tester.pumpWidget(
      _host(
        SizedBox(
          width: 300,
          child: LiquidSlider(
            value: 0.5,
            valueRange: (start: 0, end: 1),
            visibilityThreshold: 0.001,
            backdrop: emptyBackdrop,
            onValueChanged: changed.add,
          ),
        ),
      ),
    );
    expect(
      tester.getSemantics(find.byType(LiquidSlider)),
      matchesSemantics(
        isSlider: true,
        hasEnabledState: true,
        isEnabled: true,
        isFocusable: true,
        hasFocusAction: true,
        value: '50%',
        increasedValue: '60%',
        decreasedValue: '40%',
        hasIncreaseAction: true,
        hasDecreaseAction: true,
        textDirection: TextDirection.ltr,
      ),
    );
    _perform(tester, find.byType(LiquidSlider), SemanticsAction.increase);
    expect(changed.single, closeTo(0.6, 1e-9));
    await tester.pumpAndSettle();
    handle.dispose();
  });

  testWidgets('a button is a button, and a disabled one says so', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    int pressed = 0;
    await tester.pumpWidget(
      _host(
        Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            LiquidButton(
              onPressed: () => pressed++,
              backdrop: emptyBackdrop,
              children: const <Widget>[Text('Go')],
            ),
            const LiquidButton(
              onPressed: null,
              backdrop: emptyBackdrop,
              children: <Widget>[Text('Stop')],
            ),
          ],
        ),
      ),
    );
    expect(
      tester.getSemantics(find.text('Go')),
      matchesSemantics(
        label: 'Go',
        isFocusable: true,
        hasFocusAction: true,
        isButton: true,
        hasEnabledState: true,
        isEnabled: true,
        hasTapAction: true,
      ),
    );
    expect(
      tester.getSemantics(find.text('Stop')),
      matchesSemantics(label: 'Stop', isButton: true, hasEnabledState: true),
    );
    _perform(tester, find.text('Go'), SemanticsAction.tap);
    expect(pressed, 1);
    await tester.pumpAndSettle();
    handle.dispose();
  });

  testWidgets('a sheet row can be chosen by a screen reader', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    final List<String> picked = <String>[];
    await tester.pumpWidget(
      _host(
        LiquidSheet(
          backdrop: emptyBackdrop,
          items: <LiquidSheetItem>[
            LiquidSheetItem(label: 'Light', onSelected: () => picked.add('l')),
            LiquidSheetItem(label: 'Dark', onSelected: () => picked.add('d')),
          ],
        ),
      ),
    );
    expect(
      tester.getSemantics(find.text('Dark')),
      matchesSemantics(
        label: 'Dark',
        isButton: true,
        hasSelectedState: true,
        isInMutuallyExclusiveGroup: true,
        hasTapAction: true,
      ),
    );
    _perform(tester, find.text('Dark'), SemanticsAction.tap);
    expect(picked, <String>['d']);
    await tester.pumpAndSettle();
    handle.dispose();
  });

  testWidgets('a dialog names its route by its title', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    await tester.pumpWidget(
      _host(const LiquidDialog(backdrop: emptyBackdrop, title: 'Delete?')),
    );
    expect(
      tester.getSemantics(find.byType(LiquidDialog)),
      matchesSemantics(
        label: 'Delete?',
        scopesRoute: true,
        namesRoute: true,
        children: <Matcher>[anything],
      ),
    );
    handle.dispose();
  });

  testWidgets('a progress rim reports how far along it is', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    final RimLightController controller = RimLightController(
      vsync: const TestVSync(),
    );
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      _host(
        RimLight(
          controller: controller,
          shape: const Capsule(),
          child: const SizedBox(width: 200, height: 56),
        ),
      ),
    );
    controller.setProgress(0.42);
    await tester.pump();
    expect(tester.getSemantics(find.byType(RimLight)).value, '42%');
    controller.clear();
    await tester.pumpAndSettle();
    handle.dispose();
  });
}
