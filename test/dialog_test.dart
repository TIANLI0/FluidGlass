import 'dart:async';

import 'package:fluid_glass/fluid_glass.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const int _w = 400;
const int _h = 700;

Widget _bare(Widget child) => MaterialApp(
  home: Align(
    alignment: Alignment.topLeft,
    child: SizedBox(width: _w.toDouble(), height: _h.toDouble(), child: child),
  ),
);

LiquidDialog _dialog({
  String? title = 'Delete this file?',
  String? message = 'It will not be recoverable.',
  Widget? child,
  List<LiquidDialogAction> actions = const <LiquidDialogAction>[],
  LiquidDialogActionsAxis axis = LiquidDialogActionsAxis.automatic,
  bool scrollable = false,
}) => LiquidDialog(
  backdrop: emptyBackdrop,
  title: title,
  message: message,
  actions: actions,
  actionsAxis: axis,
  scrollable: scrollable,
  child: child,
);

void main() {
  testWidgets('the title, the message and the actions', (
    WidgetTester tester,
  ) async {
    final List<String> pressed = <String>[];
    await tester.pumpWidget(
      _bare(
        _dialog(
          actions: <LiquidDialogAction>[
            LiquidDialogAction(
              label: 'Cancel',
              onPressed: () => pressed.add('cancel'),
            ),
            LiquidDialogAction(
              label: 'Delete',
              isPrimary: true,
              isDestructive: true,
              onPressed: () => pressed.add('delete'),
            ),
          ],
        ),
      ),
    );

    expect(find.text('Delete this file?'), findsOneWidget);
    expect(find.text('It will not be recoverable.'), findsOneWidget);

    await tester.tap(find.text('Delete'));
    await tester.pump();
    expect(pressed, <String>['delete']);
  });

  testWidgets('an action never dismisses on its own', (
    WidgetTester tester,
  ) async {
    late BuildContext pageContext;
    await tester.pumpWidget(
      _bare(
        Builder(
          builder: (BuildContext context) {
            pageContext = context;
            return const SizedBox.expand();
          },
        ),
      ),
    );
    // A "read the policy" action opens something and leaves the question up.
    var opened = 0;
    unawaited(
      showLiquidDialog<void>(
        context: pageContext,
        title: 'Share data?',
        actions: <LiquidDialogAction>[
          LiquidDialogAction(
            label: 'Privacy policy',
            onPressed: () => opened++,
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Privacy policy'));
    await tester.pumpAndSettle();

    expect(opened, 1);
    expect(find.byType(LiquidDialog), findsOneWidget);
  });

  testWidgets('two actions share a row, three stack', (
    WidgetTester tester,
  ) async {
    const List<LiquidDialogAction> two = <LiquidDialogAction>[
      LiquidDialogAction(label: 'Cancel'),
      LiquidDialogAction(label: 'Okay'),
    ];
    await tester.pumpWidget(_bare(_dialog(actions: two)));
    expect(
      tester.getTopLeft(find.text('Cancel')).dy,
      tester.getTopLeft(find.text('Okay')).dy,
    );

    await tester.pumpWidget(
      _bare(
        _dialog(
          actions: <LiquidDialogAction>[
            ...two,
            const LiquidDialogAction(label: 'Privacy policy'),
          ],
        ),
      ),
    );
    expect(
      tester.getTopLeft(find.text('Okay')).dy,
      greaterThan(tester.getTopLeft(find.text('Cancel')).dy),
    );
  });

  testWidgets('the axis can be forced against the count', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _bare(
        _dialog(
          axis: LiquidDialogActionsAxis.vertical,
          actions: const <LiquidDialogAction>[
            LiquidDialogAction(label: 'Cancel'),
            LiquidDialogAction(label: 'Okay'),
          ],
        ),
      ),
    );
    expect(
      tester.getTopLeft(find.text('Okay')).dy,
      greaterThan(tester.getTopLeft(find.text('Cancel')).dy),
    );
  });

  testWidgets('a long message scrolls, the title and actions hold still', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _bare(
        _dialog(
          message: 'A very long disclosure. ' * 200,
          scrollable: true,
          actions: const <LiquidDialogAction>[
            LiquidDialogAction(label: 'Okay', isPrimary: true),
          ],
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    final double titleY = tester.getTopLeft(find.text('Delete this file?')).dy;
    final double actionY = tester.getTopLeft(find.text('Okay')).dy;

    await tester.drag(
      find.byType(SingleChildScrollView),
      const Offset(0, -200),
    );
    await tester.pump();

    expect(tester.getTopLeft(find.text('Delete this file?')).dy, titleY);
    expect(tester.getTopLeft(find.text('Okay')).dy, actionY);
  });

  testWidgets('free-form content replaces the message', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _bare(
        _dialog(
          child: const TextField(key: Key('field')),
          actions: const <LiquidDialogAction>[
            LiquidDialogAction(label: 'Unlock', isPrimary: true),
          ],
        ),
      ),
    );

    expect(find.byKey(const Key('field')), findsOneWidget);
    expect(find.text('It will not be recoverable.'), findsNothing);
  });

  testWidgets('an opaque surface colour drops the glass', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _bare(
        LiquidDialog(
          backdrop: emptyBackdrop,
          title: 'High contrast',
          message: 'No glass here.',
          surfaceColor: const Color(0xFF101010),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('High contrast'), findsOneWidget);
  });

  testWidgets('the keyboard is added to the inset', (
    WidgetTester tester,
  ) async {
    Widget withInsets(double bottom) => MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(viewInsets: EdgeInsets.only(bottom: bottom)),
        child: _dialog(
          actions: const <LiquidDialogAction>[
            LiquidDialogAction(label: 'Okay', isPrimary: true),
          ],
        ),
      ),
    );

    await tester.pumpWidget(withInsets(0));
    final double restingBottom = tester.getBottomLeft(find.text('Okay')).dy;

    await tester.pumpWidget(withInsets(300));
    await tester.pump();

    expect(tester.getBottomLeft(find.text('Okay')).dy, lessThan(restingBottom));
  });

  testWidgets('type overrides re-letter the dialog without resizing it', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _bare(
        const LiquidDialog(
          backdrop: emptyBackdrop,
          title: 'Titled',
          message: 'Bodied',
          actions: <LiquidDialogAction>[LiquidDialogAction(label: 'Okay')],
          titleStyle: TextStyle(fontFamily: 'Brand'),
          messageStyle: TextStyle(fontFamily: 'Brand'),
          actionStyle: TextStyle(fontFamily: 'Brand'),
        ),
      ),
    );

    TextStyle styleOf(String text) =>
        tester.widget<Text>(find.text(text)).style!;

    // The family is taken; the built-in sizes and weights survive it.
    expect(styleOf('Titled').fontFamily, 'Brand');
    expect(styleOf('Titled').fontSize, 22);
    expect(styleOf('Titled').fontWeight, FontWeight.w600);
    expect(styleOf('Bodied').fontFamily, 'Brand');
    expect(styleOf('Bodied').fontSize, 15);
    expect(styleOf('Okay').fontFamily, 'Brand');
    expect(styleOf('Okay').fontSize, 16);
  });
}
