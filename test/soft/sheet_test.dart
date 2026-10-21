import 'package:fluid_glass/fluid_glass.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'surface.dart';

const Key _content = ValueKey<String>('content');
const Duration _settle = Duration(milliseconds: 1500);

void _phone(WidgetTester tester, {Size size = const Size(400, 800)}) {
  tester.view.physicalSize = size * 3;
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}

Widget _host({required bool dark, required Widget home}) {
  return SoftTheme(
    data: dark ? const SoftThemeData.dark() : const SoftThemeData.light(),
    child: Directionality(
      textDirection: TextDirection.ltr,
      child: Navigator(
        onGenerateRoute: (RouteSettings settings) =>
            PageRouteBuilder<void>(pageBuilder: (_, _, _) => home),
      ),
    ),
  );
}

/// Pumps a page and returns a context under its navigator.
Future<BuildContext> _page(WidgetTester tester, {bool dark = false}) async {
  late BuildContext context;
  await tester.pumpWidget(
    _host(
      dark: dark,
      home: Builder(
        builder: (BuildContext c) {
          context = c;
          return const SizedBox.expand();
        },
      ),
    ),
  );
  return context;
}

Finder get _surface => find.byWidgetPredicate(
  (Widget w) =>
      w is DecoratedBox &&
      w.decoration is ShapeDecoration &&
      (w.decoration as ShapeDecoration).shape is SoftSquircleBorder,
);

/// Runs frames at 60 Hz for [_settle] and checks nothing asks for more.
Future<void> _settled(WidgetTester tester) async {
  await tester.pump();
  const Duration frame = Duration(microseconds: 16667);
  for (int i = 0; i < _settle.inMicroseconds ~/ frame.inMicroseconds; i++) {
    await tester.pump(frame);
  }
  expect(tester.binding.hasScheduledFrame, isFalse);
}

/// The middle of the drag strip, above the title row.
Offset _handle(WidgetTester tester) {
  final Rect surface = tester.getRect(_surface);
  return Offset(surface.center.dx, surface.top + 14);
}

double _contentTop(WidgetTester tester) =>
    tester.getRect(find.byKey(_content)).top;

Future<Future<Object?>> _open(
  WidgetTester tester,
  BuildContext context, {
  bool allowDismiss = true,
  bool enableNestedScroll = true,
  WidgetBuilder? builder,
  Widget? startAction,
}) async {
  final Future<Object?> result = showSoftBottomSheet<Object?>(
    context: context,
    title: 'Title',
    allowDismiss: allowDismiss,
    enableNestedScroll: enableNestedScroll,
    startAction: startAction,
    builder: builder ?? (_) => const SizedBox(key: _content, height: 200),
  );
  await _settled(tester);
  return result;
}

void main() {
  usePhoneSurface();

  group('layout', () {
    for (final bool dark in <bool>[false, true]) {
      testWidgets('rests at the bottom (${dark ? 'dark' : 'light'})', (
        WidgetTester tester,
      ) async {
        _phone(tester);
        final BuildContext context = await _page(tester, dark: dark);
        await _open(tester, context);

        final Rect surface = tester.getRect(_surface);
        expect(surface.left, 0);
        expect(surface.width, 400);
        expect(surface.bottom, 800);
        final ShapeDecoration decoration =
            tester.widget<DecoratedBox>(_surface).decoration as ShapeDecoration;
        expect(
          decoration.color,
          dark ? const Color(0xFF1E1E1E) : const Color(0xFFFFFFFF),
        );
        final SoftSquircleBorder border =
            decoration.shape as SoftSquircleBorder;
        expect(border.radius.topLeft, const Radius.circular(20));
        expect(border.radius.bottomLeft, Radius.zero);

        // Handle 24, title row 6 + text + 12, then the content inset 24.
        final Rect title = tester.getRect(find.text('Title'));
        expect(title.top, surface.top + 24 + 6);
        expect(title.center.dx, 200);
        final Rect content = tester.getRect(find.byKey(_content));
        expect(content.top, title.bottom + 12);
        expect(content.left, 24);
        expect(content.right, 376);
        expect(content.bottom, 800);

        final Text text = tester.widget<Text>(find.text('Title'));
        expect(text.style!.fontSize, 18);
        expect(text.style!.fontWeight, FontWeight.w500);
        expect(
          text.style!.color,
          dark ? const Color(0xE6FFFFFF) : const Color(0xE6000000),
        );
      });
    }

    testWidgets('is capped below the top inset', (WidgetTester tester) async {
      _phone(tester);
      tester.view.padding = const FakeViewPadding(top: 90);
      final BuildContext context = await _page(tester);
      await _open(
        tester,
        context,
        builder: (_) => const SingleChildScrollView(
          child: SizedBox(key: _content, height: 2000),
        ),
      );
      expect(tester.getRect(_surface).top, 30);
      expect(tester.getRect(_surface).bottom, 800);
    });

    testWidgets('takes six grid columns on a wide window', (
      WidgetTester tester,
    ) async {
      _phone(tester, size: const Size(1000, 800));
      final BuildContext context = await _page(tester);
      await _open(tester, context);
      final Rect surface = tester.getRect(_surface);
      expect(surface.width, closeTo((1000 - 80 - 132) / 12 * 6 + 60, 0.01));
      expect(surface.center.dx, 500);
    });

    testWidgets('rides above the keyboard', (WidgetTester tester) async {
      _phone(tester);
      final BuildContext context = await _page(tester);
      await _open(tester, context);
      tester.view.viewInsets = const FakeViewPadding(bottom: 900);
      await tester.pump();
      expect(tester.getRect(find.byKey(_content)).bottom, 500);
      tester.view.resetViewInsets();
      await tester.pump();
      expect(tester.getRect(find.byKey(_content)).bottom, 800);
    });
  });

  group('interaction', () {
    testWidgets('slides in from below', (WidgetTester tester) async {
      _phone(tester);
      final BuildContext context = await _page(tester);
      showSoftBottomSheet<void>(
        context: context,
        builder: (_) => const SizedBox(key: _content, height: 200),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));
      final double early = _contentTop(tester);
      await tester.pump(const Duration(milliseconds: 60));
      final double later = _contentTop(tester);
      expect(early, greaterThan(later));
      await tester.pump(_settle);
      expect(tester.binding.hasScheduledFrame, isFalse);
      expect(tester.getRect(find.byKey(_content)).bottom, 800);
    });

    testWidgets('a tap outside dismisses', (WidgetTester tester) async {
      _phone(tester);
      final BuildContext context = await _page(tester);
      final Future<Object?> result = await _open(tester, context);
      await tester.tapAt(const Offset(200, 100));
      await _settled(tester);
      expect(find.text('Title'), findsNothing);
      expect(await result, isNull);
    });

    testWidgets('a tap on the sheet does not dismiss', (
      WidgetTester tester,
    ) async {
      _phone(tester);
      final BuildContext context = await _page(tester);
      await _open(tester, context);
      await tester.tap(find.byKey(_content));
      await _settled(tester);
      expect(find.text('Title'), findsOneWidget);
    });

    testWidgets('allowDismiss false keeps it open', (
      WidgetTester tester,
    ) async {
      _phone(tester);
      final BuildContext context = await _page(tester);
      await _open(tester, context, allowDismiss: false);
      final double rest = _contentTop(tester);
      await tester.tapAt(const Offset(200, 100));
      await _settled(tester);
      expect(find.text('Title'), findsOneWidget);

      // A downward drag follows at a tenth and springs back.
      final TestGesture gesture = await tester.startGesture(_handle(tester));
      await gesture.moveBy(const Offset(0, 20));
      await tester.pump();
      final double start = _contentTop(tester);
      await gesture.moveBy(const Offset(0, 300));
      await tester.pump();
      expect(_contentTop(tester), closeTo(start + 30, 0.5));
      await gesture.up();
      await _settled(tester);
      expect(_contentTop(tester), rest);

      Navigator.of(context).maybePop();
      await _settled(tester);
      expect(find.text('Title'), findsOneWidget);
    });

    testWidgets('a long drag on the handle dismisses', (
      WidgetTester tester,
    ) async {
      _phone(tester);
      final BuildContext context = await _page(tester);
      final Future<Object?> result = await _open(tester, context);
      await tester.dragFrom(_handle(tester), const Offset(0, 300));
      await _settled(tester);
      expect(find.text('Title'), findsNothing);
      expect(await result, isNull);
    });

    testWidgets('a short drag springs back', (WidgetTester tester) async {
      _phone(tester);
      final BuildContext context = await _page(tester);
      await _open(tester, context);
      final double rest = _contentTop(tester);
      await tester.dragFrom(_handle(tester), const Offset(0, 80));
      await tester.pump();
      expect(_contentTop(tester), greaterThan(rest));
      await _settled(tester);
      expect(_contentTop(tester), rest);
    });

    testWidgets('a fast short fling dismisses', (WidgetTester tester) async {
      _phone(tester);
      final BuildContext context = await _page(tester);
      await _open(tester, context);
      await tester.flingFrom(_handle(tester), const Offset(0, 60), 2000);
      await _settled(tester);
      expect(find.text('Title'), findsNothing);
    });

    testWidgets('an upward pull stretches at a tenth', (
      WidgetTester tester,
    ) async {
      _phone(tester);
      final BuildContext context = await _page(tester);
      await _open(tester, context);
      final double rest = _contentTop(tester);
      final TestGesture gesture = await tester.startGesture(_handle(tester));
      await gesture.moveBy(const Offset(0, -20));
      await tester.pump();
      final double start = _contentTop(tester);
      await gesture.moveBy(const Offset(0, -100));
      await tester.pump();
      expect(_contentTop(tester), closeTo(start - 10, 0.5));
      // The surface itself lifts off the bottom edge.
      expect(tester.getRect(_surface).bottom, lessThan(800));
      await gesture.up();
      await _settled(tester);
      expect(_contentTop(tester), rest);
    });

    testWidgets('back slides it off and dismisses', (
      WidgetTester tester,
    ) async {
      _phone(tester);
      final BuildContext context = await _page(tester);
      await _open(tester, context);
      Navigator.of(context).maybePop();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.text('Title'), findsOneWidget);
      await _settled(tester);
      expect(find.text('Title'), findsNothing);
    });

    testWidgets('the scope dismisses from inside', (WidgetTester tester) async {
      _phone(tester);
      final BuildContext context = await _page(tester);
      await _open(
        tester,
        context,
        startAction: Builder(
          builder: (BuildContext c) => GestureDetector(
            onTap: () => SoftBottomSheetScope.dismissOf(c)!(),
            child: const SizedBox(width: 48, height: 48, child: Text('x')),
          ),
        ),
      );
      final Rect action = tester.getRect(find.text('x'));
      expect(action.left, 24);
      await tester.tap(find.text('x'));
      await _settled(tester);
      expect(find.text('Title'), findsNothing);
    });

    testWidgets('pops with a result', (WidgetTester tester) async {
      _phone(tester);
      final BuildContext context = await _page(tester);
      late BuildContext inner;
      final Future<Object?> result = await _open(
        tester,
        context,
        builder: (BuildContext c) {
          inner = c;
          return const SizedBox(key: _content, height: 200);
        },
      );
      Navigator.of(inner).pop('done');
      await _settled(tester);
      expect(await result, 'done');
    });
  });

  group('nested scroll', () {
    Widget tall(BuildContext _) => const SingleChildScrollView(
      child: SizedBox(key: _content, height: 1500),
    );

    ScrollPosition position(WidgetTester tester) =>
        tester.state<ScrollableState>(find.byType(Scrollable)).position;

    testWidgets('pulling down at the top drags and dismisses', (
      WidgetTester tester,
    ) async {
      _phone(tester);
      final BuildContext context = await _page(tester);
      await _open(
        tester,
        context,
        builder: (_) => const SingleChildScrollView(
          child: SizedBox(key: _content, height: 300),
        ),
      );
      await tester.dragFrom(
        tester.getCenter(find.byKey(_content)),
        const Offset(0, 300),
      );
      await _settled(tester);
      expect(find.text('Title'), findsNothing);
    });

    testWidgets('scrolls first, then hands the rest to the sheet', (
      WidgetTester tester,
    ) async {
      _phone(tester);
      final BuildContext context = await _page(tester);
      await _open(tester, context, builder: tall);
      final double surfaceTop = tester.getRect(_surface).top;
      final TestGesture gesture = await tester.startGesture(
        const Offset(200, 500),
      );
      await gesture.moveBy(const Offset(0, -20));
      await gesture.moveBy(const Offset(0, -200));
      await tester.pump();
      expect(position(tester).pixels, greaterThan(150));
      expect(tester.getRect(_surface).top, surfaceTop);

      await gesture.moveBy(const Offset(0, 260));
      await tester.pump();
      expect(position(tester).pixels, 0);
      final double pulled = tester.getRect(_surface).top - surfaceTop;
      expect(pulled, greaterThan(20));

      // Moving back up restores the sheet before the content scrolls.
      await gesture.moveBy(const Offset(0, -10));
      await tester.pump();
      expect(position(tester).pixels, 0);
      expect(
        tester.getRect(_surface).top - surfaceTop,
        closeTo(pulled - 10, 0.5),
      );

      await gesture.up();
      await _settled(tester);
      expect(tester.getRect(_surface).top, surfaceTop);
      expect(find.text('Title'), findsOneWidget);
    });

    testWidgets('disabled, the content never drags the sheet', (
      WidgetTester tester,
    ) async {
      _phone(tester);
      final BuildContext context = await _page(tester);
      await _open(tester, context, enableNestedScroll: false, builder: tall);
      final double surfaceTop = tester.getRect(_surface).top;
      final TestGesture gesture = await tester.startGesture(
        const Offset(200, 500),
      );
      await gesture.moveBy(const Offset(0, 20));
      await gesture.moveBy(const Offset(0, 300));
      await tester.pump();
      expect(tester.getRect(_surface).top, surfaceTop);
      await gesture.up();
      await _settled(tester);
      expect(find.text('Title'), findsOneWidget);
    });
  });

  group('declarative', () {
    testWidgets('follows show and reports dismissal', (
      WidgetTester tester,
    ) async {
      _phone(tester);
      bool show = false;
      bool allowDismiss = false;
      int requests = 0;
      int finished = 0;
      late StateSetter update;
      await tester.pumpWidget(
        _host(
          dark: false,
          home: StatefulBuilder(
            builder: (BuildContext context, StateSetter setState) {
              update = setState;
              return SoftBottomSheet(
                show: show,
                title: 'Sheet',
                allowDismiss: allowDismiss,
                onDismissRequest: () {
                  requests++;
                  setState(() => show = false);
                },
                onDismissFinished: () => finished++,
                child: const SizedBox(key: _content, height: 200),
              );
            },
          ),
        ),
      );
      expect(find.text('Sheet'), findsNothing);

      update(() => show = true);
      await _settled(tester);
      expect(find.text('Sheet'), findsOneWidget);

      await tester.tapAt(const Offset(200, 100));
      await _settled(tester);
      expect(requests, 0);

      // Parameters update while open.
      update(() => allowDismiss = true);
      await _settled(tester);
      await tester.tapAt(const Offset(200, 100));
      await _settled(tester);
      expect(requests, 1);
      expect(finished, 1);
      expect(find.text('Sheet'), findsNothing);

      // Reopening and closing from the owner.
      update(() => show = true);
      await _settled(tester);
      expect(find.text('Sheet'), findsOneWidget);
      update(() => show = false);
      await _settled(tester);
      expect(find.text('Sheet'), findsNothing);
      expect(finished, 2);
    });

    testWidgets('a drag past the threshold asks the owner', (
      WidgetTester tester,
    ) async {
      _phone(tester);
      bool show = true;
      int finished = 0;
      await tester.pumpWidget(
        _host(
          dark: true,
          home: StatefulBuilder(
            builder: (BuildContext context, StateSetter setState) =>
                SoftBottomSheet(
                  show: show,
                  onDismissRequest: () => setState(() => show = false),
                  onDismissFinished: () => finished++,
                  child: const SizedBox(key: _content, height: 200),
                ),
          ),
        ),
      );
      await _settled(tester);
      await tester.dragFrom(_handle(tester), const Offset(0, 300));
      await _settled(tester);
      expect(find.byKey(_content), findsNothing);
      expect(finished, 1);
    });
  });
}
