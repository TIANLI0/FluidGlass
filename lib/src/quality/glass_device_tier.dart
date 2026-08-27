import 'dart:ui' as ui;
import 'dart:ui' show Size;

import 'package:flutter/foundation.dart';

import 'device_probe.dart';
import 'glass_quality.dart';

/// Everything the built-in classifier is allowed to look at.
///
/// All of it is synchronous and available before the first frame, which is the
/// point: the tier is known when the first pixel is drawn, so nothing ever
/// changes appearance under the user.
@immutable
class GlassDeviceInfo {
  const GlassDeviceInfo({
    required this.supportsRuntimeShaders,
    required this.processorCount,
    required this.architecture,
    required this.platform,
    required this.platformVersion,
    required this.devicePixelRatio,
    required this.physicalSize,
    required this.refreshRate,
  });

  /// Reads the current device.
  factory GlassDeviceInfo.current() {
    final ui.PlatformDispatcher dispatcher = ui.PlatformDispatcher.instance;
    final ui.FlutterView? view = dispatcher.implicitView ??
        (dispatcher.views.isEmpty ? null : dispatcher.views.first);
    return GlassDeviceInfo(
      supportsRuntimeShaders: ui.ImageFilter.isShaderFilterSupported,
      processorCount: platformProcessorCount,
      architecture: platformArchitecture,
      platform: defaultTargetPlatform.name,
      platformVersion: '',
      devicePixelRatio: view?.devicePixelRatio ?? 1.0,
      physicalSize: view?.physicalSize ?? Size.zero,
      refreshRate: view?.display.refreshRate ?? 0,
    );
  }

  /// Whether `ImageFilter.shader` works here. False on Skia and on the web.
  final bool supportsRuntimeShaders;

  /// Processors the OS reports, or 0 when unknown — which must not be read as
  /// "slow".
  final int processorCount;

  /// The process ABI: `arm64`, `arm`, `x64`, `ia32`, or empty when unknown.
  final String architecture;

  /// [defaultTargetPlatform]'s name.
  final String platform;

  /// A platform version string, when the caller has one. Empty by default:
  /// `Platform.operatingSystemVersion` is a device-specific build string
  /// (`PKJ110_16.0.10.501(CN01)` on one phone) that nothing here can parse
  /// meaningfully, so it is left to an app that knows its own fleet.
  final String platformVersion;

  final double devicePixelRatio;
  final Size physicalSize;
  final double refreshRate;

  /// Pixels the compositor has to fill per second, in millions.
  ///
  /// Informational: deliberately *not* part of the built-in decision, because
  /// it moves the wrong way. A flagship has more pixels and a higher refresh
  /// rate than a budget phone and is also far better at filling them, so
  /// judging by demand alone would downgrade exactly the devices that can
  /// afford the effect.
  double get fillDemandMegapixelsPerSecond =>
      physicalSize.width * physicalSize.height * refreshRate / 1000000;

  /// Whether this is a 32-bit process.
  bool get is32Bit => architecture == 'arm' || architecture == 'ia32';

  @override
  String toString() => 'GlassDeviceInfo(shaders: $supportsRuntimeShaders, '
      'cores: $processorCount, arch: $architecture, platform: $platform, '
      'dpr: $devicePixelRatio, size: $physicalSize, hz: $refreshRate)';
}

/// Chooses a tier for a device.
typedef GlassDeviceClassifier = GlassQuality Function(GlassDeviceInfo info);

/// The [GlassQuality] this device gets, decided once from what the device is.
///
/// Deliberately **not** a running measurement. A governor that watched frame
/// times and stepped the tier up and down worked, and was the wrong idea: the
/// glass visibly changed appearance mid-session, in response to a transient
/// scroll, and a hysteresis band wide enough to stop it flapping was also wide
/// enough to leave a fast device stuck on the cheap tier. Quality is a property
/// of the device, so it is decided from the device, before the first frame, and
/// then left alone.
///
/// The classification is synchronous and available immediately — there is no
/// warm-up during which the app draws at the wrong tier. Changes propagate the
/// moment they are made: this is a [ChangeNotifier], and every glass element
/// listens to it and repaints.
///
/// What the built-in classifier looks at, in order:
///
///  1. **Runtime shader support.** Without `ImageFilter.shader` the refraction
///     and the shaded rim cannot run at all, so the tier is [GlassQuality.plain]
///     whatever else is true. This is capability, not a guess.
///  2. **A 32-bit process.** A 32-bit mobile device is entry-level or old.
///  3. **Fewer than [minimumProcessorCount] processors**, when the count is
///     known at all. Crude — core count is a poor proxy for GPU class — but it
///     is the only CPU-class signal Dart exposes without a plugin.
///
/// Anything else gets [GlassQuality.liquid].
///
/// Those three are what a Flutter app can honestly know about a device with no
/// dependencies. Model-name lookup would be more accurate and is not something
/// a rendering library should carry a database for, so if your app already
/// knows better — `device_info_plus`, remote config, a user setting — tell it:
///
/// ```dart
/// // Replace the decision wholesale.
/// GlassDeviceTier.instance.classifier = (GlassDeviceInfo info) =>
///     myDeviceIsCheap ? GlassQuality.plain : GlassQuality.liquid;
///
/// // Or just pin one.
/// GlassDeviceTier.instance.pinnedQuality = GlassQuality.plain;
/// ```
class GlassDeviceTier extends ChangeNotifier {
  GlassDeviceTier();

  static GlassDeviceTier get instance => _instance;
  static GlassDeviceTier _instance = GlassDeviceTier();

  /// Replaces the global tier. For tests.
  @visibleForTesting
  static set instance(GlassDeviceTier value) => _instance = value;

  /// Below this many processors the built-in classifier chooses
  /// [GlassQuality.plain].
  ///
  /// Six, so a big.LITTLE phone needs at least a couple of big cores to qualify.
  static const int minimumProcessorCount = 6;

  /// The built-in classification. See [GlassDeviceTier] for what it reads.
  static GlassQuality classifyDevice(GlassDeviceInfo info) {
    if (!info.supportsRuntimeShaders) return GlassQuality.plain;
    if (info.is32Bit) return GlassQuality.plain;
    if (info.processorCount > 0 &&
        info.processorCount < minimumProcessorCount) {
      return GlassQuality.plain;
    }
    return GlassQuality.liquid;
  }

  /// Replaces [classifyDevice].
  ///
  /// Setting it reclassifies immediately and notifies, so an app that learns
  /// the device model asynchronously can install a better answer at any point.
  GlassDeviceClassifier? get classifier => _classifier;
  GlassDeviceClassifier? _classifier;
  set classifier(GlassDeviceClassifier? value) {
    if (_classifier == value) return;
    final GlassQuality before = quality;
    _classifier = value;
    // Only the derived tier is stale. Installing a classifier does not change
    // what the device is, so re-reading it here would be wrong — and would
    // throw away an injected [debugInfo].
    _deviceQuality = null;
    if (quality != before) notifyListeners();
  }

  /// A tier chosen by the app, bypassing classification entirely.
  ///
  /// Still clamped by [GlassQuality.ceiling]: pinning [GlassQuality.liquid]
  /// cannot conjure a shader the backend has not got.
  GlassQuality? get pinnedQuality => _pinned;
  GlassQuality? _pinned;
  set pinnedQuality(GlassQuality? value) {
    if (_pinned == value) return;
    final GlassQuality before = quality;
    _pinned = value;
    if (quality != before) notifyListeners();
  }

  /// What the device was read as. Cached, since none of its inputs change.
  GlassDeviceInfo get info => _info ??= GlassDeviceInfo.current();
  GlassDeviceInfo? _info;

  /// The tier the classification alone chose, before clamping or pinning.
  GlassQuality get deviceQuality =>
      _deviceQuality ??= (_classifier ?? classifyDevice)(info);
  GlassQuality? _deviceQuality;

  /// The richest tier this backend can draw.
  ///
  /// Settable so a test can exercise the ladder on a backend that would
  /// otherwise pin everything to [GlassQuality.plain].
  GlassQuality get ceiling => _ceiling ?? GlassQuality.ceiling;
  GlassQuality? _ceiling;

  /// Forces [ceiling]. For tests.
  @visibleForTesting
  set debugCeiling(GlassQuality? value) {
    if (_ceiling == value) return;
    final GlassQuality before = quality;
    _ceiling = value;
    if (quality != before) notifyListeners();
  }

  /// Replaces [info]. For tests.
  ///
  /// Cannot go through [refresh], which clears the cached info in order to
  /// re-read the real device — that would discard the value being installed.
  @visibleForTesting
  set debugInfo(GlassDeviceInfo? value) {
    final GlassQuality before = quality;
    _info = value;
    _deviceQuality = null;
    if (quality != before) notifyListeners();
  }

  /// The tier glass elements draw at: pinned or classified, clamped to what the
  /// backend can do.
  GlassQuality get quality => (_pinned ?? deviceQuality).atMost(ceiling);

  /// Re-reads the device and reclassifies, notifying if the answer moved.
  ///
  /// Rarely needed — none of the inputs change during a session — but an app
  /// that installs a [classifier] later, or moves a window to a different
  /// display, can ask for a fresh answer.
  void refresh() {
    final GlassQuality before = quality;
    _info = null;
    _deviceQuality = null;
    if (quality != before) notifyListeners();
  }

  /// Why this device got this tier, for a debug readout.
  String describe() {
    if (_pinned != null) {
      return 'pinned to ${_pinned!.name}'
          '${quality != _pinned ? ', clamped to ${quality.name}' : ''}';
    }
    final GlassDeviceInfo i = info;
    if (!i.supportsRuntimeShaders) {
      return 'plain: no runtime shaders on this backend';
    }
    if (i.is32Bit) return 'plain: 32-bit process (${i.architecture})';
    if (i.processorCount > 0 && i.processorCount < minimumProcessorCount) {
      return 'plain: ${i.processorCount} cores, under $minimumProcessorCount';
    }
    if (_classifier != null) {
      return '${deviceQuality.name}: chosen by a custom classifier';
    }
    return 'liquid: shaders available, ${i.architecture.isEmpty ? "unknown arch" : i.architecture}'
        '${i.processorCount > 0 ? ", ${i.processorCount} cores" : ""}';
  }

  /// Returns everything to its initial state. For tests.
  @visibleForTesting
  void reset() {
    _pinned = null;
    _classifier = null;
    _ceiling = null;
    _info = null;
    _deviceQuality = null;
  }
}
