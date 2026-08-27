import 'dart:io' show Platform;

/// The number of processors the OS reports, or 0 when it will not say.
int get platformProcessorCount => Platform.numberOfProcessors;

/// The ABI this process was built for — `arm64`, `arm`, `x64`, `ia32`, …
///
/// There is no direct API for it. `Platform.version` ends with the target in
/// quotes, e.g. `3.13.0 (stable) ... on "android_arm64"`, so the architecture
/// is the part after the last underscore. Returns the empty string if that
/// shape ever changes, which the classifier reads as "unknown".
String get platformArchitecture {
  final RegExpMatch? match =
      RegExp(r'on "([a-z0-9]+)_([a-z0-9]+)"').firstMatch(Platform.version);
  return match?.group(2) ?? '';
}
