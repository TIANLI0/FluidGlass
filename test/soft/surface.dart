import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// Runs every test of the file on a 400 × 800 logical screen, the phone the
/// tests' geometry is written for.
void usePhoneSurface({Size size = const Size(400, 800)}) {
  setUp(() {
    final TestFlutterView view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.implicitView!;
    view.physicalSize = size;
    view.devicePixelRatio = 1;
  });
  tearDown(() {
    final TestFlutterView view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.implicitView!;
    view.resetPhysicalSize();
    view.resetDevicePixelRatio();
  });
}
