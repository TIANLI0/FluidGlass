import 'package:fluid_glass/fluid_glass.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _tabs({required int selected, required bool isInteractive}) =>
    MaterialApp(
      home: Scaffold(
        body: Align(
          alignment: Alignment.bottomCenter,
          child: SizedBox(
            width: 300,
            child: LiquidBottomTabs(
              selectedTabIndex: selected,
              onTabSelected: (int _) {},
              backdrop: emptyBackdrop,
              tabsCount: 3,
              isInteractive: isInteractive,
              children: <Widget>[
                for (int i = 0; i < 3; i++)
                  LiquidBottomTab(
                    onPressed: () {},
                    children: <Widget>[Text('tab $i')],
                  ),
              ],
            ),
          ),
        ),
      ),
    );

void main() {
  testWidgets('with motion reduced a new selection jumps, it does not spring', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_tabs(selected: 0, isInteractive: false));
    await tester.pumpWidget(_tabs(selected: 2, isInteractive: false));
    await tester.pump();
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('interactive by default: the pill springs across', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_tabs(selected: 0, isInteractive: true));
    await tester.pumpWidget(_tabs(selected: 2, isInteractive: true));
    await tester.pump();
    expect(tester.hasRunningAnimations, isTrue);
    await tester.pumpAndSettle();
  });

  testWidgets('with motion reduced the tabs still take taps', (
    WidgetTester tester,
  ) async {
    int? tapped;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.bottomCenter,
            child: SizedBox(
              width: 300,
              child: LiquidBottomTabs(
                selectedTabIndex: 0,
                onTabSelected: (int _) {},
                backdrop: emptyBackdrop,
                tabsCount: 3,
                isInteractive: false,
                children: <Widget>[
                  for (int i = 0; i < 3; i++)
                    LiquidBottomTab(
                      onPressed: () => tapped = i,
                      children: <Widget>[Text('tab $i')],
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    // The bar keeps an invisible accent copy of its tabs; tap the place.
    await tester.tapAt(tester.getCenter(find.text('tab 1').first));
    await tester.pump();
    expect(tapped, 1);
  });
}
