import 'package:fluid_glass/fluid_glass.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(Widget child) => MaterialApp(
  home: Scaffold(
    body: Center(child: SizedBox(width: 360, child: child)),
  ),
);

enum _Plan { personal, team, studio }

const _options = <LiquidSelectOption<_Plan>>[
  LiquidSelectOption(value: _Plan.personal, label: 'Personal'),
  LiquidSelectOption(value: _Plan.team, label: 'Team', enabled: false),
  LiquidSelectOption(
    value: _Plan.studio,
    label: 'Studio',
    description: 'For larger workspaces',
  ),
];

void main() {
  testWidgets(
    'changing search debounce to zero delivers outside the parent build',
    (tester) async {
      var debounce = const Duration(milliseconds: 500);
      late StateSetter update;
      final values = <String>[];
      await tester.pumpWidget(
        _host(
          StatefulBuilder(
            builder: (context, setState) {
              update = setState;
              return LiquidSearchField(
                backdrop: emptyBackdrop,
                debounce: debounce,
                onChanged: (value) => setState(() => values.add(value)),
              );
            },
          ),
        ),
      );
      await tester.enterText(find.byType(TextField), 'latest');
      update(() => debounce = Duration.zero);
      await tester.pump();
      await tester.pump();
      expect(values, ['latest']);
      await tester.pump(const Duration(seconds: 1));
      expect(values, ['latest']);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'empty search skips the invisible clear action during Tab traversal',
    (tester) async {
      final input = FocusNode();
      final next = FocusNode();
      addTearDown(input.dispose);
      addTearDown(next.dispose);
      await tester.pumpWidget(
        _host(
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              LiquidSearchField(backdrop: emptyBackdrop, focusNode: input),
              TextButton(
                focusNode: next,
                onPressed: () {},
                child: const Text('Next action'),
              ),
            ],
          ),
        ),
      );
      input.requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      expect(next.hasPrimaryFocus, isTrue);
    },
  );

  testWidgets('text fields validate, save and reset through Form', (
    tester,
  ) async {
    final key = GlobalKey<FormState>();
    String? saved;
    await tester.pumpWidget(
      _host(
        Form(
          key: key,
          child: LiquidTextField(
            label: 'Name',
            initialValue: 'Alex',
            backdrop: emptyBackdrop,
            validator: (v) =>
                v == null || v.trim().isEmpty ? 'Name is required' : null,
            onSaved: (v) => saved = v,
          ),
        ),
      ),
    );
    await tester.enterText(find.byType(TextField), '');
    expect(key.currentState!.validate(), isFalse);
    await tester.pumpAndSettle();
    expect(find.text('Name is required'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Riley');
    expect(key.currentState!.validate(), isTrue);
    key.currentState!.save();
    expect(saved, 'Riley');
    key.currentState!.reset();
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      'Alex',
    );
  });

  testWidgets('external text controller and focus remain caller owned', (
    tester,
  ) async {
    final controller = TextEditingController(text: 'one');
    final focus = FocusNode();
    addTearDown(controller.dispose);
    addTearDown(focus.dispose);
    await tester.pumpWidget(
      _host(
        LiquidTextField(
          controller: controller,
          focusNode: focus,
          backdrop: emptyBackdrop,
        ),
      ),
    );
    await tester.enterText(find.byType(TextField), 'two');
    expect(controller.text, 'two');
    await tester.pumpWidget(const SizedBox());
    controller.text = 'three';
    focus.requestFocus();
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'read-only and disabled inputs retain text without accepting edits',
    (tester) async {
      await tester.pumpWidget(
        _host(
          Column(
            mainAxisSize: MainAxisSize.min,
            children: const <Widget>[
              LiquidTextField(
                initialValue: 'Read only',
                readOnly: true,
                backdrop: emptyBackdrop,
              ),
              LiquidTextField(
                initialValue: 'Disabled',
                enabled: false,
                backdrop: emptyBackdrop,
              ),
            ],
          ),
        ),
      );
      final fields = tester
          .widgetList<TextField>(find.byType(TextField))
          .toList();
      expect(fields.first.readOnly, isTrue);
      expect(fields.last.enabled, isFalse);
      expect(fields.last.controller!.text, 'Disabled');
    },
  );

  testWidgets('search debounces edits, flushes submit and clears once', (
    tester,
  ) async {
    final changes = <String>[];
    final submissions = <String>[];
    await tester.pumpWidget(
      _host(
        LiquidSearchField(
          backdrop: emptyBackdrop,
          debounce: const Duration(milliseconds: 250),
          onChanged: changes.add,
          onSubmitted: submissions.add,
        ),
      ),
    );
    final width = tester.getSize(find.byType(TextField)).width;
    await tester.enterText(find.byType(TextField), 'a');
    await tester.pump(const Duration(milliseconds: 100));
    await tester.enterText(find.byType(TextField), 'abc');
    await tester.pump(const Duration(milliseconds: 200));
    expect(changes, isEmpty);
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pump();
    expect(changes, <String>['abc']);
    expect(submissions, <String>['abc']);
    expect(tester.getSize(find.byType(TextField)).width, width);
    await tester.tap(find.byTooltip('Clear search'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(changes, <String>['abc', '']);
    await tester.pumpAndSettle();
  });

  testWidgets('programmatic search changes cancel stale pending work', (
    tester,
  ) async {
    final controller = TextEditingController();
    final changes = <String>[];
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      _host(
        LiquidSearchField(
          controller: controller,
          backdrop: emptyBackdrop,
          debounce: const Duration(milliseconds: 250),
          onChanged: changes.add,
        ),
      ),
    );
    await tester.enterText(find.byType(TextField), 'old');
    controller.text = 'external';
    await tester.pump(const Duration(milliseconds: 300));
    expect(changes, isEmpty);
    await tester.enterText(find.byType(TextField), 'pending');
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
    expect(changes, isEmpty);
    controller.clear();
    expect(tester.takeException(), isNull);
  });

  testWidgets('checkbox labels and keyboard each toggle once; null disables', (
    tester,
  ) async {
    final changes = <bool?>[];
    final focus = FocusNode();
    addTearDown(focus.dispose);
    await tester.pumpWidget(
      _host(
        LiquidCheckbox(
          value: false,
          label: 'Keep a copy',
          onChanged: changes.add,
          focusNode: focus,
        ),
      ),
    );
    await tester.tap(find.text('Keep a copy'));
    await tester.pumpAndSettle();
    expect(changes, <bool?>[true]);
    focus.requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pumpAndSettle();
    expect(changes, <bool?>[true, true]);
    await tester.pumpWidget(
      _host(
        const LiquidCheckbox(
          value: true,
          label: 'Keep a copy',
          onChanged: null,
        ),
      ),
    );
    await tester.tap(find.text('Keep a copy'));
    await tester.pumpAndSettle();
    expect(changes, hasLength(2));
  });

  testWidgets('tristate checkbox exposes its mixed state', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      _host(
        LiquidCheckbox(
          value: null,
          tristate: true,
          label: 'All folders',
          onChanged: (_) {},
        ),
      ),
    );
    expect(
      tester.getSemantics(find.text('All folders')),
      // Retain compatibility with the package's minimum Flutter 3.35 SDK.
      // ignore: deprecated_member_use
      containsSemantics(hasCheckedState: true, isCheckStateMixed: true),
    );
    handle.dispose();
  });

  testWidgets('generic radio group skips disabled options on keyboard', (
    tester,
  ) async {
    _Plan value = _Plan.personal;
    await tester.pumpWidget(
      _host(
        StatefulBuilder(
          builder: (context, setState) => LiquidRadioGroup<_Plan>(
            options: _options,
            value: value,
            onChanged: (v) => setState(() => value = v!),
          ),
        ),
      ),
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    expect(value, _Plan.studio);
    await tester.tap(find.text('Team'));
    await tester.pumpAndSettle();
    expect(value, _Plan.studio);
  });

  testWidgets('choice and filter chips remain controlled and can be disabled', (
    tester,
  ) async {
    final choices = <bool>[];
    final filters = <bool>[];
    await tester.pumpWidget(
      _host(
        Wrap(
          spacing: 8,
          children: <Widget>[
            LiquidChoiceChip(
              label: 'Design',
              selected: false,
              onSelected: choices.add,
            ),
            LiquidFilterChip(
              label: 'Unread',
              selected: true,
              onSelected: filters.add,
            ),
            const LiquidFilterChip(
              label: 'Unavailable',
              selected: false,
              onSelected: null,
            ),
          ],
        ),
      ),
    );
    await tester.tap(find.text('Design'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Unread'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Unavailable'));
    await tester.pumpAndSettle();
    expect(choices, <bool>[true]);
    expect(filters, <bool>[false]);
    expect(
      tester.widget<ChoiceChip>(find.byType(ChoiceChip)).selected,
      isFalse,
    );
  });

  testWidgets(
    'typed select starts at current value, skips disabled and commits once',
    (tester) async {
      _Plan value = _Plan.personal;
      int calls = 0;
      await tester.pumpWidget(
        _host(
          StatefulBuilder(
            builder: (context, setState) => LiquidSelect<_Plan>(
              label: 'Plan',
              options: _options,
              value: value,
              backdrop: emptyBackdrop,
              onChanged: (next) {
                calls++;
                setState(() => value = next!);
              },
            ),
          ),
        ),
      );
      await tester.tap(find.byType(LiquidSelect<_Plan>));
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(value, _Plan.studio);
      expect(calls, 1);
      await tester.tap(find.byType(LiquidSelect<_Plan>));
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(calls, 1);
    },
  );

  testWidgets('select cancels a choice removed while its chooser was open', (
    tester,
  ) async {
    var options = _options;
    int calls = 0;
    late StateSetter update;
    await tester.pumpWidget(
      _host(
        StatefulBuilder(
          builder: (context, setState) {
            update = setState;
            return LiquidSelect<_Plan>(
              label: 'Plan',
              options: options,
              value: _Plan.personal,
              backdrop: emptyBackdrop,
              onChanged: (_) => calls++,
            );
          },
        ),
      ),
    );
    await tester.tap(find.byType(LiquidSelect<_Plan>));
    await tester.pumpAndSettle();
    update(() => options = <LiquidSelectOption<_Plan>>[_options.first]);
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey<String>('2')).last);
    await tester.pumpAndSettle();
    expect(calls, 0);
  });

  testWidgets(
    'select FormField validates, saves and resets independently of controlled select',
    (tester) async {
      final form = GlobalKey<FormState>();
      _Plan? saved;
      await tester.pumpWidget(
        _host(
          Form(
            key: form,
            child: LiquidSelectFormField<_Plan>(
              label: 'Plan',
              options: _options,
              backdrop: emptyBackdrop,
              validator: (v) => v == null ? 'Choose a plan' : null,
              onSaved: (v) => saved = v,
            ),
          ),
        ),
      );
      expect(form.currentState!.validate(), isFalse);
      await tester.pumpAndSettle();
      expect(find.text('Choose a plan'), findsOneWidget);
      await tester.tap(find.byType(LiquidSelect<_Plan>));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey<String>('0')).last);
      await tester.pumpAndSettle();
      expect(form.currentState!.validate(), isTrue);
      form.currentState!.save();
      expect(saved, _Plan.personal);
      form.currentState!.reset();
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<LiquidSelect<_Plan>>(find.byType(LiquidSelect<_Plan>))
            .value,
        isNull,
      );
    },
  );
}
