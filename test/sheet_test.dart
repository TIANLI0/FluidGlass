import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:fluid_glass/fluid_glass.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

const Key _boundary = Key('boundary');
const int _w = 300;
const int _h = 400;

Future<List<double>> _meanRgb(WidgetTester tester, Rect box) async {
  final RenderRepaintBoundary render =
      tester.renderObject(find.byKey(_boundary)) as RenderRepaintBoundary;
  final ui.Image image = render.toImageSync();
  final ByteData? data = await tester.runAsync<ByteData?>(
    () => image.toByteData(format: ui.ImageByteFormat.rawStraightRgba),
  );
  image.dispose();
  final Uint8List p = data!.buffer.asUint8List();
  final List<double> sum = <double>[0, 0, 0];
  int count = 0;
  for (int y = box.top.round(); y < box.bottom.round(); y++) {
    for (int x = box.left.round(); x < box.right.round(); x++) {
      final int i = (y * _w + x) * 4;
      sum[0] += p[i];
      sum[1] += p[i + 1];
      sum[2] += p[i + 2];
      count += 1;
    }
  }
  return <double>[sum[0] / count, sum[1] / count, sum[2] / count];
}

Widget _bare(Widget child) => MaterialApp(
  home: Align(
    alignment: Alignment.topLeft,
    child: RepaintBoundary(
      key: _boundary,
      child: SizedBox(
        width: _w.toDouble(),
        height: _h.toDouble(),
        child: child,
      ),
    ),
  ),
);

List<LiquidSheetItem> _threeOptions(List<String> picked) => <LiquidSheetItem>[
  LiquidSheetItem(
    label: 'Follow system',
    detail: 'English',
    isSelected: true,
    onSelected: () => picked.add('system'),
  ),
  LiquidSheetItem(label: 'Light', onSelected: () => picked.add('light')),
  LiquidSheetItem(label: 'Dark', onSelected: () => picked.add('dark')),
];

void main() {
  testWidgets('the title, the rows and one check', (WidgetTester tester) async {
    final List<String> picked = <String>[];
    await tester.pumpWidget(
      _bare(
        Align(
          alignment: Alignment.bottomCenter,
          child: LiquidSheet(
            backdrop: emptyBackdrop,
            title: 'Appearance',
            items: _threeOptions(picked),
          ),
        ),
      ),
    );

    expect(find.text('Appearance'), findsOneWidget);
    expect(find.text('Follow system'), findsOneWidget);
    expect(find.text('English'), findsOneWidget, reason: 'the detail line');
    expect(
      find.byIcon(Icons.check),
      findsOneWidget,
      reason: 'only the selected row is marked',
    );
  });

  testWidgets('a row reports through the item and then the sheet', (
    WidgetTester tester,
  ) async {
    final List<String> picked = <String>[];
    final List<String> reported = <String>[];
    await tester.pumpWidget(
      _bare(
        Align(
          alignment: Alignment.bottomCenter,
          child: LiquidSheet(
            backdrop: emptyBackdrop,
            items: _threeOptions(picked),
            onSelected: (LiquidSheetItem item) => reported.add(item.label),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Dark'));
    await tester.pump();

    expect(picked, <String>['dark']);
    expect(reported, <String>['Dark']);
  });

  testWidgets('a child that scrolls is not wrapped in a second scroll view', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _bare(
        Align(
          alignment: Alignment.bottomCenter,
          child: LiquidSheet(
            backdrop: emptyBackdrop,
            child: SingleChildScrollView(
              child: Column(
                children: <Widget>[
                  for (int i = 0; i < 20; i++)
                    SizedBox(height: 40, child: Text('row $i')),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    // Exactly the caller's own: nesting a second one leaves the inner list
    // unable to move.
    expect(find.byType(SingleChildScrollView), findsOneWidget);

    // `SingleChildScrollView` builds its whole child, so a scrolled-away row is
    // still findable — the position is what moves.
    final double before = tester.getTopLeft(find.text('row 0')).dy;
    await tester.drag(find.text('row 1'), const Offset(0, -200));
    await tester.pump();
    expect(tester.getTopLeft(find.text('row 0')).dy, lessThan(before - 100));
  });

  testWidgets('child replaces the rows', (WidgetTester tester) async {
    await tester.pumpWidget(
      _bare(
        Align(
          alignment: Alignment.bottomCenter,
          child: LiquidSheet(
            backdrop: emptyBackdrop,
            items: const <LiquidSheetItem>[LiquidSheetItem(label: 'ignored')],
            child: const Text('custom'),
          ),
        ),
      ),
    );

    expect(find.text('custom'), findsOneWidget);
    expect(find.text('ignored'), findsNothing);
  });

  testWidgets('rowHeight is the row floor', (WidgetTester tester) async {
    await tester.pumpWidget(
      _bare(
        Align(
          alignment: Alignment.bottomCenter,
          child: LiquidSheet(
            backdrop: emptyBackdrop,
            rowHeight: 72,
            items: const <LiquidSheetItem>[LiquidSheetItem(label: 'One')],
          ),
        ),
      ),
    );

    final Finder row = find.ancestor(
      of: find.text('One'),
      matching: find.byType(ConstrainedBox),
    );
    expect(tester.getSize(row.first).height, greaterThanOrEqualTo(72));
  });

  testWidgets('an opaque surfaceColor drops the glass', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _bare(
        Stack(
          children: <Widget>[
            Positioned.fill(child: CustomPaint(painter: _Stripes())),
            Align(
              alignment: Alignment.bottomCenter,
              child: LiquidSheet(
                backdrop: emptyBackdrop,
                surfaceColor: const Color(0xFFFF0000),
                items: const <LiquidSheetItem>[LiquidSheetItem(label: 'One')],
              ),
            ),
          ],
        ),
      ),
    );
    await tester.pump();

    // Inside the sheet, clear of its top corners: opaque red, not stripes.
    final List<double> rgb = await _meanRgb(
      tester,
      const Rect.fromLTRB(60, 340, 240, 380),
    );
    expect(rgb[0], greaterThan(220));
    expect(rgb[1], lessThan(30));
    expect(rgb[2], lessThan(30));
  });

  testWidgets(
    'a row is a mutually exclusive selectable, labelled with detail',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        _bare(
          Align(
            alignment: Alignment.bottomCenter,
            child: LiquidSheet(
              backdrop: emptyBackdrop,
              items: const <LiquidSheetItem>[
                LiquidSheetItem(
                  label: 'Follow system',
                  detail: 'English',
                  isSelected: true,
                ),
              ],
            ),
          ),
        ),
      );

      final SemanticsHandle handle = tester.ensureSemantics();
      expect(
        tester.getSemantics(find.text('Follow system')),
        matchesSemantics(
          isButton: true,
          isSelected: true,
          hasSelectedState: true,
          isInMutuallyExclusiveGroup: true,
          label: 'Follow system, English',
        ),
      );
      handle.dispose();
    },
  );

  testWidgets('showLiquidSheet dismisses on a selection', (
    WidgetTester tester,
  ) async {
    final List<String> picked = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (BuildContext context) => Center(
            child: TextButton(
              onPressed: () => showLiquidSheet<void>(
                context: context,
                backdrop: emptyBackdrop,
                title: 'Appearance',
                items: _threeOptions(picked),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('Appearance'), findsOneWidget);

    await tester.tap(find.text('Light'));
    await tester.pumpAndSettle();

    expect(picked, <String>['light']);
    expect(find.text('Appearance'), findsNothing);
  });
}

class _Stripes extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFFFFFFFF),
    );
    final Paint black = Paint()..color = const Color(0xFF000000);
    for (double x = 0; x < size.width; x += 8) {
      canvas.drawRect(Rect.fromLTWH(x, 0, 4, size.height), black);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
