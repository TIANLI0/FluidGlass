import 'package:fluid_glass/fluid_glass.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _tabs({double? height, ValueChanged<int>? onPressed}) => MaterialApp(
  home: Scaffold(
    body: Align(
      alignment: Alignment.bottomCenter,
      child: SizedBox(
        width: 300,
        child: height == null
            ? LiquidBottomTabs(
                selectedTabIndex: 0,
                onTabSelected: (int _) {},
                backdrop: emptyBackdrop,
                tabsCount: 3,
                children: _children(onPressed),
              )
            : LiquidBottomTabs(
                selectedTabIndex: 0,
                onTabSelected: (int _) {},
                backdrop: emptyBackdrop,
                tabsCount: 3,
                height: height,
                children: _children(onPressed),
              ),
      ),
    ),
  ),
);

List<Widget> _children(ValueChanged<int>? onPressed) => <Widget>[
  for (int i = 0; i < 3; i++)
    LiquidBottomTab(
      onPressed: () => onPressed?.call(i),
      children: <Widget>[Text('tab $i')],
    ),
];

void main() {
  testWidgets('the bar keeps its 64 when no height is given', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_tabs());
    expect(tester.getSize(find.byType(LiquidBottomTabs)).height, 64);
    expect(LiquidBottomTabs.defaultHeight, 64);
  });

  testWidgets('a shorter bar lays its row out inside the same 4dp inset', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_tabs(height: 52));
    expect(tester.getSize(find.byType(LiquidBottomTabs)).height, 52);
    // The visible row is the first of the two renderings of the tabs.
    expect(tester.getSize(find.byType(LiquidBottomTab).first).height, 44);
  });

  testWidgets('a shorter bar still takes taps on every tab', (
    WidgetTester tester,
  ) async {
    int? tapped;
    await tester.pumpWidget(
      _tabs(height: 52, onPressed: (int i) => tapped = i),
    );
    await tester.tapAt(tester.getCenter(find.text('tab 2').first));
    await tester.pump();
    expect(tapped, 2);
  });
}
