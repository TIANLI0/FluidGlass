import 'dart:async';

import 'package:fluid_glass/fluid_glass.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(
  Widget child, {
  bool reduce = false,
  bool dark = false,
  double scale = 1,
}) => MediaQuery(
  data: MediaQueryData(
    size: const Size(400, 800),
    disableAnimations: reduce,
    textScaler: TextScaler.linear(scale),
  ),
  child: Directionality(
    textDirection: TextDirection.ltr,
    child: SoftTheme(
      data: dark ? const SoftThemeData.dark() : const SoftThemeData.light(),
      child: DefaultTextStyle(
        style: const TextStyle(fontSize: 14, color: Color(0xFF000000)),
        child: Center(child: SizedBox(width: 400, height: 600, child: child)),
      ),
    ),
  ),
);

void main() {
  group('number and date wheels', () {
    testWidgets('external value and shorter ranges synchronize the wheel', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          SoftNumberPicker(
            value: 28,
            min: 1,
            max: 31,
            onChanged: (_) {},
            haptics: false,
          ),
        ),
      );
      await tester.pumpWidget(
        _host(
          SoftNumberPicker(
            value: 10,
            min: 1,
            max: 20,
            onChanged: (_) {},
            haptics: false,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester.getCenter(find.text('10')).dy,
        closeTo(tester.getCenter(find.byType(SoftNumberPicker)).dy, 0.1),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('dragging reports a valid new value; disabled wheels do not', (
      tester,
    ) async {
      final List<int> values = <int>[];
      await tester.pumpWidget(
        _host(
          Center(
            child: SizedBox(
              width: 90,
              child: SoftNumberPicker(
                value: 5,
                min: 1,
                max: 10,
                onChanged: values.add,
                haptics: false,
              ),
            ),
          ),
        ),
      );
      await tester.drag(find.byType(SoftNumberPicker), const Offset(0, -70));
      await tester.pumpAndSettle();
      expect(values, isNotEmpty);
      expect(values.every((int value) => value >= 1 && value <= 10), isTrue);
      values.clear();
      await tester.pumpWidget(
        _host(
          Center(
            child: SizedBox(
              width: 90,
              child: SoftNumberPicker(
                value: 5,
                min: 1,
                max: 10,
                enabled: false,
                onChanged: values.add,
                haptics: false,
              ),
            ),
          ),
        ),
      );
      await tester.drag(find.byType(SoftNumberPicker), const Offset(0, -70));
      await tester.pumpAndSettle();
      expect(values, isEmpty);
    });

    testWidgets('accessibility can wrap the wheel at its boundary', (
      tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      int? result;
      await tester.pumpWidget(
        _host(
          Center(
            child: SizedBox(
              width: 90,
              child: SoftNumberPicker(
                value: 1,
                min: 1,
                max: 3,
                wrapAround: true,
                onChanged: (int value) => result = value,
                haptics: false,
              ),
            ),
          ),
        ),
      );
      final SemanticsNode node = tester.getSemantics(
        find.byType(SoftNumberPicker),
      );
      node.owner!.performAction(node.id, SemanticsAction.decrease);
      await tester.pumpAndSettle();
      expect(result, 3);
      handle.dispose();
    });

    testWidgets('changing leap year clamps February 29 to February 28', (
      tester,
    ) async {
      DateTime? result;
      await tester.pumpWidget(
        _host(
          SoftDatePicker(
            value: DateTime(2024, 2, 29),
            onChanged: (DateTime value) => result = value,
            haptics: false,
          ),
        ),
      );
      tester
          .widget<SoftNumberPicker>(find.byType(SoftNumberPicker).at(0))
          .onChanged!(2025);
      expect(result, DateTime(2025, 2, 28));
      tester
          .widget<SoftNumberPicker>(find.byType(SoftNumberPicker).at(1))
          .onChanged!(4);
      expect(result, DateTime(2024, 4, 29));
    });

    testWidgets('changing January 31 to April does not overflow into May', (
      tester,
    ) async {
      DateTime? result;
      await tester.pumpWidget(
        _host(
          SoftDatePicker(
            value: DateTime(2025, 1, 31),
            onChanged: (DateTime value) => result = value,
            haptics: false,
          ),
        ),
      );
      tester
          .widget<SoftNumberPicker>(find.byType(SoftNumberPicker).at(1))
          .onChanged!(4);
      expect(result, DateTime(2025, 4, 30));
    });

    testWidgets('partial boundary years restrict month and day wheels', (
      tester,
    ) async {
      DateTime? result;
      await tester.pumpWidget(
        _host(
          SoftDatePicker(
            value: DateTime(2026, 3, 15),
            firstDate: DateTime(2020, 5, 10),
            lastDate: DateTime(2026, 3, 20),
            onChanged: (DateTime value) => result = value,
            haptics: false,
          ),
        ),
      );
      final List<SoftNumberPicker> wheels = tester
          .widgetList<SoftNumberPicker>(find.byType(SoftNumberPicker))
          .toList();
      expect(wheels[1].max, 3);
      expect(wheels[2].max, 20);
      wheels[1].onChanged!(12);
      expect(result, DateTime(2026, 3, 20));
      expect(
        () => SoftDatePicker(
          value: DateTime(2020),
          firstDate: DateTime(2022),
          lastDate: DateTime(2020),
          onChanged: (_) {},
        ),
        throwsArgumentError,
      );
    });
  });

  group('refresh', () {
    Widget list() => ListView(
      physics: const AlwaysScrollableScrollPhysics(
        parent: ClampingScrollPhysics(),
      ),
      children: const <Widget>[SizedBox(height: 900, child: Text('feed'))],
    );

    testWidgets('short pull cancels and long pull starts exactly one request', (
      tester,
    ) async {
      final GlobalKey<SoftPullToRefreshState> key =
          GlobalKey<SoftPullToRefreshState>();
      final Completer<void> loading = Completer<void>();
      int requests = 0;
      await tester.pumpWidget(
        _host(
          SoftPullToRefresh(
            key: key,
            triggerDistance: 40,
            onRefresh: () {
              requests++;
              return loading.future;
            },
            child: list(),
          ),
        ),
      );
      await tester.drag(find.byType(ListView), const Offset(0, 30));
      await tester.pumpAndSettle();
      expect(requests, 0);
      await tester.drag(find.byType(ListView), const Offset(0, 260));
      await tester.pump();
      for (int i = 0; i < 60; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(requests, 1);
      expect(key.currentState!.phase, SoftRefreshPhase.refreshing);
      final Future<void> pending = key.currentState!.show();
      expect(requests, 1);
      loading.complete();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();
      await pending;
      expect(key.currentState!.phase, SoftRefreshPhase.idle);
      expect(tester.binding.hasScheduledFrame, isFalse);
    });

    testWidgets(
      'the refresh ring stretches vertically and fades out in 200ms',
      (tester) async {
        final GlobalKey<SoftPullToRefreshState> key =
            GlobalKey<SoftPullToRefreshState>();
        final Completer<void> loading = Completer<void>();
        await tester.pumpWidget(
          _host(
            SoftPullToRefresh(
              key: key,
              triggerDistance: 40,
              onRefresh: () => loading.future,
              child: list(),
            ),
          ),
        );
        final TestGesture gesture = await tester.startGesture(
          tester.getCenter(find.byType(ListView)),
        );
        await gesture.moveBy(const Offset(0, 20));
        await gesture.moveBy(const Offset(0, 240));
        await tester.pump();
        expect(key.currentState!.phase, SoftRefreshPhase.armed);
        final Finder ring = find.byWidgetPredicate(
          (widget) => widget is CustomPaint && widget.size.width == 19,
        );
        expect(tester.getSize(ring).height, greaterThan(19));
        expect(
          tester.getTopLeft(find.text('Release to refresh')).dy,
          greaterThan(tester.getTopLeft(ring).dy + 19),
        );
        await gesture.up();
        for (int i = 0; i < 60; i++) {
          await tester.pump(const Duration(milliseconds: 16));
        }
        expect(key.currentState!.phase, SoftRefreshPhase.refreshing);
        loading.complete();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        expect(key.currentState!.phase, SoftRefreshPhase.complete);
        await tester.pump(const Duration(milliseconds: 110));
        expect(key.currentState!.phase, SoftRefreshPhase.idle);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('horizontal drags and cancelled pulls never refresh', (
      tester,
    ) async {
      int requests = 0;
      await tester.pumpWidget(
        _host(
          SoftPullToRefresh(
            triggerDistance: 40,
            onRefresh: () async {
              requests++;
            },
            child: list(),
          ),
        ),
      );
      await tester.drag(find.byType(ListView), const Offset(150, 0));
      final TestGesture gesture = await tester.startGesture(
        tester.getCenter(find.byType(ListView)),
      );
      await gesture.moveBy(const Offset(0, 250));
      await tester.pump();
      await gesture.cancel();
      await tester.pumpAndSettle();
      expect(requests, 0);
    });

    testWidgets('errors report once and reduced motion stops the spinner', (
      tester,
    ) async {
      final GlobalKey<SoftPullToRefreshState> key =
          GlobalKey<SoftPullToRefreshState>();
      int errors = 0;
      await tester.pumpWidget(
        _host(
          SoftPullToRefresh(
            key: key,
            onRefresh: () async => throw StateError('offline'),
            onError: (_, _) => errors++,
            child: list(),
          ),
          reduce: true,
        ),
      );
      final Future<void> refresh = key.currentState!.show();
      await tester.pump();
      await refresh;
      await tester.pumpAndSettle();
      expect(errors, 1);
      expect(key.currentState!.phase, SoftRefreshPhase.idle);
      expect(tester.binding.hasScheduledFrame, isFalse);
    });

    testWidgets('finishing a request after disposal is harmless', (
      tester,
    ) async {
      final Completer<void> loading = Completer<void>();
      final GlobalKey<SoftPullToRefreshState> key =
          GlobalKey<SoftPullToRefreshState>();
      await tester.pumpWidget(
        _host(
          SoftPullToRefresh(
            key: key,
            onRefresh: () => loading.future,
            child: list(),
          ),
        ),
      );
      final Future<void> refresh = key.currentState!.show();
      await tester.pumpWidget(_host(const SizedBox.shrink()));
      loading.complete();
      await refresh;
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });

  group('expandable groups', () {
    testWidgets('a capped list closes the oldest opened group', (tester) async {
      Set<int> opened = <int>{};
      await tester.pumpWidget(
        _host(
          StatefulBuilder(
            builder: (BuildContext context, StateSetter setState) =>
                SoftExpandableList(
                  groupCount: 3,
                  childCount: (_) => 1,
                  expandedGroups: opened,
                  maxExpandedGroups: 1,
                  onExpandedGroupsChanged: (Set<int> value) =>
                      setState(() => opened = value),
                  headerBuilder: (_, int group, _) =>
                      SizedBox(height: 48, child: Text('group $group')),
                  childBuilder: (_, int group, _) =>
                      SizedBox(height: 48, child: Text('child $group')),
                ),
          ),
        ),
      );
      await tester.tap(find.text('group 2'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('group 0'));
      await tester.pumpAndSettle();
      expect(opened, <int>{0});
      expect(find.text('child 0'), findsOneWidget);
      expect(find.text('child 2'), findsNothing);
    });

    testWidgets(
      'rapid reversal settles and collapsed children cannot activate',
      (tester) async {
        bool expanded = false;
        int taps = 0;
        await tester.pumpWidget(
          _host(
            StatefulBuilder(
              builder: (_, StateSetter setState) => SoftExpandableGroup(
                expanded: expanded,
                onToggle: () => setState(() => expanded = !expanded),
                headerBuilder: (_, _) =>
                    const SizedBox(height: 48, child: Text('toggle')),
                children: <Widget>[
                  SoftTextButton(text: 'action', onPressed: () => taps++),
                ],
              ),
            ),
          ),
        );
        await tester.tap(find.text('toggle'));
        await tester.pump(const Duration(milliseconds: 80));
        await tester.tap(find.text('toggle'));
        await tester.pumpAndSettle();
        expect(find.text('action'), findsNothing);
        expect(taps, 0);
        expect(tester.binding.hasScheduledFrame, isFalse);
      },
    );
  });

  group('notification actions', () {
    Widget card({
      required bool open,
      required ValueChanged<bool> changed,
      required VoidCallback dismiss,
      VoidCallback? settings,
      bool enabled = true,
    }) => SoftNotificationSwipeBox(
      revealed: open,
      onRevealedChanged: changed,
      onDismiss: dismiss,
      onSettings: settings,
      enabled: enabled,
      settingsIcon: const Text('S'),
      dismissIcon: const Text('D'),
      settingsLabel: 'settings',
      dismissLabel: 'delete',
      child: const Padding(
        padding: EdgeInsets.all(20),
        child: Text('notification'),
      ),
    );

    testWidgets('left swipe reveals; only the delete action dismisses', (
      tester,
    ) async {
      bool open = false;
      int dismissed = 0;
      await tester.pumpWidget(
        _host(
          Center(
            child: StatefulBuilder(
              builder: (_, StateSetter setState) => card(
                open: open,
                changed: (bool value) => setState(() => open = value),
                dismiss: () => dismissed++,
              ),
            ),
          ),
        ),
      );
      await tester.drag(find.text('notification'), const Offset(-180, 0));
      await tester.pumpAndSettle();
      expect(open, isTrue);
      expect(dismissed, 0);
      await tester.tap(find.text('D'));
      await tester.pumpAndSettle();
      expect(dismissed, 1);
      expect(open, isFalse);
    });

    testWidgets('vertical scroll and a disabled notification never reveal', (
      tester,
    ) async {
      final List<bool> requests = <bool>[];
      await tester.pumpWidget(
        _host(
          Center(
            child: card(open: false, changed: requests.add, dismiss: () {}),
          ),
        ),
      );
      await tester.drag(find.text('notification'), const Offset(0, 150));
      await tester.pumpAndSettle();
      expect(requests, isEmpty);
      await tester.pumpWidget(
        _host(
          Center(
            child: card(
              open: false,
              enabled: false,
              changed: requests.add,
              dismiss: () {},
            ),
          ),
        ),
      );
      await tester.drag(find.text('notification'), const Offset(-180, 0));
      await tester.pumpAndSettle();
      expect(requests, isEmpty);
    });

    testWidgets('rich card action and close do not activate its body', (
      tester,
    ) async {
      int body = 0, action = 0, close = 0;
      await tester.pumpWidget(
        _host(
          Center(
            child: SoftNotificationSnackBar(
              title: 'new message',
              message: 'a long notification body',
              actionLabel: 'reply',
              onAction: () => action++,
              onClose: () => close++,
              onPressed: () => body++,
            ),
          ),
          scale: 2,
        ),
      );
      await tester.tap(find.text('reply'));
      await tester.tap(
        find.byWidgetPredicate(
          (widget) =>
              widget is SoftGlyphIcon && widget.glyph == SoftGlyph.close,
        ),
      );
      expect(action, 1);
      expect(close, 1);
      expect(body, 0);
      expect(tester.takeException(), isNull);
    });
  });

  group('menus', () {
    testWidgets(
      'selection actions support keyboard and accessibility without double activation',
      (tester) async {
        final SemanticsHandle handle = tester.ensureSemantics();
        int taps = 0;
        await tester.pumpWidget(
          _host(
            SoftTextSelectionMenu(
              anchors: const TextSelectionToolbarAnchors(
                primaryAnchor: Offset(200, 200),
              ),
              actions: <SoftTextSelectionAction>[
                SoftTextSelectionAction(label: 'copy', onPressed: () => taps++),
              ],
            ),
          ),
        );
        await tester.pumpAndSettle();
        Focus.of(tester.element(find.text('copy'))).requestFocus();
        await tester.pump();
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        expect(taps, 1);
        final SemanticsNode node = tester.getSemantics(find.text('copy'));
        node.owner!.performAction(node.id, SemanticsAction.tap);
        expect(taps, 2);
        handle.dispose();
      },
    );
    testWidgets('horizontal grid wraps and disables individual actions', (
      tester,
    ) async {
      int taps = 0;
      await tester.pumpWidget(
        _host(
          Center(
            child: SoftHorizontalPopupMenu(
              items: <SoftHorizontalMenuItem>[
                for (int i = 0; i < 7; i++)
                  SoftHorizontalMenuItem(
                    icon: const SizedBox.square(dimension: 20),
                    label: 'item $i',
                    enabled: i != 1,
                    onPressed: () => taps++,
                  ),
              ],
            ),
          ),
          scale: 2,
        ),
      );
      await tester.tapAt(tester.getCenter(find.text('item 1')));
      expect(taps, 0);
      await tester.tap(find.text('item 0'));
      expect(taps, 1);
      expect(
        tester.getTopLeft(find.text('item 3')).dy,
        greaterThan(tester.getTopLeft(find.text('item 0')).dy),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('selection menu stays on screen beside an edge anchor', (
      tester,
    ) async {
      int taps = 0;
      await tester.pumpWidget(
        _host(
          SoftTextSelectionMenu(
            anchors: const TextSelectionToolbarAnchors(
              primaryAnchor: Offset(2, 30),
              secondaryAnchor: Offset(2, 60),
            ),
            actions: <SoftTextSelectionAction>[
              SoftTextSelectionAction(label: 'copy', onPressed: () => taps++),
              const SoftTextSelectionAction(label: 'disabled', onPressed: null),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('copy'));
      expect(taps, 1);
      await tester.tapAt(tester.getCenter(find.text('disabled')));
      expect(taps, 1);
      expect(tester.takeException(), isNull);
    });
  });
}
