import 'package:fluid_glass/fluid_glass.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'surface.dart';

const Size _phone = Size(400, 800);
const Size _tablet = Size(1000, 800);

/// A bare widgets app whose home exposes a context that can open dialogs.
Widget _app({required bool dark, required ValueSetter<BuildContext> onHome}) {
  return SoftTheme(
    data: dark ? const SoftThemeData.dark() : const SoftThemeData.light(),
    child: WidgetsApp(
      color: const Color(0xFF000000),
      pageRouteBuilder: <T>(RouteSettings settings, WidgetBuilder builder) =>
          PageRouteBuilder<T>(
            settings: settings,
            pageBuilder:
                (
                  BuildContext context,
                  Animation<double> animation,
                  Animation<double> secondaryAnimation,
                ) => builder(context),
          ),
      home: Builder(
        builder: (BuildContext context) {
          onHome(context);
          return const SizedBox.expand();
        },
      ),
    ),
  );
}

Future<BuildContext> _pumpHome(
  WidgetTester tester, {
  bool dark = false,
  Size size = _phone,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  late BuildContext home;
  await tester.pumpWidget(
    _app(dark: dark, onHome: (BuildContext context) => home = context),
  );
  return home;
}

/// The dialog panel (or card) surface.
final Finder _panel = find.byWidgetPredicate(
  (Widget widget) =>
      widget is DecoratedBox &&
      widget.decoration is ShapeDecoration &&
      (widget.decoration as ShapeDecoration).shape is SoftSquircleBorder,
);

Color? _panelColor(WidgetTester tester) =>
    (tester.widget<DecoratedBox>(_panel).decoration as ShapeDecoration).color;

/// Lets the enter animation (250 ms) run out.
Future<void> _settleEnter(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

Future<void> _sendBackGesture(
  WidgetTester tester,
  String method, [
  double? progress,
]) async {
  final ByteData message = const StandardMethodCodec().encodeMethodCall(
    MethodCall(
      method,
      progress == null
          ? null
          : <String, Object?>{
              'touchOffset': <double>[300, 400],
              'progress': progress,
              'swipeEdge': 0,
            },
    ),
  );
  await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
    'flutter/backgesture',
    message,
    (ByteData? _) {},
  );
  await tester.pump();
}

SoftDialogButtonBar _bar({
  SoftDialogAction? negative,
  SoftDialogAction? positive,
  SoftDialogAction? neutral,
}) => SoftDialogButtonBar(
  negative: negative,
  positive: positive,
  neutral: neutral,
);

void main() {
  usePhoneSurface();

  group('showSoftDialog', () {
    for (final bool dark in <bool>[false, true]) {
      testWidgets('bottom-anchored on a phone (${dark ? 'dark' : 'light'})', (
        WidgetTester tester,
      ) async {
        final BuildContext home = await _pumpHome(tester, dark: dark);
        showSoftDialog<void>(
          context: home,
          title: 'Title',
          summary: 'Summary',
          builder: (BuildContext context) => _bar(
            negative: SoftDialogAction(label: 'No', onPressed: () {}),
            positive: SoftDialogAction(label: 'Yes', onPressed: () {}),
          ),
        );
        await _settleEnter(tester);

        final Rect panel = tester.getRect(_panel);
        expect(panel.left, 16);
        expect(panel.width, 368);
        expect(panel.bottom, closeTo(800 - 32, 0.01));
        final SoftColors colors = dark
            ? const SoftColors.dark()
            : const SoftColors.light();
        expect(_panelColor(tester), colors.background);
        final Text title = tester.widget<Text>(find.text('Title'));
        expect(title.style!.color, colors.onBackground);
        expect(title.style!.fontSize, 18);
        expect(title.style!.fontWeight, FontWeight.w500);
        expect(
          tester.widget<Text>(find.text('Summary')).textAlign,
          TextAlign.center,
        );
        // Two short labels share a row, negative first.
        final Offset no = tester.getCenter(find.text('No'));
        final Offset yes = tester.getCenter(find.text('Yes'));
        expect(no.dy, yes.dy);
        expect(no.dx, lessThan(yes.dx));
        expect(
          tester.widget<Text>(find.text('Yes')).style!.color,
          colors.primary,
        );
        // Settled: nothing keeps asking for frames.
        expect(tester.binding.hasScheduledFrame, isFalse);
      });
    }

    testWidgets('slides up from below its resting place', (
      WidgetTester tester,
    ) async {
      final BuildContext home = await _pumpHome(tester);
      showSoftDialog<void>(context: home, title: 'Title', summary: 'Summary');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 40));
      final double early = tester.getRect(_panel).bottom;
      expect(early, greaterThan(768));
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.getRect(_panel).bottom, closeTo(768, 0.01));
    });

    testWidgets('centred on a large window', (WidgetTester tester) async {
      final BuildContext home = await _pumpHome(tester, size: _tablet);
      showSoftDialog<void>(context: home, title: 'Title', summary: 'Summary');
      await _settleEnter(tester);
      final Rect panel = tester.getRect(_panel);
      expect(panel.width, SoftDialogDefaults.maxWidth);
      expect(panel.center.dx, closeTo(500, 0.01));
      // The bottom margin applies to a centred panel too.
      expect(panel.center.dy, closeTo((800 - 32) / 2, 0.01));
      expect(tester.binding.hasScheduledFrame, isFalse);
    });

    testWidgets('a tap outside dismisses it after the exit animation', (
      WidgetTester tester,
    ) async {
      final BuildContext home = await _pumpHome(tester);
      bool finished = false;
      bool completed = false;
      String? result = 'unset';
      showSoftDialog<String>(
        context: home,
        title: 'Title',
        onDismissFinished: () => finished = true,
      ).then((String? value) {
        completed = true;
        result = value;
      });
      await _settleEnter(tester);

      // Taps on the panel stay on the panel.
      await tester.tap(find.text('Title'));
      await tester.pump();
      expect(completed, isFalse);

      await tester.tapAt(const Offset(200, 100));
      await tester.pump();
      expect(completed, isTrue);
      expect(result, isNull);
      expect(_panel, findsOneWidget);
      await tester.pump(const Duration(milliseconds: 300));
      expect(_panel, findsNothing);
      expect(finished, isTrue);
      expect(tester.binding.hasScheduledFrame, isFalse);
    });

    testWidgets('a non-dismissible dialog ignores outside taps and back', (
      WidgetTester tester,
    ) async {
      final BuildContext home = await _pumpHome(tester);
      showSoftDialog<void>(context: home, title: 'Title', dismissible: false);
      await _settleEnter(tester);
      await tester.tapAt(const Offset(200, 100));
      await tester.pump(const Duration(milliseconds: 300));
      expect(_panel, findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(_panel, findsOneWidget);
    });

    testWidgets('the back button pops a dismissible dialog', (
      WidgetTester tester,
    ) async {
      final BuildContext home = await _pumpHome(tester);
      showSoftDialog<void>(context: home, title: 'Title');
      await _settleEnter(tester);
      await tester.binding.handlePopRoute();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(_panel, findsNothing);
    });

    testWidgets('keeps clear of the keyboard', (WidgetTester tester) async {
      final BuildContext home = await _pumpHome(tester);
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      showSoftDialog<void>(context: home, title: 'Title', summary: 'Summary');
      await _settleEnter(tester);
      expect(tester.getRect(_panel).bottom, closeTo(800 - 300 - 32, 0.01));
    });

    testWidgets('the back gesture lowers the panel and can be cancelled', (
      WidgetTester tester,
    ) async {
      final BuildContext home = await _pumpHome(tester);
      showSoftDialog<void>(context: home, title: 'Title', summary: 'Summary');
      await _settleEnter(tester);
      final double resting = tester.getRect(_panel).top;

      await _sendBackGesture(tester, 'startBackGesture', 0);
      await _sendBackGesture(tester, 'updateBackGestureProgress', 0.5);
      expect(tester.getRect(_panel).top, greaterThan(resting));

      await _sendBackGesture(tester, 'cancelBackGesture');
      // The panel settles first, then the dimming.
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump(const Duration(milliseconds: 200));
      expect(tester.getRect(_panel).top, closeTo(resting, 0.01));
      expect(tester.binding.hasScheduledFrame, isFalse);

      await _sendBackGesture(tester, 'startBackGesture', 0);
      await _sendBackGesture(tester, 'updateBackGestureProgress', 0.6);
      await _sendBackGesture(tester, 'commitBackGesture');
      await tester.pump(const Duration(milliseconds: 300));
      expect(_panel, findsNothing);
    });

    testWidgets('the back gesture shrinks a centred panel', (
      WidgetTester tester,
    ) async {
      final BuildContext home = await _pumpHome(tester, size: _tablet);
      showSoftDialog<void>(context: home, title: 'Title', summary: 'Summary');
      await _settleEnter(tester);
      final double width = tester.getRect(_panel).width;
      await _sendBackGesture(tester, 'startBackGesture', 0);
      await _sendBackGesture(tester, 'updateBackGestureProgress', 0.5);
      expect(tester.getRect(_panel).width, closeTo(width * 0.9, 0.01));
      await _sendBackGesture(tester, 'cancelBackGesture');
      await tester.pump(const Duration(milliseconds: 400));
      expect(tester.getRect(_panel).width, closeTo(width, 0.01));
    });

    testWidgets('a wrapping summary is start-aligned with tighter padding', (
      WidgetTester tester,
    ) async {
      final BuildContext home = await _pumpHome(tester);
      showSoftDialog<void>(
        context: home,
        summary: List<String>.filled(20, 'long words').join(' '),
      );
      await _settleEnter(tester);
      final Text summary = tester.widget<Text>(find.textContaining('long'));
      expect(summary.textAlign, TextAlign.start);
      final Rect text = tester.getRect(find.textContaining('long'));
      expect(text.top - tester.getRect(_panel).top, closeTo(8, 0.01));
    });
  });

  group('SoftDialogButtonBar', () {
    Future<void> openBar(WidgetTester tester, SoftDialogButtonBar bar) async {
      final BuildContext home = await _pumpHome(tester);
      showSoftDialog<void>(
        context: home,
        title: 'Title',
        builder: (BuildContext context) => bar,
      );
      await _settleEnter(tester);
    }

    testWidgets('a label that does not fit stacks the bar', (
      WidgetTester tester,
    ) async {
      await openBar(
        tester,
        _bar(
          negative: SoftDialogAction(label: 'Not now', onPressed: () {}),
          positive: SoftDialogAction(
            label: 'Delete the backup and every local copy of it',
            onPressed: () {},
          ),
        ),
      );
      final Offset negative = tester.getCenter(find.text('Not now'));
      final Offset positive = tester.getCenter(
        find.textContaining('Delete the backup'),
      );
      // Positive on top, negative below, both centred.
      expect(positive.dy, lessThan(negative.dy));
      expect(positive.dx, closeTo(negative.dx, 0.01));
    });

    testWidgets('three actions stack neutral, positive, negative', (
      WidgetTester tester,
    ) async {
      await openBar(
        tester,
        _bar(
          negative: SoftDialogAction(label: 'A', onPressed: () {}),
          positive: SoftDialogAction(label: 'B', onPressed: () {}),
          neutral: SoftDialogAction(label: 'C', onPressed: () {}),
        ),
      );
      final double a = tester.getCenter(find.text('A')).dy;
      final double b = tester.getCenter(find.text('B')).dy;
      final double c = tester.getCenter(find.text('C')).dy;
      expect(c, lessThan(b));
      expect(b, lessThan(a));
    });

    testWidgets('taps, recommended and disabled actions', (
      WidgetTester tester,
    ) async {
      final List<String> taps = <String>[];
      await openBar(
        tester,
        _bar(
          negative: SoftDialogAction(
            label: 'Off',
            enabled: false,
            onPressed: () => taps.add('off'),
          ),
          positive: SoftDialogAction(
            label: 'Go',
            recommended: true,
            onPressed: () => taps.add('go'),
          ),
        ),
      );
      const SoftColors colors = SoftColors.light();
      expect(
        tester.widget<Text>(find.text('Go')).style!.color,
        colors.onPrimary,
      );
      expect(
        tester.widget<Text>(find.text('Off')).style!.color,
        colors.disabledPrimary,
      );

      await tester.tap(find.text('Off'));
      await tester.tap(find.text('Go'));
      expect(taps, <String>['go']);

      // A held press shrinks the button, and lets go on release.
      final TestGesture gesture = await tester.startGesture(
        tester.getCenter(find.text('Go')),
      );
      // The press shows 150 ms in, then springs.
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump(const Duration(milliseconds: 400));
      final double pressed = tester.getRect(find.text('Go')).width;
      await gesture.up();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      expect(tester.getRect(find.text('Go')).width, greaterThan(pressed));
      expect(tester.binding.hasScheduledFrame, isFalse);
    });
  });

  group('showSoftAlertDialog', () {
    for (final bool dark in <bool>[false, true]) {
      testWidgets('centred on a phone (${dark ? 'dark' : 'light'})', (
        WidgetTester tester,
      ) async {
        final BuildContext home = await _pumpHome(tester, dark: dark);
        showSoftAlertDialog(
          context: home,
          title: 'Delete?',
          summary: 'Gone for good.',
          confirmText: 'Delete',
          cancelText: 'Cancel',
          destructive: true,
        );
        await _settleEnter(tester);
        final Rect panel = tester.getRect(_panel);
        expect(panel.center.dx, closeTo(200, 0.01));
        // The bottom margin applies to a centred panel too.
        expect(panel.center.dy, closeTo((800 - 32) / 2, 0.01));
        final SoftColors colors = dark
            ? const SoftColors.dark()
            : const SoftColors.light();
        expect(_panelColor(tester), colors.background);
        expect(
          tester.widget<Text>(find.text('Delete')).style!.color,
          colors.error,
        );
        expect(tester.binding.hasScheduledFrame, isFalse);
      });
    }

    testWidgets('completes with the button tapped', (
      WidgetTester tester,
    ) async {
      final BuildContext home = await _pumpHome(tester);
      bool? result;
      showSoftAlertDialog(
        context: home,
        title: 'Delete?',
        confirmText: 'Delete',
        cancelText: 'Cancel',
      ).then((bool value) => result = value);
      await _settleEnter(tester);
      await tester.tap(find.text('Delete'));
      await tester.pump();
      expect(result, isTrue);
      // A centred dialog fades out in 150 ms.
      await tester.pump(const Duration(milliseconds: 200));
      expect(_panel, findsNothing);

      showSoftAlertDialog(
        context: home,
        title: 'Delete?',
        confirmText: 'Delete',
        cancelText: 'Cancel',
      ).then((bool value) => result = value);
      await _settleEnter(tester);
      await tester.tap(find.text('Cancel'));
      await tester.pump();
      expect(result, isFalse);
      await tester.pump(const Duration(milliseconds: 200));

      result = null;
      showSoftAlertDialog(
        context: home,
        title: 'Delete?',
        confirmText: 'Delete',
        cancelText: 'Cancel',
      ).then((bool value) => result = value);
      await _settleEnter(tester);
      await tester.tapAt(const Offset(200, 40));
      await tester.pump();
      expect(result, isFalse);
      await tester.pump(const Duration(milliseconds: 200));
      expect(_panel, findsNothing);
    });

    testWidgets('a second tap during the exit does not pop the page', (
      WidgetTester tester,
    ) async {
      final BuildContext home = await _pumpHome(tester);
      showSoftAlertDialog(
        context: home,
        title: 'Delete?',
        confirmText: 'Delete',
        cancelText: 'Cancel',
      );
      await _settleEnter(tester);
      await tester.tap(find.text('Delete'));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(find.text('Delete'), warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 200));
      expect(Navigator.of(home).canPop(), isFalse);
      expect(_panel, findsNothing);
    });
  });

  group('loading and progress dialogs', () {
    for (final bool dark in <bool>[false, true]) {
      testWidgets('the loading card (${dark ? 'dark' : 'light'})', (
        WidgetTester tester,
      ) async {
        final BuildContext home = await _pumpHome(tester, dark: dark);
        showSoftLoadingDialog(context: home, text: 'Loading');
        await _settleEnter(tester);
        final Rect card = tester.getRect(_panel);
        expect(card.width, SoftLoadingDialogDefaults.cardWidth);
        expect(card.height, greaterThanOrEqualTo(120));
        expect(card.center.dx, closeTo(200, 0.01));
        expect(card.center.dy, closeTo((800 - 32) / 2, 0.01));
        final SoftColors colors = dark
            ? const SoftColors.dark()
            : const SoftColors.light();
        expect(_panelColor(tester), colors.background);
        expect(find.byType(SoftDialogSpinner), findsOneWidget);
        // The spinner spins forever, inside its own repaint boundary.
        expect(tester.binding.hasScheduledFrame, isTrue);
        expect(
          find.ancestor(
            of: find.byType(CustomPaint),
            matching: find.byType(RepaintBoundary),
          ),
          findsWidgets,
        );

        // Not dismissible by default.
        await tester.tapAt(const Offset(200, 40));
        await tester.pump(const Duration(milliseconds: 300));
        expect(_panel, findsOneWidget);

        Navigator.of(home).pop();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));
        expect(_panel, findsNothing);
        await tester.pump();
        expect(tester.binding.hasScheduledFrame, isFalse);
      });
    }

    testWidgets('a loading card without text centres the spinner', (
      WidgetTester tester,
    ) async {
      final BuildContext home = await _pumpHome(tester);
      showSoftLoadingDialog(context: home);
      await _settleEnter(tester);
      final Rect card = tester.getRect(_panel);
      expect(card.size, const Size(152, 120));
      expect(
        tester.getCenter(find.byType(SoftDialogSpinner)),
        offsetMoreOrLessEquals(card.center),
      );
      Navigator.of(home).pop();
      await tester.pump(const Duration(milliseconds: 200));
    });

    testWidgets('the progress dialog follows its listenable', (
      WidgetTester tester,
    ) async {
      final BuildContext home = await _pumpHome(tester);
      final ValueNotifier<double?> progress = ValueNotifier<double?>(null);
      addTearDown(progress.dispose);
      showSoftProgressDialog(
        context: home,
        progress: progress,
        textBuilder: (double? value) => value == null ? 'Connecting' : 'Busy',
      );
      await _settleEnter(tester);
      expect(find.text('Connecting'), findsOneWidget);
      // Indeterminate: the sweep keeps running.
      expect(tester.binding.hasScheduledFrame, isTrue);

      progress.value = 0.5;
      await tester.pump();
      expect(find.text('Busy'), findsOneWidget);
      final Semantics semantics = tester.widget<Semantics>(
        find.byWidgetPredicate(
          (Widget widget) =>
              widget is Semantics && widget.properties.value == '50%',
        ),
      );
      expect(semantics, isNotNull);
      // Determinate: nothing animates any more.
      await tester.pump(const Duration(milliseconds: 16));
      expect(tester.binding.hasScheduledFrame, isFalse);

      Navigator.of(home).pop();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(_panel, findsNothing);
    });
  });
}
