import 'package:fluid_glass/fluid_glass.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const double _thumbWidth = 40;

Widget _host(Widget child) {
  return MaterialApp(
    home: Scaffold(body: Center(child: child)),
  );
}

Widget _slider({
  required double value,
  ({double start, double end}) range = (start: 0, end: 1),
  ValueChanged<double>? onChanged,
}) {
  return LiquidSlider(
    value: value,
    valueRange: range,
    visibilityThreshold: 0.001,
    backdrop: emptyBackdrop,
    onValueChanged: onChanged ?? (_) {},
  );
}

/// How far the thumb's glass sits from the slider's leading edge.
double _thumbOffset(WidgetTester tester) {
  return tester.getTopLeft(find.byType(DrawBackdrop)).dx -
      tester.getTopLeft(find.byType(LiquidSlider)).dx;
}

RenderBackdropLayer _track(WidgetTester tester) {
  return tester.renderObject<RenderBackdropLayer>(
    find.byWidgetPredicate(
      (Widget w) => w.runtimeType.toString() == '_BackdropLayerHost',
    ),
  );
}

void main() {
  // Regression: the fill painter listened to the whole drag animation, and
  // the fill sits inside the track's own capture. Every press, scale or
  // velocity tick repainted identical fill pixels, threw the capture away and
  // made the thumb take a fresh one — 29 captures in 30 frames of a thumb held
  // perfectly still.
  testWidgets('holding the thumb still does not re-capture the track', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _host(SizedBox(width: 300, child: _slider(value: 0.5))),
    );
    await tester.pumpAndSettle();
    final RenderBackdropLayer track = _track(tester);

    final int before = track.debugCaptureCount;
    final TestGesture gesture = await tester.startGesture(
      tester.getCenter(find.byType(DrawBackdrop)),
    );
    // The press grows the thumb, which then reads a wider strip than the one
    // held, so a capture or so while it grows is expected. Once it has, the
    // fill has not moved and the track has not changed.
    for (int i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    final int grown = track.debugCaptureCount;
    for (int i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(
      track.debugCaptureCount - grown,
      0,
      reason: 'the fill did not move, so the track did not change',
    );
    await gesture.up();
    await tester.pumpAndSettle();
    // The whole press, release included, used to cost 49.
    expect(track.debugCaptureCount - before, lessThanOrEqualTo(3));
  });

  testWidgets('dragging still re-captures as the fill moves', (
    WidgetTester tester,
  ) async {
    double value = 0.5;
    await tester.pumpWidget(
      _host(
        SizedBox(
          width: 300,
          child: StatefulBuilder(
            builder: (BuildContext context, StateSetter setState) => _slider(
              value: value,
              onChanged: (double v) => setState(() => value = v),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final RenderBackdropLayer track = _track(tester);
    final int before = track.debugCaptureCount;
    // The thumb's gesture layer takes the drag, above the glass it wraps.
    await tester.drag(
      find.byType(DrawBackdrop),
      const Offset(60, 0),
      warnIfMissed: false,
    );
    await tester.pumpAndSettle();
    expect(value, greaterThan(0.6));
    expect(track.debugCaptureCount, greaterThan(before));
  });

  // Regression: the thumb's travel was clamped to [-w/4, track - 3w/4], which
  // crosses itself on a track under half a thumb wide, and `clamp` throws.
  testWidgets('a track narrower than the thumb lays out', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _host(SizedBox(width: 10, child: _slider(value: 0.5))),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('a slider given no width falls back to a default track', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _host(
        Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[_slider(value: 0.5)],
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(tester.getSize(find.byType(LiquidSlider)).width, 200);
  });

  // Regression: an empty range made the progress 0/0, and NaN clamps to the
  // upper bound, so the thumb sat at the far end over a full track.
  testWidgets('an empty range sits at its start', (WidgetTester tester) async {
    await tester.pumpWidget(
      _host(
        SizedBox(
          width: 300,
          child: _slider(value: 3, range: (start: 3, end: 3)),
        ),
      ),
    );
    await tester.pump();
    expect(_thumbOffset(tester), closeTo(-_thumbWidth / 4, 0.5));
  });

  // Regression: the range was fixed when the slider was first built.
  testWidgets('a range that changes later is followed', (
    WidgetTester tester,
  ) async {
    Widget at(double value, double end) => _host(
      SizedBox(
        width: 300,
        child: _slider(value: value, range: (start: 0, end: end)),
      ),
    );
    await tester.pumpWidget(at(1, 1));
    await tester.pumpAndSettle();
    await tester.pumpWidget(at(1.5, 2));
    await tester.pumpAndSettle();
    // 1.5 of 2 is three quarters along: the thumb's centre sits there.
    expect(_thumbOffset(tester) + _thumbWidth / 2, closeTo(300 * 0.75, 1.0));
  });

  testWidgets('a reversed range can be dragged', (WidgetTester tester) async {
    await tester.pumpWidget(
      _host(
        SizedBox(
          width: 300,
          child: _slider(value: 0.5, range: (start: 1, end: 0)),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.drag(
      find.byType(DrawBackdrop),
      const Offset(40, 0),
      warnIfMissed: false,
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
