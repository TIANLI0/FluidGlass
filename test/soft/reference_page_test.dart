import 'package:fluid_glass/fluid_glass.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

Widget host(Widget child) => MediaQuery(
  data: const MediaQueryData(size: Size(400, 800)),
  child: Directionality(
    textDirection: TextDirection.ltr,
    child: SoftTheme(
      data: const SoftThemeData.light(),
      child: DefaultTextStyle(
        style: const TextStyle(fontSize: 17, color: Color(0xE6000000)),
        child: Center(child: SizedBox(width: 400, child: child)),
      ),
    ),
  ),
);

void main() {
  // Expectations transcribed from the pinned Kotlin source, not derived from
  // Flutter implementation constants.
  testWidgets('NumberPicker commits once after the decay and snap finish', (
    tester,
  ) async {
    final List<int> values = <int>[];
    await tester.pumpWidget(
      host(
        SoftNumberPicker(
          value: 5,
          min: 0,
          max: 100,
          haptics: false,
          onChanged: values.add,
        ),
      ),
    );
    final TestGesture finger = await tester.startGesture(
      tester.getCenter(find.byType(SoftNumberPicker)),
    );
    await finger.moveBy(const Offset(0, -20));
    await finger.moveBy(const Offset(0, -55));
    await tester.pump(const Duration(milliseconds: 16));
    expect(values, isEmpty);
    await finger.up();
    await tester.pumpAndSettle();
    expect(values.length, 1);
    expect(values.single, greaterThan(5));
  });

  testWidgets('DatePicker uses the source English month abbreviations', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        SoftDatePicker(
          value: DateTime(2026, 7, 26),
          haptics: false,
          onChanged: (_) {},
        ),
      ),
    );
    expect(find.text('Jul'), findsOneWidget);
    expect(find.text('26'), findsOneWidget);
    expect(tester.getSize(find.byType(SoftDatePicker)).height, 159);
  });

  testWidgets(
    'NotificationSnackBar uses source typography and top-end close geometry',
    (tester) async {
      await tester.pumpWidget(
        host(
          SoftNotificationSnackBar(
            title: 'Title',
            message: 'Subtitle',
            image: const SoftGlyphIcon(SoftGlyph.email),
            actionLabel: 'Open',
            onAction: () {},
            onClose: () {},
          ),
        ),
      );
      final Rect card = tester.getRect(find.byType(SoftNotificationSnackBar));
      final Finder image = find.byWidgetPredicate(
        (w) => w is SoftGlyphIcon && w.glyph == SoftGlyph.email,
      );
      final Finder close = find.byWidgetPredicate(
        (w) => w is SoftGlyphIcon && w.glyph == SoftGlyph.close,
      );
      expect(
        tester.getSize(image),
        const Size(24, 24),
      ); // scaled by its 44dp image slot.
      expect(tester.getTopLeft(find.text('Title')).dx - card.left, 68);
      expect(tester.getTopLeft(close).dy - card.top, 8);
      expect(tester.getTopLeft(close).dx - card.left, 376);
      expect(tester.getSize(close), const Size(16, 16));
      expect(tester.widget<Text>(find.text('Title')).style!.fontSize, 14);
      expect(tester.widget<Text>(find.text('Subtitle')).style!.fontSize, 11);
      expect(
        tester.widget<Text>(find.text('Open')).style!.color,
        const Color(0xFFFFFFFF),
      );
      expect(find.byType(SoftTextButton), findsNothing);
    },
  );

  Widget notification({required bool revealed}) => SoftNotificationSwipeBox(
    minHeight: 0,
    revealed: revealed,
    onRevealedChanged: (_) {},
    onSettings: () {},
    onDismiss: () {},
    settingsLabel: 'Settings',
    dismissLabel: 'Delete',
    settingsIcon: const SoftGlyphIcon(SoftGlyph.settings),
    dismissIcon: const SoftGlyphIcon(SoftGlyph.delete),
    child: const SizedBox(height: 60, child: Text('Notification')),
  );

  testWidgets(
    'compact swipe particles retain 60 by 44 menu cells with native blend reach',
    (tester) async {
      await tester.pumpWidget(host(notification(revealed: true)));
      await tester.pumpAndSettle();
      final SoftMetaBallSurface surface = tester.widget(
        find.byType(SoftMetaBallSurface),
      );
      expect(surface.particles[0].size, const Size(256, 60));
      expect(surface.particles[1].size, const Size(60, 44));
      expect(surface.particles[1].center, const Offset(366, 30));
      expect(surface.particles[2].center, const Offset(296, 30));
      expect(surface.particles.every((p) => p.alpha == 1), isTrue);
      expect(surface.extension, 3.5);
      expect(surface.extensionFactorX, 1.2);
      expect(surface.extensionFactorY, 2);
    },
  );

  testWidgets(
    'delete icon clears before settings during the first half of a swipe',
    (tester) async {
      await tester.pumpWidget(host(notification(revealed: false)));
      final TestGesture finger = await tester.startGesture(
        tester.getCenter(find.byType(SoftNotificationSwipeBox)),
      );
      await finger.moveBy(const Offset(-20, 0));
      await finger.moveBy(const Offset(-76, 0));
      await tester.pump(const Duration(milliseconds: 16));
      expect(
        find.byWidgetPredicate(
          (w) => w is SoftGlyphIcon && w.glyph == SoftGlyph.delete,
        ),
        findsOneWidget,
      );
      expect(
        find.byWidgetPredicate(
          (w) => w is SoftGlyphIcon && w.glyph == SoftGlyph.settings,
        ),
        findsNothing,
      );
      await finger.cancel();
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'icon-only horizontal block has no invented outer or row padding',
    (tester) async {
      await tester.pumpWidget(
        host(
          Center(
            child: SoftHorizontalPopupMenu(
              items: <SoftHorizontalMenuItem>[
                for (int i = 0; i < 4; i++)
                  SoftHorizontalMenuItem(
                    icon: const SoftGlyphIcon(SoftGlyph.email),
                    onPressed: () {},
                  ),
              ],
            ),
          ),
        ),
      );
      expect(
        tester.getSize(find.byType(SoftHorizontalPopupMenu)),
        const Size(208, 40),
      );
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('ExpandableList collapse follows the forward move-ease curve', (
    tester,
  ) async {
    bool expanded = true;
    await tester.pumpWidget(
      host(
        StatefulBuilder(
          builder: (context, update) => SoftExpandableGroup(
            expanded: expanded,
            onToggle: () => update(() => expanded = !expanded),
            headerBuilder: (_, _) =>
                const SizedBox(height: 48, child: Text('Toggle')),
            children: const <Widget>[
              SizedBox(height: 100, child: Text('Child')),
            ],
          ),
        ),
      ),
    );
    await tester.tap(find.text('Toggle'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    final Finder fade = find.descendant(
      of: find.byType(SoftExpandableGroup),
      matching: find.byType(Opacity),
    );
    expect(
      tester.widget<Opacity>(fade).opacity,
      closeTo(1 - const Cubic(0.3, 0, 0.1, 1).transform(0.25), 0.001),
    );
    await tester.pumpAndSettle();
  });

  testWidgets(
    'ExpandableList cap follows Kotlin minOrNull rather than set insertion order',
    (tester) async {
      Set<int>? result;
      await tester.pumpWidget(
        host(
          SizedBox(
            height: 500,
            child: SoftExpandableList(
              groupCount: 3,
              childCount: (_) => 0,
              expandedGroups: <int>{2, 0},
              maxExpandedGroups: 2,
              onExpandedGroupsChanged: (value) => result = value,
              headerBuilder: (_, index, _) =>
                  SizedBox(height: 48, child: Text('Group $index')),
              childBuilder: (_, _, _) => const SizedBox.shrink(),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Group 1'));
      expect(result, <int>{2, 1});
    },
  );
}
