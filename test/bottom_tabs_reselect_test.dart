import 'package:fluid_glass/fluid_glass.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _bar({
  required int selected,
  double width = 300,
  ValueChanged<int>? onSelected,
  ValueChanged<int>? onReselected,
  List<bool>? copies,
}) => MaterialApp(
  home: Scaffold(
    body: Align(
      alignment: Alignment.bottomCenter,
      child: SizedBox(
        width: width,
        child: LiquidBottomTabs(
          selectedTabIndex: selected,
          onTabSelected: onSelected ?? (int _) {},
          onTabReselected: onReselected,
          backdrop: emptyBackdrop,
          tabsCount: 3,
          children: <Widget>[
            for (int i = 0; i < 3; i++)
              LiquidBottomTab(
                onPressed: () {},
                children: <Widget>[
                  Builder(
                    builder: (BuildContext context) {
                      if (i == 0) {
                        copies?.add(LiquidBottomTabs.isAccentCopy(context));
                      }
                      return Text('tab $i');
                    },
                  ),
                ],
              ),
          ],
        ),
      ),
    ),
  ),
);

void main() {
  testWidgets('a tap on the selected tab is reported as a reselect', (
    tester,
  ) async {
    final reselected = <int>[];
    final selected = <int>[];
    await tester.pumpWidget(
      _bar(selected: 1, onSelected: selected.add, onReselected: reselected.add),
    );

    await tester.tapAt(tester.getCenter(find.text('tab 1').first));
    await tester.pumpAndSettle();

    expect(reselected, <int>[1]);
    expect(selected, isEmpty);
  });

  testWidgets('the pill dragged away and back is not a reselect', (
    tester,
  ) async {
    final reselected = <int>[];
    await tester.pumpWidget(_bar(selected: 1, onReselected: reselected.add));

    final gesture = await tester.startGesture(
      tester.getCenter(find.text('tab 1').first),
    );
    for (int i = 0; i < 10; i++) {
      await gesture.moveBy(const Offset(4, 0));
    }
    for (int i = 0; i < 10; i++) {
      await gesture.moveBy(const Offset(-4, 0));
    }
    await gesture.up();
    await tester.pumpAndSettle();

    expect(reselected, isEmpty);
  });

  testWidgets('a tap on another tab selects it and reselects nothing', (
    tester,
  ) async {
    final reselected = <int>[];
    final selected = <int>[];
    await tester.pumpWidget(
      _bar(selected: 0, onSelected: selected.add, onReselected: reselected.add),
    );

    await tester.tapAt(tester.getCenter(find.text('tab 2').first));
    await tester.pumpAndSettle();

    expect(reselected, isEmpty);
  });

  testWidgets('laid out at zero width it draws nothing and does not throw', (
    tester,
  ) async {
    await tester.pumpWidget(_bar(selected: 0, width: 0));
    expect(tester.takeException(), isNull);
    expect(tester.getSize(find.byType(LiquidBottomTabs)).height, 64);

    await tester.pumpWidget(_bar(selected: 0));
    expect(tester.takeException(), isNull);
    expect(find.text('tab 0'), findsWidgets);
  });

  testWidgets('isAccentCopy tells the copy from the visible row', (
    tester,
  ) async {
    final copies = <bool>[];
    await tester.pumpWidget(_bar(selected: 0, copies: copies));
    expect(copies, containsAll(<bool>[true, false]));
    expect(copies.where((bool c) => c).length, 1);
  });
}
