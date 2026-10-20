import 'dart:async';

import 'package:fluid_glass/fluid_glass.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const List<LiquidCommand> _commands = <LiquidCommand>[
  LiquidCommand(
    id: 'new',
    label: 'New canvas',
    description: 'A fresh idea',
    group: 'Workspace',
    icon: Icons.add,
    keywords: <String>['create', '创建', '画布'],
  ),
  LiquidCommand(
    id: 'disabled',
    label: 'Invite team',
    group: 'Workspace',
    enabled: false,
  ),
  LiquidCommand(
    id: 'open',
    label: 'Open recent',
    description: 'Your last project',
    group: 'Workspace',
  ),
  LiquidCommand(
    id: 'theme',
    label: 'Dark appearance',
    group: 'Preferences',
    keywords: <String>['theme'],
  ),
];

Widget _host(
  Widget child, {
  bool still = false,
  double scale = 1,
  EdgeInsets insets = EdgeInsets.zero,
}) => MaterialApp(
  home: MediaQuery(
    data: MediaQueryData(
      size: const Size(800, 600),
      disableAnimations: still,
      textScaler: TextScaler.linear(scale),
      viewInsets: insets,
    ),
    child: Scaffold(body: Center(child: child)),
  ),
);

Finder _row(String id) => find.byKey(ValueKey<String>(id)).last;

Future<void> _pump(
  WidgetTester tester, {
  TextEditingController? controller,
  FocusNode? focusNode,
  FutureOr<void> Function(LiquidCommand)? onSelected,
  List<LiquidCommand> commands = _commands,
  bool still = false,
}) async {
  await tester.pumpWidget(
    _host(
      LiquidCommandPalette(
        commands: commands,
        backdrop: emptyBackdrop,
        controller: controller,
        focusNode: focusNode,
        onSelected: onSelected ?? (_) {},
      ),
      still: still,
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'search matches labels, descriptions, keywords and multiple tokens',
    (tester) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      await _pump(tester, controller: controller);
      controller.text = 'CREATE 画布';
      await tester.pumpAndSettle();
      expect(find.text('New canvas'), findsOneWidget);
      expect(find.text('Open recent'), findsNothing);
      controller.text = 'last project';
      await tester.pumpAndSettle();
      expect(find.text('Open recent'), findsOneWidget);
      expect(find.text('New canvas'), findsNothing);
      controller.text = 'theme';
      await tester.pumpAndSettle();
      expect(find.text('Dark appearance'), findsOneWidget);
      controller.clear();
      await tester.pumpAndSettle();
      expect(find.text('New canvas'), findsOneWidget);
    },
  );

  testWidgets('keyboard selection skips disabled actions and executes once', (
    tester,
  ) async {
    final List<String> calls = <String>[];
    final focus = FocusNode();
    addTearDown(focus.dispose);
    await _pump(tester, focusNode: focus, onSelected: (c) => calls.add(c.id));
    expect(focus.hasPrimaryFocus, isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(calls, <String>['open']);
    expect(focus.hasPrimaryFocus, isTrue);
  });

  testWidgets('search editing and IME composition do not execute a command', (
    tester,
  ) async {
    int calls = 0;
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    await _pump(tester, controller: controller, onSelected: (_) => calls++);
    controller.value = const TextEditingValue(
      text: '创建',
      selection: TextSelection.collapsed(offset: 2),
      composing: TextRange(start: 0, end: 2),
    );
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(calls, 0);
    controller.value = const TextEditingValue(
      text: '创建',
      selection: TextSelection.collapsed(offset: 2),
    );
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.home);
    await tester.pump();
    expect(controller.text, '创建');
    expect(calls, 0);
  });

  testWidgets('empty results crossfade without moving the field or footer', (
    tester,
  ) async {
    final controller = TextEditingController();
    final focus = FocusNode();
    addTearDown(controller.dispose);
    addTearDown(focus.dispose);
    await _pump(tester, controller: controller, focusNode: focus);
    final Rect field = tester.getRect(find.byType(TextField));
    final Size panel = tester.getSize(find.byType(LiquidCommandPalette));
    controller.text = 'nothing here';
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));
    expect(tester.getRect(find.byType(TextField)), field);
    expect(tester.getSize(find.byType(LiquidCommandPalette)), panel);
    await tester.pumpAndSettle();
    expect(find.text('No matching commands'), findsOneWidget);
    expect(focus.hasPrimaryFocus, isTrue);
    await tester.tap(find.byTooltip('Clear search'));
    await tester.pumpAndSettle();
    expect(find.text('New canvas'), findsOneWidget);
  });

  testWidgets(
    'async execution is serialized and supports a recoverable retry',
    (tester) async {
      int attempts = 0;
      Completer<void> pending = Completer<void>();
      await _pump(
        tester,
        onSelected: (_) {
          attempts++;
          return pending.future;
        },
      );
      await tester.tap(_row('new'));
      await tester.pump();
      expect(find.text('Running · New canvas'), findsOneWidget);
      await tester.tap(_row('open'));
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      expect(attempts, 1);
      pending.completeError(StateError('offline'));
      await tester.pumpAndSettle();
      expect(find.text('That did not finish. Try again.'), findsOneWidget);
      pending = Completer<void>();
      await tester.tap(find.text('Retry'));
      await tester.pump();
      expect(attempts, 2);
      pending.complete();
      await tester.pumpAndSettle();
      expect(find.text('Completed · New canvas'), findsOneWidget);
      expect(tester.binding.transientCallbackCount, 0);
    },
  );

  testWidgets('an async completion after disposal does not touch the route', (
    tester,
  ) async {
    final pending = Completer<void>();
    int completed = 0;
    await tester.pumpWidget(
      _host(
        LiquidCommandPalette(
          commands: _commands,
          backdrop: emptyBackdrop,
          onSelected: (_) => pending.future,
          onCompleted: (_) => completed++,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(_row('new'));
    await tester.pump();
    await tester.pumpWidget(const SizedBox());
    pending.complete();
    await tester.pump();
    expect(completed, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('screen readers can select enabled commands only', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final List<String> calls = <String>[];
    await _pump(tester, onSelected: (c) => calls.add(c.id));
    final SemanticsNode disabled = tester.getSemantics(_row('disabled'));
    expect(disabled.getSemanticsData().hasAction(SemanticsAction.tap), isFalse);
    final SemanticsNode open = tester.getSemantics(_row('open'));
    expect(open.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
    open.owner!.performAction(open.id, SemanticsAction.tap);
    await tester.pumpAndSettle();
    expect(calls, <String>['open']);
    semantics.dispose();
  });

  testWidgets(
    'large command sets are built lazily and scroll to keyboard selection',
    (tester) async {
      await _pump(
        tester,
        commands: <LiquidCommand>[
          for (int i = 0; i < 1000; i++)
            LiquidCommand(id: '$i', label: 'Command $i'),
        ],
      );
      expect(find.byType(InkWell).evaluate().length, lessThan(20));
      for (int i = 0; i < 12; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.pump(const Duration(milliseconds: 20));
      }
      await tester.pumpAndSettle();
      expect(find.text('Command 12'), findsOneWidget);
      expect(tester.getRect(find.text('Command 12')).center.dy, lessThan(500));
    },
  );

  testWidgets('a selection reversal never snaps or rebuilds on spring ticks', (
    tester,
  ) async {
    await _pump(tester);
    final SpringValue beam = tester
        .widgetList<CustomPaint>(find.byType(CustomPaint))
        .map((paint) => paint.painter)
        .where(
          (painter) => painter.runtimeType.toString() == '_SelectionPainter',
        )
        .map((painter) => (painter as dynamic).y as SpringValue)
        .single;
    final double from = beam.value;
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    expect(beam.value, from);
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(const Duration(milliseconds: 60));
    final double middle = beam.value;
    expect(middle, greaterThan(from));
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pump();
    expect(beam.value, middle);
    final List<String> builds = <String>[];
    final previous = debugOnRebuildDirtyWidget;
    debugOnRebuildDirtyWidget = (element, builtOnce) =>
        builds.add(element.widget.runtimeType.toString());
    try {
      for (int i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
    } finally {
      debugOnRebuildDirtyWidget = previous;
    }
    expect(builds, isEmpty);
    await tester.pumpAndSettle();
    expect(beam.value, from);
    expect(tester.binding.transientCallbackCount, 0);
  });

  testWidgets(
    'reduced motion settles selection and filtering without tickers',
    (tester) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      await _pump(tester, controller: controller, still: true);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      controller.text = 'no results';
      await tester.pumpAndSettle();
      expect(find.text('No matching commands'), findsOneWidget);
      expect(tester.binding.transientCallbackCount, 0);
    },
  );

  testWidgets('caller-owned controllers and nodes can be swapped and reused', (
    tester,
  ) async {
    final first = TextEditingController(text: 'recent');
    final second = TextEditingController(text: 'theme');
    final focus = FocusNode();
    addTearDown(first.dispose);
    addTearDown(second.dispose);
    addTearDown(focus.dispose);
    await _pump(tester, controller: first, focusNode: focus);
    expect(find.text('Open recent'), findsOneWidget);
    await _pump(tester, controller: second, focusNode: focus);
    expect(find.text('Dark appearance'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    first.clear();
    second.clear();
    focus.requestFocus();
    expect(tester.takeException(), isNull);
  });

  testWidgets('rapid filtering never exposes an outgoing result to input', (
    tester,
  ) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    final List<String> calls = <String>[];
    await _pump(
      tester,
      controller: controller,
      onSelected: (c) => calls.add(c.id),
    );
    for (final query in <String>[
      'recent',
      'theme',
      'none',
      'create',
      'theme',
    ]) {
      controller.text = query;
      await tester.pump(const Duration(milliseconds: 20));
    }
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(calls, <String>['theme']);
    expect(tester.takeException(), isNull);
    expect(tester.binding.transientCallbackCount, 0);
  });

  testWidgets('a command update replaces a removed keyboard selection', (
    tester,
  ) async {
    final controller = TextEditingController(text: 'theme');
    addTearDown(controller.dispose);
    final List<String> calls = <String>[];
    await _pump(
      tester,
      controller: controller,
      onSelected: (c) => calls.add(c.id),
    );
    await _pump(
      tester,
      controller: controller,
      commands: const <LiquidCommand>[
        LiquidCommand(id: 'replacement', label: 'Theme editor'),
      ],
      onSelected: (c) => calls.add(c.id),
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(calls, <String>['replacement']);
  });

  testWidgets('compact mode keeps the same field state and focus', (
    tester,
  ) async {
    final controller = TextEditingController(text: 'recent');
    final focus = FocusNode();
    addTearDown(controller.dispose);
    addTearDown(focus.dispose);
    Widget host(double height) => _host(
      SizedBox(
        width: 340,
        height: height,
        child: LiquidCommandPalette(
          commands: _commands,
          backdrop: emptyBackdrop,
          controller: controller,
          focusNode: focus,
          onSelected: (_) {},
          onDismiss: () {},
        ),
      ),
      scale: 1.8,
    );
    await tester.pumpWidget(host(520));
    await tester.pumpAndSettle();
    final State field = tester.state(find.byType(TextField));
    await tester.pumpWidget(host(170));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(identical(tester.state(find.byType(TextField)), field), isTrue);
    expect(focus.hasPrimaryFocus, isTrue);
    expect(find.byTooltip('Close'), findsOneWidget);
    expect(controller.text, 'recent');
  });

  for (final Brightness brightness in Brightness.values) {
    testWidgets('narrow layout supports large text ($brightness)', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          Theme(
            data: ThemeData(brightness: brightness),
            child: SizedBox(
              width: 320,
              height: 520,
              child: LiquidCommandPalette(
                commands: _commands,
                backdrop: emptyBackdrop,
                onSelected: (_) {},
              ),
            ),
          ),
          scale: 1.8,
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.enterText(find.byType(TextField), 'not found');
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('modal returns a command and restores focus to the launcher', (
    tester,
  ) async {
    final launcher = FocusNode();
    addTearDown(launcher.dispose);
    LiquidCommand? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              focusNode: launcher,
              onPressed: () async {
                result = await showLiquidCommandPalette(
                  context: context,
                  commands: _commands,
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    launcher.requestFocus();
    await tester.pump();
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(_row('open'));
    await tester.pumpAndSettle();
    expect(result?.id, 'open');
    expect(find.byType(LiquidCommandPalette), findsNothing);
    expect(launcher.hasFocus, isTrue);
  });

  testWidgets(
    'an opening modal can reverse into its launcher without a clip jump',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showLiquidCommandPalette(
                  context: context,
                  commands: _commands,
                  origin: const Rect.fromLTWH(100, 100, 180, 48),
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 110));
      final RenderLiquidMorph morph = tester.renderObject(
        find.byType(LiquidMorph),
      );
      final Rect? before = morph.debugClipRect;
      expect(before, isNotNull);
      // Reverse from the system back action before entry has completed.
      await tester.binding.handlePopRoute();
      await tester.pump();
      if (find.byType(LiquidMorph).evaluate().isNotEmpty) {
        expect(
          tester
              .renderObject<RenderLiquidMorph>(find.byType(LiquidMorph))
              .debugClipRect,
          before,
        );
      }
      await tester.pumpAndSettle();
      expect(find.byType(LiquidCommandPalette), findsNothing);
    },
  );
}
