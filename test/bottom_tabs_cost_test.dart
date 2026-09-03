import 'package:fluid_glass/fluid_glass.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// What moving the selection pill costs, in captures.
//
// Every capture is an `OffsetLayer.toImageSync` — a pipeline flush. The bar
// holds two capturable sources: the page it floats over, and the accent-tinted
// copy of its tabs that the pill looks through. Neither changes while the pill
// springs from one tab to the next over a still page, so neither may be
// re-captured: the copy's glass is drawn by the pill itself, not captured from
// a second glass element on every frame.

const double _w = 320;
const double _h = 200;

class _Host extends StatefulWidget {
  const _Host({required this.backdrop});

  final LayerBackdrop backdrop;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  int index = 0;

  void select(int i) => setState(() => index = i);

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: MediaQuery(
        data: const MediaQueryData(),
        child: Theme(
          data: ThemeData(brightness: Brightness.light),
          child: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: _w,
              height: _h,
              child: Stack(
                clipBehavior: Clip.none,
                children: <Widget>[
                  Positioned.fill(
                    child: BackdropLayer(
                      backdrop: widget.backdrop,
                      child: const ColoredBox(color: Color(0xFF808080)),
                    ),
                  ),
                  Positioned(
                    left: 0,
                    top: _h - 64,
                    width: _w,
                    child: LiquidBottomTabs(
                      selectedTabIndex: index,
                      onTabSelected: (int i) => setState(() => index = i),
                      backdrop: widget.backdrop,
                      tabsCount: 3,
                      children: <Widget>[
                        for (int i = 0; i < 3; i++)
                          LiquidBottomTab(
                            onPressed: () => setState(() => index = i),
                            children: <Widget>[
                              const Icon(Icons.circle, size: 12),
                              Text('Tab $i'),
                            ],
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

RenderBackdropLayer _source(WidgetTester tester, Finder finder) =>
    tester.renderObject(finder) as RenderBackdropLayer;

void main() {
  setUp(() {
    // The sampled path. Under `flutter_test` the tier would resolve to `plain`,
    // which never captures anything and would pass these vacuously.
    GlassDeviceTier.instance
      ..reset()
      ..debugCeiling = GlassQuality.liquid
      ..pinnedQuality = GlassQuality.liquid;
  });
  tearDown(() => GlassDeviceTier.instance.reset());

  testWidgets('switching tabs over a still page captures nothing', (
    WidgetTester tester,
  ) async {
    final LayerBackdrop backdrop = LayerBackdrop();
    addTearDown(backdrop.dispose);

    await tester.pumpWidget(_Host(backdrop: backdrop));
    await tester.pump();
    await tester.pump();

    final Finder tabs = find.byType(LiquidBottomTabs);
    final RenderBackdropLayer page = _source(
      tester,
      find.byWidgetPredicate(
        (Widget w) => w is BackdropLayer && identical(w.backdrop, backdrop),
      ),
    );
    final RenderBackdropLayer row = _source(
      tester,
      find.descendant(of: tabs, matching: find.byType(BackdropLayer)),
    );
    expect(
      row.debugCaptureCount,
      greaterThan(0),
      reason: 'the accent tab row is captured once for the pill to read',
    );
    page.debugCaptureCount = 0;
    row.debugCaptureCount = 0;

    tester.state<_HostState>(find.byType(_Host)).select(2);
    // The pill presses, springs across and releases.
    int frames = 0;
    for (; frames < 90; frames++) {
      await tester.pump(const Duration(milliseconds: 16));
      if (!tester.hasRunningAnimations) break;
    }
    expect(frames, greaterThan(5), reason: 'the spring should take a while');
    expect(
      tester.hasRunningAnimations,
      isFalse,
      reason: 'the spring must settle',
    );

    // The page is still, but the panel grows by 16 logical pixels while
    // pressed and so reads a wider strip than it did: a capture or two as it
    // grows, served from then on. What it must not be is one per frame.
    expect(
      page.debugCaptureCount,
      lessThanOrEqualTo(3),
      reason:
          'the page did not change; only the wider strip the pressed '
          'panel reads may cost a capture',
    );
    expect(
      row.debugCaptureCount,
      0,
      reason: 'the accent copy is drawn by the pill, not captured per frame',
    );
  });

  testWidgets('the accent copy is not a glass element of its own', (
    WidgetTester tester,
  ) async {
    final LayerBackdrop backdrop = LayerBackdrop();
    addTearDown(backdrop.dispose);

    await tester.pumpWidget(_Host(backdrop: backdrop));
    await tester.pump();

    // The panel and the pill. A third would be the copy, captured per frame.
    expect(
      find.descendant(
        of: find.byType(LiquidBottomTabs),
        matching: find.byType(DrawBackdrop),
      ),
      findsNWidgets(2),
    );
    // The copy's tabs are still rendered — once, marked, for the pill to read.
    expect(
      find.descendant(
        of: find.byType(LiquidBottomTabs),
        matching: find.byType(LiquidBottomTabScale),
      ),
      findsOneWidget,
    );
    expect(find.text('Tab 1'), findsNWidgets(2));
  });
}
