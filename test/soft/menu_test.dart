import 'package:fluid_glass/fluid_glass.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'surface.dart';

Widget _app(Widget child, {bool dark = false, bool reduceMotion = false}) {
  final SoftThemeData theme = dark
      ? const SoftThemeData.dark()
      : const SoftThemeData.light();
  return WidgetsApp(
    color: const Color(0xFF000000),
    debugShowCheckedModeBanner: false,
    pageRouteBuilder: <T>(RouteSettings settings, WidgetBuilder builder) =>
        PageRouteBuilder<T>(
          settings: settings,
          pageBuilder:
              (
                BuildContext context,
                Animation<double> animation,
                Animation<double> secondary,
              ) => builder(context),
        ),
    builder: (BuildContext context, Widget? navigator) {
      return MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: reduceMotion),
        child: SoftTheme(
          data: theme,
          child: DefaultTextStyle(
            style: theme.textStyles.body1.copyWith(
              color: theme.colors.onBackground,
            ),
            child: navigator!,
          ),
        ),
      );
    },
    home: ColoredBox(
      color: theme.colors.surface,
      child: Align(
        alignment: Alignment.topCenter,
        child: Padding(padding: const EdgeInsets.only(top: 120), child: child),
      ),
    ),
  );
}

void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(1200, 2400);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}

Finder _inPopup(String text) => find.descendant(
  of: find.byType(SoftListPopupColumn),
  matching: find.text(text),
);

Color? _textColor(WidgetTester tester, Finder text) {
  final RichText rich = tester.widget<RichText>(
    find.descendant(of: text, matching: find.byType(RichText)).first,
  );
  return rich.text.style?.color;
}

Future<void> _settle(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 16));
  await tester.pump(const Duration(seconds: 1));
}

Future<void> _closeAndSettle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(
    SoftListPopupDefaults.exitDuration + const Duration(milliseconds: 50),
  );
  await tester.pump(const Duration(milliseconds: 500));
}

class _Picker extends StatefulWidget {
  const _Picker({this.enabled = true, this.onExpanded, this.onSelected});

  final bool enabled;
  final ValueChanged<bool>? onExpanded;
  final ValueChanged<int>? onSelected;

  @override
  State<_Picker> createState() => _PickerState();
}

class _PickerState extends State<_Picker> {
  int selected = 0;

  @override
  Widget build(BuildContext context) {
    return SoftDropdownPreference.items(
      title: 'Title',
      items: const <String>['Apple', 'Banana', 'Cherry', 'Durian'],
      selectedIndex: selected,
      enabled: widget.enabled,
      onExpandedChange: widget.onExpanded,
      onSelectedIndexChange: (int i) {
        widget.onSelected?.call(i);
        setState(() => selected = i);
      },
    );
  }
}

class _Grouped extends StatefulWidget {
  const _Grouped();

  @override
  State<_Grouped> createState() => _GroupedState();
}

class _GroupedState extends State<_Grouped> {
  int first = 0;
  int second = 0;

  @override
  Widget build(BuildContext context) {
    return SoftDropdownPreference(
      title: 'Grouped',
      collapseOnSelection: false,
      entries: <SoftDropdownEntry>[
        SoftDropdownEntry(
          title: 'Header',
          items: <SoftDropdownItem>[
            for (int i = 0; i < 2; i++)
              SoftDropdownItem(
                text: 'A$i',
                selected: first == i,
                onTap: () => setState(() => first = i),
              ),
          ],
        ),
        SoftDropdownEntry(
          items: <SoftDropdownItem>[
            for (int i = 0; i < 3; i++)
              SoftDropdownItem(
                text: 'B$i',
                selected: second == i,
                enabled: i != 2,
                alert: i == 1,
                onTap: () => setState(() => second = i),
              ),
          ],
        ),
      ],
    );
  }
}

void main() {
  usePhoneSurface();

  group('positioners', () {
    const Rect window = Rect.fromLTRB(0, 40, 400, 760);
    const SoftPopupPositioner dropdown = SoftPopupPositioner.dropdown;
    final EdgeInsets margin = dropdown.margins;

    Offset place(Rect anchor, Size popup) => dropdown.position(
      anchor: anchor,
      window: window,
      textDirection: TextDirection.ltr,
      popupSize: popup,
      margin: margin,
      alignment: SoftPopupAlign.end,
    );

    test('dropdown opens below, centred, 8 under the anchor', () {
      final Offset p = place(
        const Rect.fromLTWH(150, 100, 100, 40),
        const Size(200, 300),
      );
      expect(p, const Offset(100, 148));
    });

    test('dropdown flips above when there is no room below', () {
      final Offset p = place(
        const Rect.fromLTWH(150, 600, 100, 40),
        const Size(200, 300),
      );
      expect(p.dy, 600 - 300 - 8);
    });

    test('dropdown falls back to the window top when neither fits', () {
      final Offset p = place(
        const Rect.fromLTWH(150, 380, 100, 40),
        const Size(200, 600),
      );
      expect(p.dy, 48);
    });

    test('a point anchor drops the gap and clamps into the margins', () {
      final Offset p = place(
        Rect.fromLTWH(390, 200, 0, 0),
        const Size(200, 100),
      );
      expect(p, const Offset(400 - 16 - 200, 200));
    });

    test('context menu hangs from the anchor corner', () {
      final Offset p = SoftPopupPositioner.contextMenu.position(
        anchor: const Rect.fromLTWH(100, 100, 50, 50),
        window: window,
        textDirection: TextDirection.ltr,
        popupSize: const Size(120, 80),
        margin: EdgeInsets.zero,
        alignment: SoftPopupAlign.topEnd,
      );
      expect(p, const Offset(150 - 120, 150));
      final Offset rtl = SoftPopupPositioner.contextMenu.position(
        anchor: const Rect.fromLTWH(100, 100, 50, 50),
        window: window,
        textDirection: TextDirection.rtl,
        popupSize: const Size(120, 80),
        margin: EdgeInsets.zero,
        alignment: SoftPopupAlign.topEnd,
      );
      expect(rtl, const Offset(100, 150));
    });
  });

  group('gravity path', () {
    test('starts at the anchor, ends at the centre and sags downwards', () {
      final SoftGravityPath path = SoftGravityPath.between(
        const Offset(-120, -160),
        Offset.zero,
        dMin: 10,
        dMax: 133,
        gMax: 43,
      );
      expect(path.pointAt(0), const Offset(-120, -160));
      expect(path.pointAt(1), Offset.zero);
      // The chord runs down-right; the sag pushes the middle below it.
      final Offset mid = path.pointAt(0.5);
      expect(mid.dy, greaterThan(-80));
    });

    test('a short or axis-aligned chord does not sag', () {
      final SoftGravityPath short = SoftGravityPath.between(
        const Offset(0, -0.5),
        Offset.zero,
        dMin: 10,
        dMax: 133,
        gMax: 43,
      );
      expect(short.pointAt(0.5).dx, 0);
      expect(
        SoftGravityPath.adaptiveGravity(
          0,
          200,
          200,
          dMin: 10,
          dMax: 133,
          gMax: 43,
        ),
        0,
      );
    });
  });

  for (final bool dark in <bool>[false, true]) {
    final String mode = dark ? 'dark' : 'light';
    final SoftColors colors = dark
        ? const SoftColors.dark()
        : const SoftColors.light();

    group('SoftDropdownPreference ($mode)', () {
      testWidgets('lays out the row and opens the popup at the finger', (
        WidgetTester tester,
      ) async {
        _phone(tester);
        await tester.pumpWidget(_app(const _Picker(), dark: dark));
        expect(find.text('Title'), findsOneWidget);
        // The selected value sits before the arrow.
        expect(find.text('Apple'), findsOneWidget);
        expect(find.byType(SoftDropdownArrow), findsOneWidget);
        expect(
          tester.getSize(find.byType(SoftDropdownArrow)),
          SoftDropdownDefaults.arrowSize,
        );

        final Offset tap = tester.getCenter(find.text('Title'));
        await tester.tapAt(tap);
        await _settle(tester);

        expect(find.byType(SoftListPopupColumn), findsOneWidget);
        final Rect panel = tester.getRect(find.byType(SoftListPopupColumn));
        expect(panel.width, inInclusiveRange(168, 256));
        // Point anchored: no gap, centred on the finger (clamped).
        expect(panel.top, moreOrLessEquals(tap.dy, epsilon: 0.5));
        expect(panel.left, greaterThanOrEqualTo(16));
        // Four 40-high rows plus 8 above and below.
        expect(panel.height, moreOrLessEquals(4 * 40 + 16, epsilon: 0.5));
        expect(
          tester.getSize(find.byType(SoftDropdownRow).first).height,
          SoftDropdownDefaults.itemMinHeight,
        );

        // The panel is the theme's popup surface.
        final SoftGlass glass = tester.widget<SoftGlass>(
          find.descendant(
            of: find.byType(SoftTouchMotion),
            matching: find.byType(SoftGlass),
          ),
        );
        expect(
          glass.color,
          dark
              ? SoftListPopupDefaults.surfaceDark
              : SoftListPopupDefaults.surfaceLight,
        );
        expect(glass.size, SoftGlassSize.panel);

        // The selected title is primary, the others the label colour.
        expect(_textColor(tester, _inPopup('Apple')), colors.primary);
        expect(
          _textColor(tester, _inPopup('Banana')),
          colors.onSurfaceContainer,
        );

        // Nothing animates once the popup has settled.
        expect(tester.binding.hasScheduledFrame, isFalse);
      });

      testWidgets('tapping an option selects it and closes the popup', (
        WidgetTester tester,
      ) async {
        _phone(tester);
        final List<bool> expanded = <bool>[];
        final List<int> picked = <int>[];
        await tester.pumpWidget(
          _app(
            _Picker(onExpanded: expanded.add, onSelected: picked.add),
            dark: dark,
          ),
        );
        await tester.tap(find.text('Title'));
        await _settle(tester);
        expect(expanded, <bool>[true]);

        await tester.tap(_inPopup('Cherry'));
        await _closeAndSettle(tester);
        expect(picked, <int>[2]);
        expect(expanded, <bool>[true, false]);
        expect(find.byType(SoftListPopupColumn), findsNothing);
        expect(find.text('Cherry'), findsOneWidget);
        // The springs still settling after the popup has gone stop on
        // their own: nothing keeps ticking.
        await tester.pump(const Duration(seconds: 1));
        expect(tester.binding.hasScheduledFrame, isFalse);
      });

      testWidgets('dragging moves the selection to the row released over', (
        WidgetTester tester,
      ) async {
        _phone(tester);
        final List<int> picked = <int>[];
        await tester.pumpWidget(
          _app(_Picker(onSelected: picked.add), dark: dark),
        );
        await tester.tap(find.text('Title'));
        await _settle(tester);

        final TestGesture gesture = await tester.startGesture(
          tester.getCenter(_inPopup('Banana')),
        );
        await tester.pump(const Duration(milliseconds: 100));
        await gesture.moveTo(tester.getCenter(_inPopup('Cherry')));
        await tester.pump(const Duration(milliseconds: 100));
        await gesture.moveTo(tester.getCenter(_inPopup('Durian')));
        await tester.pump(const Duration(milliseconds: 100));
        await gesture.up();
        await _closeAndSettle(tester);
        expect(picked, <int>[3]);
      });

      testWidgets('tapping outside dismisses without selecting', (
        WidgetTester tester,
      ) async {
        _phone(tester);
        final List<int> picked = <int>[];
        final List<bool> expanded = <bool>[];
        await tester.pumpWidget(
          _app(
            _Picker(onSelected: picked.add, onExpanded: expanded.add),
            dark: dark,
          ),
        );
        await tester.tap(find.text('Title'));
        await _settle(tester);
        await tester.tapAt(const Offset(10, 780));
        await _closeAndSettle(tester);
        expect(find.byType(SoftListPopupColumn), findsNothing);
        expect(picked, isEmpty);
        expect(expanded, <bool>[true, false]);
      });

      testWidgets('a disabled row does not open', (WidgetTester tester) async {
        _phone(tester);
        await tester.pumpWidget(
          _app(const _Picker(enabled: false), dark: dark),
        );
        await tester.tap(find.text('Title'));
        await _settle(tester);
        expect(find.byType(SoftListPopupColumn), findsNothing);
        expect(
          _textColor(tester, find.text('Title')),
          colors.disabledOnSecondaryVariant,
        );
      });

      testWidgets('groups: header, divider band, alert, disabled, stays open', (
        WidgetTester tester,
      ) async {
        _phone(tester);
        await tester.pumpWidget(_app(const _Grouped(), dark: dark));
        await tester.tap(find.text('Grouped'));
        await _settle(tester);

        final Rect header = tester.getRect(find.byType(SoftDropdownHeader));
        expect(header.height, SoftDropdownDefaults.headerMinHeight);
        final Rect a1 = tester.getRect(
          find.ancestor(
            of: _inPopup('A1'),
            matching: find.byType(SoftDropdownRow),
          ),
        );
        final Rect b0 = tester.getRect(
          find.ancestor(
            of: _inPopup('B0'),
            matching: find.byType(SoftDropdownRow),
          ),
        );
        // One 12 band between the groups, none inside a group.
        expect(b0.top - a1.bottom, SoftPopupListDefaults.dividerBandHeight);
        expect(find.byType(SoftPopupListDivider), findsOneWidget);

        expect(_textColor(tester, _inPopup('B1')), colors.error);
        expect(
          _textColor(tester, _inPopup('B2')),
          colors.disabledOnSecondaryVariant,
        );
        expect(
          _textColor(tester, find.text('Header')),
          colors.onSurfaceSecondary,
        );

        // A disabled option ignores the tap.
        await tester.tap(_inPopup('B2'));
        await tester.pump(const Duration(milliseconds: 100));
        expect(
          _textColor(tester, _inPopup('B2')),
          colors.disabledOnSecondaryVariant,
        );

        // A grouped popup stays open and follows the selection.
        await tester.tap(_inPopup('A1'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        expect(find.byType(SoftListPopupColumn), findsOneWidget);
        expect(_textColor(tester, _inPopup('A1')), colors.primary);
        expect(_textColor(tester, _inPopup('A0')), colors.onSurfaceContainer);
        await tester.pump(const Duration(seconds: 1));
        expect(tester.binding.hasScheduledFrame, isFalse);
      });
    });
  }

  testWidgets('a menu row opens under its end side', (
    WidgetTester tester,
  ) async {
    _phone(tester);
    await tester.pumpWidget(
      _app(
        SoftDropdownMenu(
          title: 'Menu',
          entries: <SoftDropdownEntry>[
            SoftDropdownEntry(
              items: <SoftDropdownItem>[
                SoftDropdownItem(text: 'One', onTap: () {}),
                SoftDropdownItem(text: 'Two', onTap: () {}),
              ],
            ),
          ],
        ),
      ),
    );
    final Rect arrow = tester.getRect(find.byType(SoftDropdownArrow));
    await tester.tap(find.text('Menu'));
    await _settle(tester);
    final Rect panel = tester.getRect(find.byType(SoftListPopupColumn));
    expect(panel.top, moreOrLessEquals(arrow.bottom + 8, epsilon: 0.5));
    expect(panel.right, lessThanOrEqualTo(400 - 16 + 0.5));
  });

  testWidgets('a long list is capped and scrolls instead of selecting', (
    WidgetTester tester,
  ) async {
    _phone(tester);
    final List<String> tapped = <String>[];
    await tester.pumpWidget(
      _app(
        Builder(
          builder: (BuildContext context) => GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => showSoftPopupMenu(
              context: context,
              maxHeight: 300,
              entries: <SoftDropdownEntry>[
                SoftDropdownEntry(
                  items: <SoftDropdownItem>[
                    for (int i = 0; i < 30; i++)
                      SoftDropdownItem(
                        text: 'Row $i',
                        onTap: () => tapped.add('Row $i'),
                      ),
                  ],
                ),
              ],
            ),
            child: const SizedBox(width: 100, height: 40),
          ),
        ),
      ),
    );
    await tester.tap(find.byType(GestureDetector).first);
    await _settle(tester);
    final Rect panel = tester.getRect(find.byType(SoftListPopupColumn));
    expect(panel.height, 300);

    final ScrollableState scrollable = tester.state<ScrollableState>(
      find.descendant(
        of: find.byType(SoftListPopupColumn),
        matching: find.byType(Scrollable),
      ),
    );
    await tester.drag(_inPopup('Row 3'), const Offset(0, -120));
    await tester.pump(const Duration(seconds: 1));
    expect(scrollable.position.pixels, greaterThan(0));
    expect(tapped, isEmpty);
    expect(find.byType(SoftListPopupColumn), findsOneWidget);
  });

  testWidgets('reduced motion shows and hides the popup at once', (
    WidgetTester tester,
  ) async {
    _phone(tester);
    await tester.pumpWidget(_app(const _Picker(), reduceMotion: true));
    await tester.tap(find.text('Title'));
    await tester.pump();
    await tester.pump();
    expect(find.byType(SoftListPopupColumn), findsOneWidget);
    expect(tester.binding.hasScheduledFrame, isFalse);
    await tester.tap(_inPopup('Banana'));
    await tester.pump();
    await tester.pump();
    expect(find.byType(SoftListPopupColumn), findsNothing);
  });

  testWidgets('rows expose selection semantics', (WidgetTester tester) async {
    _phone(tester);
    final SemanticsHandle handle = tester.ensureSemantics();
    await tester.pumpWidget(_app(const _Picker()));
    await tester.tap(find.text('Title'));
    await _settle(tester);
    expect(
      tester.getSemantics(
        find.ancestor(
          of: _inPopup('Apple'),
          matching: find.byType(SoftDropdownRow),
        ),
      ),
      matchesSemantics(
        label: 'Apple',
        isChecked: true,
        hasCheckedState: true,
        isSelected: true,
        hasSelectedState: true,
        isInMutuallyExclusiveGroup: true,
        isEnabled: true,
        hasEnabledState: true,
        hasTapAction: true,
      ),
    );
    handle.dispose();
  });
}
