import 'package:fluid_glass/fluid_glass.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

// The example is a separate package, exercised here with the library's tests.
// ignore: avoid_relative_lib_imports
import '../../example/lib/soft_demo/motion_section.dart';

void main() {
  for (final bool dark in <bool>[false, true]) {
    testWidgets('motion demo presets and loading controls (dark: $dark)', (
      tester,
    ) async {
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(size: Size(400, 800)),
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: SoftTheme(
              data: dark
                  ? const SoftThemeData.dark()
                  : const SoftThemeData.light(),
              child: const Center(
                child: SizedBox(
                  width: 400,
                  child: SingleChildScrollView(child: SoftMotionSection()),
                ),
              ),
            ),
          ),
        ),
      );
      for (final String name in <String>['圆形', '弹层', '圆角矩形', '胶囊']) {
        await tester.ensureVisible(find.text(name));
        await tester.tap(find.text(name));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
      await tester.ensureVisible(find.text('加载动效'));
      await tester.tap(find.text('加载动效'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(
        tester.widget<SoftSwitch>(find.byType(SoftSwitch)).isLoading,
        isTrue,
      );
      await tester.ensureVisible(find.text('减少动画：关'));
      await tester.tap(find.text('减少动画：关'));
      await tester.pumpAndSettle();
      expect(find.text('减少动画：开'), findsOneWidget);
      expect(tester.binding.hasScheduledFrame, isFalse);
      await tester.tap(find.text('结束加载'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<SoftSwitch>(find.byType(SoftSwitch)).isLoading,
        isFalse,
      );
      expect(tester.takeException(), isNull);
    });
  }
}
