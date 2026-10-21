import 'package:fluid_glass/fluid_glass.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(
  Widget child, {
  bool dark = false,
  double width = 360,
  double? height,
  EdgeInsets padding = EdgeInsets.zero,
}) {
  return MediaQuery(
    data: MediaQueryData(size: const Size(360, 800), padding: padding),
    child: Directionality(
      textDirection: TextDirection.ltr,
      child: SoftTheme(
        data: dark ? const SoftThemeData.dark() : const SoftThemeData.light(),
        child: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(width: width, height: height, child: child),
        ),
      ),
    ),
  );
}

Widget _back() => SoftTopAppBarIconButton(
  icon: const SoftBackIcon(),
  semanticLabel: 'back',
  onPressed: () {},
);

Widget _more({VoidCallback? onPressed}) => SoftTopAppBarIconButton(
  icon: const SoftMoreIcon(),
  semanticLabel: 'more',
  onPressed: onPressed ?? () {},
);

/// The bar's own surface (the first coloured box under [of]).
Size _surfaceSize(WidgetTester tester, Finder of) => tester.getSize(
  find.descendant(of: of, matching: find.byType(ColoredBox)).first,
);

void main() {
  group('SoftTopAppBar', () {
    for (final bool dark in <bool>[false, true]) {
      testWidgets('lays out the toolbar row (dark: $dark)', (
        WidgetTester tester,
      ) async {
        await tester.pumpWidget(
          _host(
            dark: dark,
            SoftTopAppBar(
              title: 'Title',
              navigationIcon: _back(),
              actions: <Widget>[_more()],
            ),
          ),
        );
        expect(tester.getSize(find.byType(SoftTopAppBar)).height, 52);
        // 16 padding + 40 key + 10 gap.
        expect(tester.getTopLeft(find.text('Title')).dx, 66);
        expect(
          tester.getTopRight(find.byType(SoftTopAppBarIconButton).last).dx,
          360 - 16,
        );
        final ColoredBox surface = tester.widget<ColoredBox>(
          find
              .descendant(
                of: find.byType(SoftTopAppBar),
                matching: find.byType(ColoredBox),
              )
              .first,
        );
        expect(
          surface.color,
          dark
              ? const SoftColors.dark().surface
              : const SoftColors.light().surface,
        );
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('starts the title at the padding without a key', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_host(const SoftTopAppBar(title: 'Title')));
      expect(tester.getTopLeft(find.text('Title')).dx, 16);
    });

    testWidgets('grows for a subtitle stack', (WidgetTester tester) async {
      await tester.pumpWidget(
        _host(const SoftTopAppBar(title: 'Title', subtitle: 'Sub')),
      );
      final double titleH = tester.getSize(find.text('Title')).height;
      final double subH = tester.getSize(find.text('Sub')).height;
      final double gap =
          tester.getTopLeft(find.text('Sub')).dy -
          tester.getBottomLeft(find.text('Title')).dy;
      expect(gap, closeTo(3.5, 0.01));
      expect(
        tester.getSize(find.byType(SoftTopAppBar)).height,
        closeTo(
          (titleH + 3.5 + subH + 8) > 52 ? titleH + 3.5 + subH + 8 : 52,
          0.01,
        ),
      );
    });

    testWidgets('centres the title', (WidgetTester tester) async {
      await tester.pumpWidget(
        _host(
          SoftTopAppBar(
            title: 'Centre',
            centerTitle: true,
            navigationIcon: _back(),
            actions: <Widget>[_more()],
          ),
        ),
      );
      expect(tester.getCenter(find.text('Centre')).dx, closeTo(180, 0.5));
    });

    testWidgets('keeps clear of the status bar', (WidgetTester tester) async {
      await tester.pumpWidget(
        _host(
          padding: const EdgeInsets.only(top: 24),
          const SoftTopAppBar(title: 'Title'),
        ),
      );
      expect(tester.getSize(find.byType(SoftTopAppBar)).height, 52 + 24);
    });

    testWidgets('fades the gradient glass in with the scroll', (
      WidgetTester tester,
    ) async {
      final ScrollController controller = ScrollController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        _host(
          height: 500,
          Column(
            children: <Widget>[
              SoftTopAppBar(
                title: 'Glass',
                gradientGlass: true,
                scrollController: controller,
              ),
              Expanded(
                child: ListView.builder(
                  controller: controller,
                  itemCount: 50,
                  itemBuilder: (BuildContext context, int i) =>
                      SizedBox(height: 40, child: Text('row $i')),
                ),
              ),
            ],
          ),
        ),
      );
      FadeTransition fade() => tester.widget<FadeTransition>(
        find.descendant(
          of: find.byType(SoftTopAppBar),
          matching: find.byType(FadeTransition),
        ),
      );
      expect(fade().opacity.value, 0);
      controller.jumpTo(15);
      await tester.pump();
      expect(fade().opacity.value, closeTo(0.5, 1e-6));
      controller.jumpTo(100);
      await tester.pump();
      expect(fade().opacity.value, 1);
    });

    testWidgets('paints the uniform glass over a blur', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _host(dark: true, const SoftTopAppBar(title: 'Glass', blur: true)),
      );
      expect(
        find.descendant(
          of: find.byType(SoftTopAppBar),
          matching: find.byType(BackdropFilter),
        ),
        findsOneWidget,
      );
      final ColoredBox tint = tester.widget<ColoredBox>(
        find.descendant(
          of: find.byType(BackdropFilter),
          matching: find.byType(ColoredBox),
        ),
      );
      expect(tint.color.a, closeTo(0.6, 1e-3));
    });
  });

  group('SoftLargeTopAppBar', () {
    Widget page({bool dark = false, bool glass = false}) => _host(
      dark: dark,
      height: 600,
      CustomScrollView(
        slivers: <Widget>[
          SoftLargeTopAppBar(
            title: 'Settings',
            navigationIcon: _back(),
            actions: <Widget>[_more()],
            gradientGlass: glass,
          ),
          SliverList.builder(
            itemCount: 60,
            itemBuilder: (BuildContext context, int i) =>
                SizedBox(height: 48, child: Text('row $i')),
          ),
        ],
      ),
    );

    double barHeight(WidgetTester tester) =>
        _surfaceSize(tester, find.byType(SoftLargeTopAppBar)).height;

    for (final bool dark in <bool>[false, true]) {
      testWidgets('expands to 110 with the large title at 54 (dark: $dark)', (
        WidgetTester tester,
      ) async {
        await tester.pumpWidget(page(dark: dark));
        expect(barHeight(tester), 110);
        // The morphing title, then the collapsed one.
        final Finder titles = find.text('Settings');
        expect(titles, findsNWidgets(2));
        expect(tester.getTopLeft(titles.last).dy, 54);
        expect(tester.getTopLeft(titles.last).dx, 16);
      });
    }

    testWidgets('collapses into the toolbar row as the content scrolls', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(page());
      final ScrollPosition position = tester
          .state<ScrollableState>(find.byType(Scrollable))
          .position;
      position.jumpTo(200);
      await tester.pump();
      expect(barHeight(tester), 52);
      // The collapsed title sits after the back key.
      expect(tester.getTopLeft(find.text('Settings').first).dx, 66);
      position.jumpTo(0);
      await tester.pump();
      expect(barHeight(tester), 110);
    });

    testWidgets('snaps a half-collapsed bar to the nearer end', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(page());
      await tester.timedDrag(
        find.text('row 3'),
        const Offset(0, -40),
        const Duration(milliseconds: 800),
      );
      await tester.pumpAndSettle();
      expect(barHeight(tester), 52);
      await tester.timedDrag(
        find.text('row 3'),
        const Offset(0, 40),
        const Duration(milliseconds: 800),
      );
      await tester.pumpAndSettle();
      expect(barHeight(tester), 110);
      expect(tester.binding.hasScheduledFrame, isFalse);
    });

    testWidgets('fades the gradient glass in after the collapse', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(page(glass: true));
      FadeTransition fade() => tester.widget<FadeTransition>(
        find.descendant(
          of: find.byType(SoftLargeTopAppBar),
          matching: find.byType(FadeTransition),
        ),
      );
      final ScrollPosition position = tester
          .state<ScrollableState>(find.byType(Scrollable))
          .position;
      expect(fade().opacity.value, 0);
      position.jumpTo(58);
      await tester.pump();
      expect(fade().opacity.value, 0);
      position.jumpTo(58 + 15);
      await tester.pump();
      expect(fade().opacity.value, closeTo(0.5, 1e-6));
    });
  });

  group('SoftTopAppBarIconButton', () {
    testWidgets('fires on tap and settles', (WidgetTester tester) async {
      int taps = 0;
      await tester.pumpWidget(
        _host(Center(child: _more(onPressed: () => taps++))),
      );
      expect(tester.getSize(find.byType(SoftTopAppBarIconButton)).width, 40);
      final TestGesture gesture = await tester.startGesture(
        tester.getCenter(find.byType(SoftTopAppBarIconButton)),
      );
      await tester.pump(const Duration(milliseconds: 400));
      await gesture.up();
      await tester.pumpAndSettle();
      expect(taps, 1);
      await tester.tap(find.byType(SoftTopAppBarIconButton));
      await tester.pumpAndSettle();
      expect(taps, 2);
      expect(tester.binding.hasScheduledFrame, isFalse);
      expect(find.bySemanticsLabel('more'), findsOneWidget);
    });
  });

  group('SoftTabRow', () {
    Widget row(
      int selected,
      ValueChanged<int> onSelected, {
      bool dark = false,
      bool contour = false,
      List<String> tabs = const <String>['Day', 'Week', 'Month'],
      double width = 300,
    }) => _host(
      dark: dark,
      width: width,
      contour
          ? SoftTabRow.contour(
              tabs: tabs,
              selectedIndex: selected,
              onTabSelected: onSelected,
            )
          : SoftTabRow(
              tabs: tabs,
              selectedIndex: selected,
              onTabSelected: onSelected,
            ),
    );

    for (final bool dark in <bool>[false, true]) {
      testWidgets('shares the width out (dark: $dark)', (
        WidgetTester tester,
      ) async {
        await tester.pumpWidget(row(0, (_) {}, dark: dark, contour: true));
        expect(tester.getSize(find.byType(SoftTabRow)), const Size(300, 40));
        // 300 - 2 × 4 inset, shared by three short labels.
        final double first = tester.getCenter(find.text('Day')).dx;
        final double second = tester.getCenter(find.text('Week')).dx;
        expect(second - first, closeTo((300 - 8) / 3, 0.5));
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('selects on tap and the indicator settles', (
      WidgetTester tester,
    ) async {
      int selected = 0;
      await tester.pumpWidget(row(selected, (int i) => selected = i));
      await tester.tap(find.text('Month'));
      expect(selected, 2);
      await tester.pumpWidget(row(selected, (int i) => selected = i));
      await tester.pump(const Duration(milliseconds: 16));
      expect(tester.binding.hasScheduledFrame, isTrue);
      await tester.pumpAndSettle();
      expect(tester.binding.hasScheduledFrame, isFalse);
      final Text month = tester.widget<Text>(find.text('Month'));
      expect(month.style?.fontWeight, FontWeight.w500);
      final Text day = tester.widget<Text>(find.text('Day'));
      expect(day.style?.fontWeight, FontWeight.w400);
    });

    testWidgets('the tiny form is 32 high', (WidgetTester tester) async {
      await tester.pumpWidget(
        _host(
          SoftTabRow.contour(
            tabs: const <String>['Photo', 'Video'],
            selectedIndex: 0,
            onTabSelected: (_) {},
            height: SoftTabRowDefaults.tinyHeight,
            cornerRadius: SoftTabRowDefaults.tinyCornerRadius,
            contourPadding: SoftTabRowDefaults.tinyContourPadding,
          ),
        ),
      );
      expect(tester.getSize(find.byType(SoftTabRow)).height, 32);
    });

    testWidgets('scrolls sideways when the labels overflow, without '
        'scrolling the page', (WidgetTester tester) async {
      final List<String> many = <String>[
        for (int i = 0; i < 8; i++) 'Long label $i',
      ];
      final ScrollController page = ScrollController();
      addTearDown(page.dispose);
      await tester.pumpWidget(
        _host(
          width: 200,
          height: 400,
          ListView(
            controller: page,
            children: <Widget>[
              SoftTabRow(tabs: many, selectedIndex: 0, onTabSelected: (_) {}),
              const SizedBox(height: 2000),
            ],
          ),
        ),
      );
      final Finder inner = find.descendant(
        of: find.byType(SoftTabRow),
        matching: find.byType(Scrollable),
      );
      final ScrollPosition position = tester
          .state<ScrollableState>(inner)
          .position;
      expect(position.maxScrollExtent, greaterThan(0));
      await tester.drag(find.text('Long label 0'), const Offset(-120, -6));
      await tester.pumpAndSettle();
      expect(position.pixels, greaterThan(0));
      expect(page.offset, 0);
    });

    testWidgets('a row that fits does not take sideways drags', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(row(0, (_) {}));
      final Finder inner = find.descendant(
        of: find.byType(SoftTabRow),
        matching: find.byType(Scrollable),
      );
      final ScrollableState scrollable = tester.state<ScrollableState>(inner);
      expect(scrollable.widget.physics, isA<NeverScrollableScrollPhysics>());
    });
  });

  group('SoftChipTabGroup', () {
    List<SoftChipTabData> tabs() => const <SoftChipTabData>[
      SoftChipTabData(label: 'Inbox', showRedDot: true),
      SoftChipTabData(label: 'Updates', count: 12),
      SoftChipTabData(label: 'Archived', count: 128, showRedDot: true),
      SoftChipTabData(label: 'Unavailable', enabled: false),
      SoftChipTabData(label: 'Spam'),
    ];

    Widget group(
      int selected,
      ValueChanged<int> onChanged, {
      bool dark = false,
      double width = 360,
    }) => _host(
      dark: dark,
      width: width,
      SoftChipTabGroup(
        tabs: tabs(),
        selectedIndex: selected,
        onSelectedChange: onChanged,
      ),
    );

    for (final bool dark in <bool>[false, true]) {
      testWidgets('lays out 32 pills 8 apart (dark: $dark)', (
        WidgetTester tester,
      ) async {
        await tester.pumpWidget(group(0, (_) {}, dark: dark, width: 1200));
        final Finder pills = find.byType(SoftChipTab);
        expect(tester.getSize(pills.first).height, 32);
        expect(
          tester.getTopLeft(pills.at(1)).dx -
              tester.getTopRight(pills.at(0)).dx,
          8,
        );
        expect(find.text('128'), findsOneWidget);
        expect(find.byType(SoftBadge), findsNWidgets(2));
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('selects on tap; a disabled tab does not', (
      WidgetTester tester,
    ) async {
      final List<int> picked = <int>[];
      await tester.pumpWidget(group(0, picked.add, width: 1200));
      await tester.tap(find.text('Spam'));
      await tester.tap(find.text('Unavailable'));
      expect(picked, <int>[4]);
      await tester.pumpWidget(group(4, picked.add, width: 1200));
      await tester.pump(const Duration(milliseconds: 16));
      expect(tester.binding.hasScheduledFrame, isTrue);
      await tester.pumpAndSettle();
      expect(tester.binding.hasScheduledFrame, isFalse);
    });

    testWidgets('fades the edge it can scroll to and scrolls a cut tab in', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(group(0, (_) {}, width: 200));
      await tester.pump();
      expect(tester.layers.whereType<ShaderMaskLayer>(), isNotEmpty);
      final ScrollPosition position = tester
          .state<ScrollableState>(find.byType(Scrollable))
          .position;
      expect(position.pixels, 0);
      // 'Updates' straddles the right edge of a 200 wide row.
      await tester.pumpWidget(group(1, (_) {}, width: 200));
      await tester.pumpAndSettle();
      expect(position.pixels, greaterThan(0));
      expect(tester.binding.hasScheduledFrame, isFalse);
    });

    testWidgets('no mask when everything fits', (WidgetTester tester) async {
      await tester.pumpWidget(group(0, (_) {}, width: 1200));
      await tester.pump();
      expect(tester.layers.whereType<ShaderMaskLayer>(), isEmpty);
    });
  });
}
