import 'package:fluid_glass/fluid_glass.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

const List<SoftFloatingNavigationItem> _items = <SoftFloatingNavigationItem>[
  SoftFloatingNavigationItem(icon: SizedBox.square(dimension: 24), label: 'A'),
  SoftFloatingNavigationItem(icon: SizedBox.square(dimension: 24), label: 'B'),
  SoftFloatingNavigationItem(icon: SizedBox.square(dimension: 24), label: 'C'),
];

/// Tab 0 has no view, tab 1 shares, tab 2 adds.
Widget _host(
  int tab, {
  bool reduceMotion = false,
  ValueChanged<String>? onTap,
}) {
  final bool share = tab != 2;
  final String id = share ? 'share' : 'add';
  return MediaQuery(
    data: MediaQueryData(
      size: const Size(400, 800),
      disableAnimations: reduceMotion,
    ),
    child: Directionality(
      textDirection: TextDirection.ltr,
      child: SoftTheme(
        data: SoftThemeData.light(),
        child: Align(
          alignment: Alignment.bottomCenter,
          child: SoftFloatingNavigationBar(
            items: _items,
            selectedIndex: tab,
            onSelected: (_) {},
            expansion: SoftFloatingAccessory(
              id: id,
              icon: SizedBox.square(key: ValueKey<String>(id), dimension: 24),
              semanticLabel: id,
              visible: tab != 0,
              onTap: () => onTap?.call(id),
            ),
          ),
        ),
      ),
    ),
  );
}

Future<void> _pump(WidgetTester tester, Widget widget) async {
  tester.view.physicalSize = const Size(400, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(widget);
}

Future<void> _frames(WidgetTester tester, int n) async {
  for (int i = 0; i < n; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

/// The opacity an icon is drawn at, through the swap's own [Opacity].
double _opacity(WidgetTester tester, String id) {
  final Finder icon = find.byKey(ValueKey<String>(id));
  if (icon.evaluate().isEmpty) return 0;
  final Opacity o = tester.widget(
    find.ancestor(of: icon, matching: find.byType(Opacity)).first,
  );
  return o.opacity;
}

void main() {
  testWidgets('a new id while out changes the icon in place', (tester) async {
    await _pump(tester, _host(1));
    final Rect ball = tester.getRect(find.bySemanticsLabel('share'));
    await _pump(tester, _host(2));
    await _frames(tester, 3);
    // Both icons drawn, crossing; the view did not go back in.
    expect(_opacity(tester, 'share'), inExclusiveRange(0, 1));
    expect(_opacity(tester, 'add'), inExclusiveRange(0, 1));
    expect(tester.getRect(find.bySemanticsLabel('add')), ball);
    final SoftMetaBallSurface surface = tester.widget(
      find.byType(SoftMetaBallSurface),
    );
    expect(
      surface.particles[1].size,
      const Size.square(56),
      reason: 'no melt: the round view stays out at full size',
    );

    await _frames(tester, 60);
    expect(find.byKey(const ValueKey<String>('share')), findsNothing);
    expect(_opacity(tester, 'add'), 1);
    expect(tester.hasRunningAnimations, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the tap and the label switch at once', (tester) async {
    final List<String> taps = <String>[];
    await _pump(tester, _host(1, onTap: taps.add));
    await _pump(tester, _host(2, onTap: taps.add));
    await tester.pump(const Duration(milliseconds: 16));
    expect(find.bySemanticsLabel('add'), findsOneWidget);
    expect(find.bySemanticsLabel('share'), findsNothing);
    await tester.tap(find.bySemanticsLabel('add'));
    await tester.pump();
    expect(taps, <String>['add']);
  });

  testWidgets('switching back mid-change turns round where it is', (
    tester,
  ) async {
    await _pump(tester, _host(1));
    await _pump(tester, _host(2));
    await _frames(tester, 4);
    final double share = _opacity(tester, 'share');
    final double add = _opacity(tester, 'add');
    await _pump(tester, _host(1));
    final double shareAfter = _opacity(tester, 'share');
    final double addAfter = _opacity(tester, 'add');
    expect(shareAfter, closeTo(share, 1e-6));
    expect(addAfter, closeTo(add, 1e-6));
    await _frames(tester, 60);
    expect(find.byKey(const ValueKey<String>('add')), findsNothing);
    expect(_opacity(tester, 'share'), 1);
  });

  testWidgets('a new icon while melting back in grows over the old', (
    tester,
  ) async {
    await _pump(tester, _host(2));
    await _pump(tester, _host(0));
    await _frames(tester, 3);
    // Going in keeps the icon it leaves with.
    expect(_opacity(tester, 'add'), 1);
    await _pump(tester, _host(1));
    await tester.pump(const Duration(milliseconds: 16));
    expect(_opacity(tester, 'add'), inExclusiveRange(0, 1));
    expect(_opacity(tester, 'share'), inExclusiveRange(0, 1));
    await _frames(tester, 90);
    expect(_opacity(tester, 'share'), 1);
    expect(find.byKey(const ValueKey<String>('add')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('out from fully in shows the new icon alone', (tester) async {
    await _pump(tester, _host(2));
    await _pump(tester, _host(0));
    await _frames(tester, 90);
    await _pump(tester, _host(1));
    for (int i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 16));
      expect(find.byKey(const ValueKey<String>('add')), findsNothing);
    }
    expect(_opacity(tester, 'share'), 1);
  });

  testWidgets('with reduced motion the icon is replaced', (tester) async {
    await _pump(tester, _host(1, reduceMotion: true));
    await _pump(tester, _host(2, reduceMotion: true));
    await tester.pump();
    expect(find.byKey(const ValueKey<String>('share')), findsNothing);
    expect(_opacity(tester, 'add'), 1);
    expect(tester.hasRunningAnimations, isFalse);
  });
}
