import 'package:fluid_glass/fluid_glass.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

const List<SoftFloatingNavigationItem> _items = <SoftFloatingNavigationItem>[
  SoftFloatingNavigationItem(icon: SizedBox.square(dimension: 24), label: 'A'),
  SoftFloatingNavigationItem(icon: SizedBox.square(dimension: 24), label: 'B'),
  SoftFloatingNavigationItem(icon: SizedBox.square(dimension: 24), label: 'C'),
];

Future<void> _settle(WidgetTester tester) async {
  for (int i = 0; i < 90; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

/// A bar over a tappable page, at the bottom of a 400 × 800 screen.
Widget _host({
  required int selected,
  required ValueChanged<int> onSelected,
  List<SoftFloatingNavigationItem> items = _items,
  double inset = 0,
  double width = 400,
  bool dispatchWhenAlreadySelected = false,
  bool visible = true,
  SoftFloatingAccessory? expansion,
  VoidCallback? onPage,
}) {
  return MediaQuery(
    data: MediaQueryData(
      size: Size(width, 800),
      viewPadding: EdgeInsets.only(bottom: inset),
      padding: EdgeInsets.only(bottom: inset),
    ),
    child: Directionality(
      textDirection: TextDirection.ltr,
      child: SoftTheme(
        data: SoftThemeData.light(),
        child: Stack(
          children: <Widget>[
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onPage,
              ),
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: SoftFloatingNavigationBar(
                items: items,
                selectedIndex: selected,
                onSelected: onSelected,
                dispatchWhenAlreadySelected: dispatchWhenAlreadySelected,
                visible: visible,
                expansion: expansion,
                scrimColor: const Color(0xFFFAFAFA),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

Future<void> _pump(
  WidgetTester tester,
  Widget widget, {
  double width = 400,
}) async {
  tester.view.physicalSize = Size(width, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(widget);
}

Finder _capsule() => find.descendant(
  of: find.byType(SoftFloatingNavigationBar),
  matching: find.byType(SoftTouchMotion),
);

void main() {
  testWidgets('a tap beside the capsule reaches the page under the bar', (
    tester,
  ) async {
    int page = 0;
    final List<int> taps = <int>[];
    await _pump(
      tester,
      _host(selected: 0, onSelected: taps.add, onPage: () => page++),
    );
    final Rect capsule = tester.getRect(_capsule().first);
    await tester.tapAt(Offset(capsule.left - 10, capsule.center.dy));
    await tester.pump();
    expect(page, 1);
    expect(taps, isEmpty);
  });

  testWidgets('a press that wanders inside its item still clicks it', (
    tester,
  ) async {
    final List<int> taps = <int>[];
    await _pump(tester, _host(selected: 0, onSelected: taps.add));
    final Offset c = tester.getCenter(find.text('C'));
    final TestGesture g = await tester.startGesture(c + const Offset(-25, 0));
    // Further than a tap's slop, but inside the cell.
    await g.moveTo(c + const Offset(25, 4));
    await tester.pump();
    await g.up();
    await tester.pump();
    expect(taps, <int>[2]);
  });

  testWidgets('a tap on the selected item is reported only when asked', (
    tester,
  ) async {
    final List<int> taps = <int>[];
    await _pump(tester, _host(selected: 1, onSelected: taps.add));
    await tester.tap(find.text('B'));
    await tester.pump();
    expect(taps, isEmpty);

    await _pump(
      tester,
      _host(
        selected: 1,
        onSelected: taps.add,
        dispatchWhenAlreadySelected: true,
      ),
    );
    await tester.tap(find.text('B'));
    await tester.pump();
    expect(taps, <int>[1]);
  });

  testWidgets('sliding away and back reports the item it started on', (
    tester,
  ) async {
    final List<int> taps = <int>[];
    await _pump(tester, _host(selected: 0, onSelected: taps.add));
    final Offset a = tester.getCenter(find.text('A'));
    final Offset b = tester.getCenter(find.text('B'));
    final TestGesture g = await tester.startGesture(a);
    await g.moveTo(b);
    await tester.pump();
    await g.moveTo(a);
    await tester.pump();
    await g.up();
    await tester.pump();
    expect(taps, <int>[0]);
  });

  testWidgets('a cancelled slide still goes where it slid to', (tester) async {
    final List<int> taps = <int>[];
    await _pump(tester, _host(selected: 0, onSelected: taps.add));
    final TestGesture g = await tester.startGesture(
      tester.getCenter(find.text('A')),
    );
    await g.moveTo(tester.getCenter(find.text('C')));
    await tester.pump();
    await g.cancel();
    await tester.pump();
    expect(taps, <int>[2]);
  });

  testWidgets('a second finger leaves no stale selection behind', (
    tester,
  ) async {
    final List<int> taps = <int>[];
    await _pump(tester, _host(selected: 0, onSelected: taps.add));
    final TestGesture first = await tester.startGesture(
      tester.getCenter(find.text('A')),
    );
    final TestGesture second = await tester.startGesture(
      tester.getCenter(find.text('B')),
    );
    await second.up();
    await tester.pump();
    await first.moveTo(tester.getCenter(find.text('B')));
    await tester.pump();
    await first.up();
    await tester.pump();
    expect(taps, <int>[1]);
  });

  testWidgets('a long press opens its menu and selects nothing', (
    tester,
  ) async {
    final List<int> taps = <int>[];
    int menus = 0;
    await _pump(
      tester,
      _host(
        selected: 0,
        onSelected: taps.add,
        items: <SoftFloatingNavigationItem>[
          _items[0],
          SoftFloatingNavigationItem(
            icon: const SizedBox.square(dimension: 24),
            label: 'B',
            onLongPress: () => menus++,
          ),
        ],
      ),
    );
    await tester.longPress(find.text('B'));
    await tester.pump();
    expect(menus, 1);
    expect(taps, isEmpty);
  });

  testWidgets('a disabled item hides its badge and takes no taps', (
    tester,
  ) async {
    final List<int> taps = <int>[];
    await _pump(
      tester,
      _host(
        selected: 0,
        onSelected: taps.add,
        items: const <SoftFloatingNavigationItem>[
          SoftFloatingNavigationItem(
            icon: SizedBox.square(dimension: 24),
            label: 'A',
            badge: 3,
          ),
          SoftFloatingNavigationItem(
            icon: SizedBox.square(dimension: 24),
            label: 'B',
            badge: 3,
            enabled: false,
          ),
        ],
      ),
    );
    expect(find.byType(SoftBadge), findsOneWidget);
    await tester.tap(find.text('B'));
    await tester.pump();
    expect(taps, isEmpty);
  });

  group('position and size', () {
    for (final (double inset, double gap) in <(double, double)>[
      (0, 24),
      (4, 16),
      (24, 32),
      (48, 56),
    ]) {
      testWidgets('inset $inset: the capsule sits $gap above the screen edge', (
        tester,
      ) async {
        await _pump(
          tester,
          _host(selected: 0, onSelected: (_) {}, inset: inset),
        );
        final Rect capsule = tester.getRect(_capsule().first);
        expect(capsule.height, 56);
        expect(800 - capsule.bottom, gap);
        final Rect bar = tester.getRect(find.byType(SoftFloatingNavigationBar));
        // 16 above the capsule, and the bar is as tall as a page reserves.
        expect(capsule.top - bar.top, 16);
        late double extent;
        await tester.pumpWidget(
          MediaQuery(
            data: MediaQueryData(
              size: const Size(400, 800),
              viewPadding: EdgeInsets.only(bottom: inset),
            ),
            child: Builder(
              builder: (BuildContext context) {
                extent = SoftFloatingNavigationBarDefaults.extent(context);
                return const SizedBox();
              },
            ),
          ),
        );
        expect(extent, bar.height);
      });
    }

    testWidgets('three items: 70 each, 12 at the ends, 8 between, centred', (
      tester,
    ) async {
      await _pump(tester, _host(selected: 0, onSelected: (_) {}));
      final Rect capsule = tester.getRect(_capsule().first);
      expect(capsule.width, 3 * 70 + 24 + 16);
      expect(capsule.center.dx, 200);
    });

    testWidgets('from 600 wide the capsule fills the bar', (tester) async {
      await _pump(
        tester,
        _host(selected: 0, onSelected: (_) {}, width: 800),
        width: 800,
      );
      final Rect capsule = tester.getRect(_capsule().first);
      expect(capsule.width, 800);
    });
  });

  testWidgets('hiding fades and shrinks the capsule, and it takes no taps', (
    tester,
  ) async {
    final List<int> taps = <int>[];
    await _pump(tester, _host(selected: 0, onSelected: taps.add));
    await _pump(
      tester,
      _host(selected: 0, onSelected: taps.add, visible: false),
    );
    await tester.pump(const Duration(milliseconds: 50));
    final Opacity fading = tester.widget<Opacity>(
      find.ancestor(of: _capsule().first, matching: find.byType(Opacity)).first,
    );
    expect(fading.opacity, inExclusiveRange(0, 1));
    await _settle(tester);
    await tester.tap(find.text('B'), warnIfMissed: false);
    await tester.pump();
    expect(taps, isEmpty);

    await _pump(tester, _host(selected: 0, onSelected: taps.add));
    await _settle(tester);
    await tester.tap(find.text('B'));
    await tester.pump();
    expect(taps, <int>[1]);
    expect(tester.takeException(), isNull);
  });

  testWidgets('an expansion moves the capsule to the start edge and back', (
    tester,
  ) async {
    int actions = 0;
    SoftFloatingAccessory fab(bool visible) => SoftFloatingAccessory(
      icon: const SizedBox.square(dimension: 24),
      onTap: () => actions++,
      visible: visible,
    );
    await _pump(
      tester,
      _host(selected: 0, onSelected: (_) {}, expansion: fab(false)),
    );
    expect(tester.getRect(_capsule().first).center.dx, 200);

    await _pump(
      tester,
      _host(selected: 0, onSelected: (_) {}, expansion: fab(true)),
    );
    await tester.pump(const Duration(milliseconds: 80));
    final double moving = tester.getRect(_capsule().first).left;
    expect(moving, inExclusiveRange(16, 200 - 125));
    await _settle(tester);
    expect(tester.getRect(_capsule().first).left, 16);
    await tester.tapAt(const Offset(400 - 16 - 28, 800 - 24 - 28));
    await tester.pump();
    expect(actions, 1);

    await _pump(
      tester,
      _host(selected: 0, onSelected: (_) {}, expansion: fab(false)),
    );
    await _settle(tester);
    expect(tester.getRect(_capsule().first).center.dx, 200);
    expect(tester.takeException(), isNull);
  });

  testWidgets('items read as tabs', (tester) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    await _pump(tester, _host(selected: 1, onSelected: (_) {}));
    expect(
      tester.getSemantics(find.text('B')),
      matchesSemantics(
        label: 'B',
        isButton: true,
        isSelected: true,
        hasSelectedState: true,
        isEnabled: true,
        hasEnabledState: true,
        isInMutuallyExclusiveGroup: true,
        hasTapAction: true,
      ),
    );
    handle.dispose();
  });
}
