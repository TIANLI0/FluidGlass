// Device facts that need `dart:io`, resolved per platform.
//
// The library declares no platform restriction, so `dart:io` cannot be
// imported directly — a web build would not compile.
export 'device_probe_stub.dart' if (dart.library.io) 'device_probe_io.dart';
