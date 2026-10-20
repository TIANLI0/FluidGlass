import 'package:fluid_glass/fluid_glass.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(Widget child, {bool still = false, double scale = 1}) =>
    MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(
          disableAnimations: still,
          textScaler: TextScaler.linear(scale),
        ),
        child: Scaffold(
          body: Center(child: SizedBox(width: 320, child: child)),
        ),
      ),
    );

void main() {
  testWidgets('settings section uses one surface and permits static rows', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        const LiquidSettingsSection(
          title: 'General',
          backdrop: emptyBackdrop,
          children: <Widget>[
            LiquidSettingsTile(title: 'Version', trailing: Text('1.0')),
            LiquidSettingsTile(title: 'Storage', subtitle: 'On this device'),
          ],
        ),
      ),
    );
    expect(find.byType(DrawBackdrop), findsOneWidget);
    await tester.tap(find.text('Version'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'switch row and knob each activate exactly once with one keyboard stop',
    (tester) async {
      int calls = 0;
      final focus = FocusNode();
      addTearDown(focus.dispose);
      await tester.pumpWidget(
        _host(
          LiquidSwitchTile(
            title: 'Alerts',
            value: false,
            backdrop: emptyBackdrop,
            focusNode: focus,
            onChanged: (_) => calls++,
          ),
        ),
      );
      await tester.tap(find.text('Alerts'));
      await tester.pumpAndSettle();
      expect(calls, 1);
      await tester.tapAt(tester.getCenter(find.byType(LiquidToggle)));
      await tester.pumpAndSettle();
      expect(calls, 2);
      focus.requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pumpAndSettle();
      expect(calls, 3);
      expect(focus.hasPrimaryFocus, isTrue);
    },
  );

  testWidgets('disabled switch has state but no semantic action', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      _host(
        const LiquidSwitchTile(
          title: 'Alerts',
          value: true,
          onChanged: null,
          backdrop: emptyBackdrop,
        ),
      ),
    );
    expect(
      tester.getSemantics(find.text('Alerts')),
      // Retain compatibility with the package's minimum Flutter 3.35 SDK.
      // ignore: deprecated_member_use
      containsSemantics(
        hasToggledState: true,
        isToggled: true,
        hasEnabledState: true,
        isEnabled: false,
        hasTapAction: false,
      ),
    );
    handle.dispose();
  });

  testWidgets(
    'slider row formats its actual range and delegates release callbacks',
    (tester) async {
      final ends = <double>[];
      await tester.pumpWidget(
        _host(
          LiquidSliderTile(
            title: 'Volume',
            value: 50,
            min: 0,
            max: 100,
            divisions: 100,
            backdrop: emptyBackdrop,
            onChanged: (_) {},
            onChangeEnd: ends.add,
          ),
        ),
      );
      expect(find.text('50%'), findsOneWidget);
      final box = tester.getRect(find.byType(LiquidSlider));
      await tester.tapAt(Offset(box.left + box.width / 4, box.center.dy));
      await tester.pumpAndSettle();
      expect(ends, <double>[25]);
    },
  );

  testWidgets('notice action and dismissal remain separate and accessible', (
    tester,
  ) async {
    int retried = 0;
    int dismissed = 0;
    await tester.pumpWidget(
      _host(
        LiquidNotice(
          title: 'Could not sync',
          message: 'Your edits are still here.',
          severity: LiquidNoticeSeverity.error,
          actionLabel: 'Retry',
          onAction: () => retried++,
          onDismiss: () => dismissed++,
        ),
      ),
    );
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Dismiss'));
    await tester.pumpAndSettle();
    expect(retried, 1);
    expect(dismissed, 1);
  });

  testWidgets('progress retargets from the current frame and becomes idle', (
    tester,
  ) async {
    Widget at(double value) =>
        _host(LiquidProgress(label: 'Upload', value: value));
    await tester.pumpWidget(at(0.1));
    await tester.pumpAndSettle();
    await tester.pumpWidget(at(0.9));
    await tester.pump(const Duration(milliseconds: 80));
    final double middle = tester
        .widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator))
        .value!;
    expect(middle, greaterThan(0.1));
    expect(middle, lessThan(0.9));
    await tester.pumpWidget(at(0.2));
    expect(
      tester
          .widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator))
          .value,
      middle,
    );
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator))
          .value,
      0.2,
    );
    expect(tester.binding.transientCallbackCount, 0);
  });

  testWidgets('indeterminate progress stays still with reduced motion', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(const LiquidProgress(label: 'Working'), still: true),
    );
    await tester.pumpAndSettle();
    expect(tester.binding.transientCallbackCount, 0);
    expect(find.byType(LinearProgressIndicator), findsNothing);
  });

  testWidgets('empty state can scroll inside a short large-text viewport', (
    tester,
  ) async {
    int calls = 0;
    await tester.pumpWidget(
      _host(
        SizedBox(
          height: 180,
          child: LiquidEmptyState(
            title: 'Nothing matched this search',
            message: 'Clear your filters to see everything.',
            actionLabel: 'Clear filters',
            onAction: () => calls++,
          ),
        ),
        scale: 1.8,
      ),
    );
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.text('Clear filters'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Clear filters'));
    await tester.pumpAndSettle();
    expect(calls, 1);
  });

  testWidgets(
    'toast uses ScaffoldMessenger queue and native action lifecycle',
    (tester) async {
      int undone = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showLiquidToast(
                  context: context,
                  title: 'Saved',
                  message: 'Preferences updated',
                  actionLabel: 'Undo',
                  onAction: () => undone++,
                ),
                child: const Text('Show'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Show'));
      await tester.pumpAndSettle();
      expect(find.byType(SnackBar), findsOneWidget);
      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();
      expect(undone, 1);
      expect(find.byType(SnackBar), findsNothing);
    },
  );
}
