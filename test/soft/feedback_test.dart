import 'package:fluid_glass/fluid_glass.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'surface.dart';

Widget _host(Widget child, {bool dark = false}) {
  final SoftThemeData theme = dark
      ? const SoftThemeData.dark()
      : const SoftThemeData.light();
  return MediaQuery(
    data: const MediaQueryData(size: Size(400, 800)),
    child: Directionality(
      textDirection: TextDirection.ltr,
      child: TapRegionSurface(
        child: SoftTheme(
          data: theme,
          child: DefaultTextStyle(
            style: theme.textStyles.body1.copyWith(
              color: theme.colors.onBackground,
            ),
            child: _HostOverlay(
              child: ColoredBox(color: theme.colors.surface, child: child),
            ),
          ),
        ),
      ),
    ),
  );
}

/// An overlay whose one entry follows [child]: an [Overlay] reads its
/// initial entries once, so pumping a new host would otherwise leave the
/// old content mounted.
class _HostOverlay extends StatefulWidget {
  const _HostOverlay({required this.child});

  final Widget child;

  @override
  State<_HostOverlay> createState() => _HostOverlayState();
}

class _HostOverlayState extends State<_HostOverlay> {
  late final OverlayEntry _entry = OverlayEntry(
    builder: (BuildContext context) => widget.child,
  );

  @override
  void didUpdateWidget(_HostOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    _entry.markNeedsBuild();
  }

  @override
  void dispose() {
    _entry
      ..remove()
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      Overlay(initialEntries: <OverlayEntry>[_entry]);
}

/// Pumps [frames] frames of 16 ms.
Future<void> _frames(WidgetTester tester, int frames) async {
  for (int i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

void main() {
  usePhoneSurface();

  group('SoftSnackbar', () {
    for (final bool dark in <bool>[false, true]) {
      testWidgets('shows, stacks and settles (dark: $dark)', (
        WidgetTester tester,
      ) async {
        final SoftSnackbarHostState state = SoftSnackbarHostState();
        addTearDown(state.dispose);
        await tester.pumpWidget(
          _host(SoftSnackbarHost(state: state), dark: dark),
        );
        state.showSnackbar(message: 'first');
        await tester.pump();
        await _frames(tester, 40);
        expect(find.text('first'), findsOneWidget);
        expect(tester.binding.hasScheduledFrame, isFalse);

        // The snackbar wraps its content, centred, 32 above the bottom.
        final Rect first = tester.getRect(find.byType(SoftSnackbar));
        expect(first.center.dx, closeTo(200, 0.5));
        expect(first.bottom, closeTo(800 - 28, 0.5));

        state.showSnackbar(message: 'second');
        await tester.pump();
        await _frames(tester, 60);
        expect(tester.binding.hasScheduledFrame, isFalse);
        final Rect older = tester.getRect(find.text('first'));
        final Rect newer = tester.getRect(find.text('second'));
        expect(newer.top, greaterThan(older.bottom));
        expect(state.newestSnackbarData!.visuals.message, 'second');
        expect(state.oldestSnackbarData!.visuals.message, 'first');

        state.oldestSnackbarData!.dismiss();
        await tester.pump();
        await _frames(tester, 60);
        expect(find.text('first'), findsNothing);
        expect(state.snackbars, hasLength(1));
        expect(tester.binding.hasScheduledFrame, isFalse);
        state.newestSnackbarData!.dismiss();
        await _frames(tester, 60);
        expect(find.byType(SoftSnackbar), findsNothing);
      });
    }

    testWidgets('times out, reports the action and swipes away', (
      WidgetTester tester,
    ) async {
      final SoftSnackbarHostState state = SoftSnackbarHostState();
      addTearDown(state.dispose);
      await tester.pumpWidget(_host(SoftSnackbarHost(state: state)));

      SoftSnackbarResult? timed;
      state
          .showSnackbar(
            message: 'short',
            duration: const SoftSnackbarDuration.custom(Duration(seconds: 2)),
          )
          .then((SoftSnackbarResult r) => timed = r);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1900));
      expect(timed, isNull);
      await tester.pump(const Duration(milliseconds: 200));
      expect(timed, SoftSnackbarResult.dismissed);
      await _frames(tester, 40);
      expect(find.text('short'), findsNothing);

      SoftSnackbarResult? acted;
      state
          .showSnackbar(message: 'with action', actionLabel: 'Undo')
          .then((SoftSnackbarResult r) => acted = r);
      await tester.pump();
      await _frames(tester, 30);
      await tester.tap(find.text('Undo'));
      await tester.pump();
      expect(acted, SoftSnackbarResult.actionPerformed);
      await _frames(tester, 40);
      expect(find.text('with action'), findsNothing);

      SoftSnackbarResult? swiped;
      state
          .showSnackbar(
            message: 'swipe me',
            duration: SoftSnackbarDuration.indefinite,
          )
          .then((SoftSnackbarResult r) => swiped = r);
      await tester.pump();
      await _frames(tester, 30);
      // A short drag springs back.
      await tester.drag(find.text('swipe me'), const Offset(40, 0));
      await _frames(tester, 40);
      expect(swiped, isNull);
      expect(tester.binding.hasScheduledFrame, isFalse);
      // Past half the width (slowly, no fling) throws it off.
      final TestGesture gesture = await tester.startGesture(
        tester.getCenter(find.text('swipe me')),
      );
      for (int i = 0; i < 30; i++) {
        await gesture.moveBy(const Offset(10, 0));
        await tester.pump(const Duration(milliseconds: 100));
      }
      await gesture.up();
      await _frames(tester, 60);
      expect(swiped, SoftSnackbarResult.dismissed);
      expect(find.text('swipe me'), findsNothing);
      expect(tester.binding.hasScheduledFrame, isFalse);
    });

    testWidgets('the dismiss glyph closes it; a wrapped message rounds 16', (
      WidgetTester tester,
    ) async {
      final SoftSnackbarHostState state = SoftSnackbarHostState();
      addTearDown(state.dispose);
      await tester.pumpWidget(_host(SoftSnackbarHost(state: state)));
      SoftSnackbarResult? result;
      state
          .showSnackbar(
            message:
                'A long message that needs to wrap onto a second line '
                'because it does not fit the snackbar width at all',
            withDismissAction: true,
            duration: SoftSnackbarDuration.indefinite,
          )
          .then((SoftSnackbarResult r) => result = r);
      await tester.pump();
      await _frames(tester, 30);
      final Rect box = tester.getRect(find.byType(SoftSnackbar));
      expect(box.width, closeTo(400, 0.5));
      expect(box.height, greaterThan(60));
      final Finder glyph = find.descendant(
        of: find.byType(SoftSnackbar),
        matching: find.byType(SoftPressable),
      );
      await tester.tap(glyph);
      await tester.pump();
      expect(result, SoftSnackbarResult.dismissed);
      await _frames(tester, 40);
      expect(find.byType(SoftSnackbar), findsNothing);
    });

    testWidgets(
      'showSoftSnackbar uses an overlay host that lets taps through',
      (WidgetTester tester) async {
        int taps = 0;
        late BuildContext context;
        await tester.pumpWidget(
          _host(
            Builder(
              builder: (BuildContext c) {
                context = c;
                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => taps++,
                );
              },
            ),
          ),
        );
        showSoftSnackbar(context, message: 'overlay');
        await tester.pump();
        await _frames(tester, 30);
        expect(find.text('overlay'), findsOneWidget);
        await tester.tapAt(const Offset(200, 100));
        expect(taps, 1);
        // Taps on the snackbar stay on it.
        await tester.tap(find.text('overlay'));
        expect(taps, 1);
        softOverlaySnackbarHost(context).newestSnackbarData!.dismiss();
        await _frames(tester, 40);
        expect(find.text('overlay'), findsNothing);
      },
    );
  });

  group('SoftTopTips', () {
    for (final bool dark in <bool>[false, true]) {
      testWidgets('one row is a capsule, a long one wraps (dark: $dark)', (
        WidgetTester tester,
      ) async {
        await tester.pumpWidget(
          _host(
            Column(
              children: <Widget>[
                SoftTopTips(
                  key: const Key('short'),
                  text: 'Update available',
                  actionText: 'Update',
                  onAction: () {},
                ),
                SoftTopTips(
                  key: const Key('long'),
                  text:
                      'This longer message shows how the action label drops '
                      'to its own row when the text would collide with it',
                  actionText: 'Turn on',
                  onAction: () {},
                ),
              ],
            ),
            dark: dark,
          ),
        );
        final Rect short = tester.getRect(find.byKey(const Key('short')));
        expect(short.width, 400);
        // 12 + 20 + 12.
        expect(short.height, closeTo(44, 0.5));
        final Rect message = tester.getRect(find.text('Update available'));
        final Rect action = tester.getRect(find.text('Update'));
        expect(action.center.dy, closeTo(message.center.dy, 2));

        final Rect turnOn = tester.getRect(find.text('Turn on'));
        final Rect long = tester.getRect(find.byKey(const Key('long')));
        expect(turnOn.top, greaterThan(long.top + 44));
        // The overflowing message scrolls after a second, then forever.
        await tester.pump(const Duration(milliseconds: 1100));
        expect(tester.binding.hasScheduledFrame, isTrue);

        final ShapeDecoration fill =
            tester
                    .widget<DecoratedBox>(
                      find
                          .descendant(
                            of: find.byKey(const Key('short')),
                            matching: find.byType(DecoratedBox),
                          )
                          .first,
                    )
                    .decoration
                as ShapeDecoration;
        expect(
          fill.color,
          dark ? const Color(0x1AFFFFFF) : const Color(0x0A000000),
        );
        expect(
          (fill.shape as SoftSquircleBorder).radius,
          BorderRadius.circular(72),
        );
        await tester.pumpWidget(const SizedBox());
      });
    }

    testWidgets('close hides it with a 250 ms vertical scale', (
      WidgetTester tester,
    ) async {
      bool visible = true;
      late StateSetter setState;
      await tester.pumpWidget(
        _host(
          StatefulBuilder(
            builder: (BuildContext context, StateSetter set) {
              setState = set;
              return Column(
                children: <Widget>[
                  SoftTopTips(
                    text: 'closable',
                    title: 'Title',
                    visible: visible,
                    marqueeEnabled: false,
                    onClose: () => set(() => visible = false),
                  ),
                ],
              );
            },
          ),
        ),
      );
      final Finder close = find.descendant(
        of: find.byType(SoftTopTips),
        matching: find.byType(SoftPressable),
      );
      await tester.tap(close);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 125));
      expect(find.text('closable'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 150));
      await tester.pump();
      expect(find.text('closable'), findsNothing);
      expect(tester.binding.hasScheduledFrame, isFalse);
      setState(() => visible = true);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('closable'), findsOneWidget);
      expect(tester.binding.hasScheduledFrame, isFalse);
    });
  });

  group('SoftTooltip', () {
    for (final bool dark in <bool>[false, true]) {
      testWidgets('a long press shows it and a tap outside hides it '
          '(dark: $dark)', (WidgetTester tester) async {
        int anchorTaps = 0;
        await tester.pumpWidget(
          _host(
            Center(
              child: SoftTooltip(
                message: 'Edit',
                showCaret: true,
                child: GestureDetector(
                  onTap: () => anchorTaps++,
                  child: const SizedBox.square(dimension: 40),
                ),
              ),
            ),
            dark: dark,
          ),
        );
        await tester.longPress(find.byType(SoftTooltip));
        expect(anchorTaps, 0);
        await _frames(tester, 60);
        expect(find.text('Edit'), findsOneWidget);
        expect(tester.binding.hasScheduledFrame, isFalse);
        // Below the anchor, 8 off, plus the 8 caret.
        final Rect anchor = tester.getRect(find.byType(SoftTooltip));
        final Rect label = tester.getRect(find.text('Edit'));
        expect(label.top, greaterThan(anchor.bottom + 8));
        expect(label.center.dx, closeTo(anchor.center.dx, 1));
        final DecoratedBox surface = tester.widget<DecoratedBox>(
          find
              .ancestor(
                of: find.text('Edit'),
                matching: find.byType(DecoratedBox),
              )
              .first,
        );
        expect(
          (surface.decoration as ShapeDecoration).color,
          dark ? const Color(0xFF1A8CFF) : const Color(0xFF0080FF),
        );

        await tester.tapAt(const Offset(20, 20));
        await _frames(tester, 60);
        expect(find.text('Edit'), findsNothing);
        expect(tester.binding.hasScheduledFrame, isFalse);
      });
    }

    testWidgets('shown from code it leaves after 1.5 s; one at a time', (
      WidgetTester tester,
    ) async {
      final SoftTooltipController a = SoftTooltipController();
      final SoftTooltipController b = SoftTooltipController();
      addTearDown(a.dispose);
      addTearDown(b.dispose);
      await tester.pumpWidget(
        _host(
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: <Widget>[
              SoftTooltip(
                message: 'A',
                controller: a,
                child: const SizedBox.square(dimension: 40),
              ),
              SoftTooltip(
                message: 'B',
                controller: b,
                position: SoftTooltipPosition.above,
                child: const SizedBox.square(dimension: 40),
              ),
            ],
          ),
        ),
      );
      a.show();
      await tester.pump();
      await _frames(tester, 30);
      expect(find.text('A'), findsOneWidget);
      b.show();
      await tester.pump();
      await _frames(tester, 40);
      expect(find.text('A'), findsNothing);
      expect(find.text('B'), findsOneWidget);
      // Above the anchor.
      expect(
        tester.getRect(find.text('B')).bottom,
        lessThan(tester.getRect(find.byType(SoftTooltip).last).top),
      );
      await tester.pump(const Duration(milliseconds: 1500));
      await _frames(tester, 40);
      expect(find.text('B'), findsNothing);
      expect(tester.binding.hasScheduledFrame, isFalse);
    });

    testWidgets('the rich tooltip action runs and dismisses', (
      WidgetTester tester,
    ) async {
      int actions = 0;
      int under = 0;
      await tester.pumpWidget(
        _host(
          Stack(
            children: <Widget>[
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => under++,
                ),
              ),
              Center(
                child: SoftRichTooltipBox(
                  title: 'Rich tooltip',
                  text: 'Body text',
                  actionText: 'Got it',
                  onAction: () => actions++,
                  child: const SizedBox.square(dimension: 40),
                ),
              ),
            ],
          ),
        ),
      );
      await tester.longPress(find.byType(SoftRichTooltipBox));
      await _frames(tester, 60);
      expect(find.text('Rich tooltip'), findsOneWidget);
      expect(find.text('Body text'), findsOneWidget);
      await tester.tap(find.text('Got it'));
      await tester.pump();
      expect(actions, 1);
      await _frames(tester, 60);
      expect(find.text('Body text'), findsNothing);

      // A tap outside a rich tooltip dismisses it without reaching the page.
      await tester.longPress(find.byType(SoftRichTooltipBox));
      await _frames(tester, 60);
      under = 0;
      await tester.tapAt(const Offset(20, 20));
      await _frames(tester, 60);
      expect(under, 0);
      expect(find.text('Body text'), findsNothing);
      expect(tester.binding.hasScheduledFrame, isFalse);
    });
  });

  group('progress indicators', () {
    for (final bool dark in <bool>[false, true]) {
      testWidgets('determinate ones are static (dark: $dark)', (
        WidgetTester tester,
      ) async {
        await tester.pumpWidget(
          _host(
            const Column(
              children: <Widget>[
                SoftLinearProgressIndicator(key: Key('linear'), progress: 0.4),
                SoftCircularProgressIndicator(
                  key: Key('circular'),
                  progress: 0.4,
                ),
                SoftCircularProgressIndicator(
                  key: Key('error'),
                  state: SoftCircularProgressState.error,
                ),
                SoftCircularProgressIndicator(
                  state: SoftCircularProgressState.paused,
                ),
              ],
            ),
            dark: dark,
          ),
        );
        expect(
          tester.getSize(find.byKey(const Key('linear'))),
          const Size(400, 4),
        );
        expect(
          tester.getSize(find.byKey(const Key('circular'))),
          const Size(30, 30),
        );
        expect(
          tester.getSize(find.byKey(const Key('error'))),
          const Size(30, 30),
        );
        expect(tester.binding.hasScheduledFrame, isFalse);
      });
    }

    testWidgets('indeterminate ones animate inside a repaint boundary', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _host(
          const Column(
            children: <Widget>[
              SoftLinearProgressIndicator(),
              SoftCircularProgressIndicator(),
              SoftInfiniteProgressIndicator(key: Key('infinite')),
              SoftRotatingProgressIndicator(key: Key('rotating')),
              SoftRotatingProgressIndicator.small(key: Key('small')),
            ],
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));
      expect(tester.binding.hasScheduledFrame, isTrue);
      expect(
        tester.getSize(find.byKey(const Key('infinite'))),
        const Size(18, 18),
      );
      expect(
        tester.getSize(find.byKey(const Key('rotating'))),
        const Size(26, 26),
      );
      expect(
        tester.getSize(find.byKey(const Key('small'))),
        const Size(16, 16),
      );
      expect(
        find.descendant(
          of: find.byType(SoftRotatingProgressIndicator).first,
          matching: find.byType(RepaintBoundary),
        ),
        findsWidgets,
      );
      // Switching to determinate stops the ticker.
      await tester.pumpWidget(
        _host(const SoftCircularProgressIndicator(progress: 1)),
      );
      await tester.pump();
      expect(tester.binding.hasScheduledFrame, isFalse);
    });
  });

  group('SoftPageIndicator', () {
    for (final bool dark in <bool>[false, true]) {
      testWidgets('sizes to the visible dots (dark: $dark)', (
        WidgetTester tester,
      ) async {
        await tester.pumpWidget(
          _host(
            const Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                SoftPageIndicator(key: Key('3'), count: 3, currentIndex: 1),
                SoftPageIndicator(key: Key('8'), count: 8, currentIndex: 6),
                SoftPageIndicator(key: Key('0'), count: 0, currentIndex: 0),
              ],
            ),
            dark: dark,
          ),
        );
        expect(tester.getSize(find.byKey(const Key('3'))), const Size(30, 6));
        expect(tester.getSize(find.byKey(const Key('8'))), const Size(66, 6));
        expect(tester.getSize(find.byKey(const Key('0'))), Size.zero);
      });
    }
  });

  group('SoftEmptyState', () {
    for (final bool dark in <bool>[false, true]) {
      testWidgets('sits at 45 % of the free height (dark: $dark)', (
        WidgetTester tester,
      ) async {
        int taps = 0;
        await tester.pumpWidget(
          _host(
            SoftEmptyState(
              title: 'Nothing here yet',
              subtitle: 'Items you add will show up here',
              actionText: 'Add',
              onAction: () => taps++,
              illustration: const SizedBox.expand(key: Key('art')),
            ),
            dark: dark,
          ),
        );
        final Rect art = tester.getRect(find.byKey(const Key('art')));
        expect(art.size, const Size(120, 100));
        final Rect action = tester.getRect(
          find.ancestor(
            of: find.text('Add'),
            matching: find.byType(SoftPressable),
          ),
        );
        final double content = action.bottom - art.top;
        expect(art.top, closeTo((800 - content) * 0.45, 1));
        await tester.tap(find.text('Add'));
        expect(taps, 1);
        await tester.pump(const Duration(milliseconds: 500));
        expect(tester.binding.hasScheduledFrame, isFalse);
      });
    }

    testWidgets('a short box hides the illustration; a loose one stacks at '
        'the top', (WidgetTester tester) async {
      await tester.pumpWidget(
        _host(
          const Column(
            children: <Widget>[
              SizedBox(
                height: 150,
                child: SoftEmptyState(
                  title: 'Small',
                  illustration: SizedBox.expand(key: Key('art')),
                ),
              ),
              SoftEmptyState(title: 'Loose'),
            ],
          ),
        ),
      );
      expect(find.byKey(const Key('art')), findsNothing);
      expect(tester.getRect(find.text('Loose')).top, closeTo(150, 0.5));
    });
  });
}
