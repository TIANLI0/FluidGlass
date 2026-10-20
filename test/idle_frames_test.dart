import 'package:fluid_glass/fluid_glass.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Pumps frames for as long as the app keeps asking for them, up to [limit].
///
/// Returns how many it took, so a failure can say how far past settled the
/// component went.
Future<int> _framesUntilIdle(WidgetTester tester, {int limit = 300}) async {
  int frames = 0;
  while (tester.binding.hasScheduledFrame && frames < limit) {
    await tester.pump(const Duration(milliseconds: 16));
    frames++;
  }
  return frames;
}

Widget _host(Widget child) {
  return MaterialApp(
    home: Scaffold(body: Center(child: child)),
  );
}

void main() {
  // A static screen costs no frames. Every component has to come to rest
  // after an interaction, and must not keep asking for frames once it has.
  group('a settled component asks for no frames', () {
    final Map<String, Widget Function()> components =
        <String, Widget Function()>{
          'LiquidButton': () => LiquidButton(
            onPressed: () {},
            backdrop: emptyBackdrop,
            children: const <Widget>[Text('Go')],
          ),
          'LiquidToggle': () => const _Toggle(),
          'LiquidSegmentedControl': () => SizedBox(
            width: 300,
            child: LiquidSegmentedControl(
              selectedIndex: 0,
              onSelected: (_) {},
              backdrop: emptyBackdrop,
              segments: const <Widget>[Text('A'), Text('B'), Text('C')],
            ),
          ),
        };
    for (final MapEntry<String, Widget Function()> entry
        in components.entries) {
      testWidgets(entry.key, (WidgetTester tester) async {
        await tester.pumpWidget(_host(entry.value()));
        await _framesUntilIdle(tester);
        expect(tester.binding.hasScheduledFrame, isFalse, reason: 'at rest');

        await tester.tap(find.byType(Center).last, warnIfMissed: false);
        final int frames = await _framesUntilIdle(tester);
        expect(
          tester.binding.hasScheduledFrame,
          isFalse,
          reason: 'still asking for frames $frames frames after a tap',
        );
        expect(tester.binding.transientCallbackCount, 0);
      });
    }
  });

  // Regression: the release waited for the value by re-arming a post-frame
  // callback and scheduling a frame, until the value arrived. Under a muted
  // ticker — any route covered by an opaque one — the value never moves, so a
  // setting changed on a covered page kept the app drawing every frame until
  // the page came back.
  group('a value changed under a muted ticker asks for no frames', () {
    Widget muted(ValueNotifier<int> value, Widget Function(int) build) {
      return _host(
        TickerMode(
          enabled: false,
          child: ValueListenableBuilder<int>(
            valueListenable: value,
            builder: (BuildContext context, int v, Widget? _) => build(v),
          ),
        ),
      );
    }

    final Map<String, Widget Function(int)> components =
        <String, Widget Function(int)>{
          'LiquidToggle': (int v) => LiquidToggle(
            selected: v == 1,
            onSelect: (_) {},
            backdrop: emptyBackdrop,
          ),
          'LiquidSegmentedControl': (int v) => SizedBox(
            width: 300,
            child: LiquidSegmentedControl(
              selectedIndex: v,
              onSelected: (_) {},
              backdrop: emptyBackdrop,
              segments: const <Widget>[Text('A'), Text('B'), Text('C')],
            ),
          ),
        };
    for (final MapEntry<String, Widget Function(int)> entry
        in components.entries) {
      testWidgets(entry.key, (WidgetTester tester) async {
        final ValueNotifier<int> value = ValueNotifier<int>(0);
        addTearDown(value.dispose);
        await tester.pumpWidget(muted(value, entry.value));
        await _framesUntilIdle(tester);

        value.value = 1;
        final int frames = await _framesUntilIdle(tester);
        expect(
          frames,
          lessThan(5),
          reason: 'a muted ticker cannot settle, so nothing may wait on it',
        );
        expect(tester.binding.hasScheduledFrame, isFalse);
      });
    }
  });

  // The other half: once the ticker is unmuted, the press that the change
  // started still releases.
  testWidgets('the release still lands once the ticker is unmuted', (
    WidgetTester tester,
  ) async {
    final ValueNotifier<bool> enabled = ValueNotifier<bool>(false);
    final ValueNotifier<bool> selected = ValueNotifier<bool>(false);
    addTearDown(enabled.dispose);
    addTearDown(selected.dispose);
    await tester.pumpWidget(
      _host(
        ValueListenableBuilder<bool>(
          valueListenable: enabled,
          builder: (BuildContext context, bool on, Widget? _) => TickerMode(
            enabled: on,
            child: ValueListenableBuilder<bool>(
              valueListenable: selected,
              builder: (BuildContext context, bool s, Widget? _) =>
                  LiquidToggle(
                    selected: s,
                    onSelect: (_) {},
                    backdrop: emptyBackdrop,
                  ),
            ),
          ),
        ),
      ),
    );
    await _framesUntilIdle(tester);
    selected.value = true;
    await _framesUntilIdle(tester);

    enabled.value = true;
    final int frames = await _framesUntilIdle(tester);
    expect(tester.binding.hasScheduledFrame, isFalse, reason: '$frames');
    expect(tester.binding.transientCallbackCount, 0);
  });
}

class _Toggle extends StatefulWidget {
  const _Toggle();

  @override
  State<_Toggle> createState() => _ToggleState();
}

class _ToggleState extends State<_Toggle> {
  bool _selected = false;

  @override
  Widget build(BuildContext context) {
    return LiquidToggle(
      selected: _selected,
      onSelect: (bool value) => setState(() => _selected = value),
      backdrop: emptyBackdrop,
    );
  }
}
