import 'package:fluid_glass/fluid_glass.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../backdrop_demo_scaffold.dart';

/// The two quality tiers, side by side, and what this device was classified as.
///
/// Both panels are the same [LiquidPanel] under a [GlassQualityScope], so the
/// only difference is the tier: `liquid` bends the wallpaper at its edge and
/// shades its rim, `plain` is a Gaussian blur behind the same tint with a flat
/// rim.
///
/// The tier is decided once, from the device, before the first frame — so
/// nothing here changes while you watch. The raster figure is information, not
/// an input: it is what the current tier costs, which is worth knowing, but it
/// is not what chose it.
class QualityContent extends StatefulWidget {
  const QualityContent({super.key});

  @override
  State<QualityContent> createState() => _QualityContentState();
}

class _QualityContentState extends State<QualityContent> {
  /// Null means "let the device classification stand".
  GlassQuality? _pinned;

  final List<int> _recentRaster = <int>[];
  int _p90Micros = 0;

  @override
  void initState() {
    super.initState();
    SchedulerBinding.instance.addTimingsCallback(_onTimings);
    GlassDeviceTier.instance.addListener(_onTier);
  }

  @override
  void dispose() {
    SchedulerBinding.instance.removeTimingsCallback(_onTimings);
    GlassDeviceTier.instance
      ..removeListener(_onTier)
      ..pinnedQuality = null;
    super.dispose();
  }

  void _onTier() {
    if (mounted) setState(() {});
  }

  void _onTimings(List<FrameTiming> timings) {
    for (final FrameTiming timing in timings) {
      _recentRaster.add(timing.rasterDuration.inMicroseconds);
    }
    if (_recentRaster.length < 30) return;
    final List<int> sorted = List<int>.of(_recentRaster)..sort();
    _p90Micros = sorted[(sorted.length * 0.9).floor()];
    _recentRaster.clear();
    if (mounted) setState(() {});
  }

  void _pin(GlassQuality? quality) {
    setState(() => _pinned = quality);
    GlassDeviceTier.instance.pinnedQuality = quality;
  }

  @override
  Widget build(BuildContext context) {
    final bool isLight = Theme.of(context).brightness == Brightness.light;
    final Color contentColor =
        isLight ? const Color(0xFF000000) : const Color(0xFFFFFFFF);

    return BackdropDemoScaffold(
      builder: (BuildContext context, LayerBackdrop backdrop) {
        return <Widget>[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              spacing: 22,
              children: <Widget>[
                // The two tiers, together. The whole point of the screen: the
                // difference has to be seen, not described.
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  spacing: 14,
                  children: <Widget>[
                    for (final GlassQuality quality in GlassQuality.values)
                      _TierSample(
                        backdrop: backdrop,
                        quality: quality,
                        contentColor: contentColor,
                      ),
                  ],
                ),
                _DeviceReadout(
                  contentColor: contentColor,
                  p90Micros: _p90Micros,
                ),
                _PinControl(
                  backdrop: backdrop,
                  contentColor: contentColor,
                  pinned: _pinned,
                  onPin: _pin,
                ),
              ],
            ),
          ),
        ];
      },
    );
  }
}

/// What this device was classified as, and on what evidence.
class _DeviceReadout extends StatelessWidget {
  const _DeviceReadout({required this.contentColor, required this.p90Micros});

  final Color contentColor;
  final int p90Micros;

  @override
  Widget build(BuildContext context) {
    final GlassDeviceTier tier = GlassDeviceTier.instance;
    final GlassDeviceInfo info = tier.info;
    final double refreshRate = info.refreshRate;
    final double budgetMs = refreshRate > 0 ? 1000 / refreshRate : 16.7;

    return DefaultTextStyle(
      style: TextStyle(color: contentColor, fontSize: 14, height: 1.55),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'This device draws at: ${tier.quality.name}',
            style: TextStyle(
              color: contentColor,
              fontSize: 17,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            tier.describe(),
            style: TextStyle(
              color: contentColor.withValues(alpha: 0.68),
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 8),
          Text('Runtime shaders: ${info.supportsRuntimeShaders}'),
          Text(
            'Cores: ${info.processorCount == 0 ? "unknown" : info.processorCount}'
            '   Arch: ${info.architecture.isEmpty ? "unknown" : info.architecture}',
          ),
          Text('Display: ${refreshRate.round()} Hz'
              '   ${info.devicePixelRatio}x'
              '   ${info.fillDemandMegapixelsPerSecond.round()} Mpx/s to fill'),
          const SizedBox(height: 8),
          Text(
            p90Micros == 0
                ? 'Raster p90: idle — nothing is animating to measure'
                : 'Raster p90: ${(p90Micros / 1000).toStringAsFixed(1)} ms of a '
                    '${budgetMs.toStringAsFixed(1)} ms frame',
            style: TextStyle(
              color: contentColor.withValues(alpha: 0.68),
              fontSize: 13,
            ),
          ),
          Text(
            'Measured, but not what decided the tier — quality is a device '
            'property here, not a running average.',
            style: TextStyle(
              color: contentColor.withValues(alpha: 0.5),
              fontSize: 12,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

/// One panel pinned to one tier, labelled with what it draws.
class _TierSample extends StatelessWidget {
  const _TierSample({
    required this.backdrop,
    required this.quality,
    required this.contentColor,
  });

  final Backdrop backdrop;
  final GlassQuality quality;
  final Color contentColor;

  static const Map<GlassQuality, String> _draws = <GlassQuality, String>{
    GlassQuality.liquid: 'refraction\n+ shaded rim',
    GlassQuality.plain: 'Gaussian blur\n+ flat rim',
  };

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      spacing: 8,
      children: <Widget>[
        // A scope is how a subtree pins a tier; no component takes a quality
        // parameter of its own.
        GlassQualityScope(
          quality: quality,
          child: LiquidPanel(
            backdrop: backdrop,
            shape: const RoundedRectangle(24),
            child: SizedBox(
              width: 140,
              height: 132,
              child: Center(
                child: Text(
                  quality.name,
                  style: TextStyle(
                    color: contentColor,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ),
        Text(
          _draws[quality]!,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: contentColor.withValues(alpha: 0.62),
            fontSize: 12,
            height: 1.3,
          ),
        ),
      ],
    );
  }
}

/// Overrides the classification, or hands it back.
class _PinControl extends StatelessWidget {
  const _PinControl({
    required this.backdrop,
    required this.contentColor,
    required this.pinned,
    required this.onPin,
  });

  final Backdrop backdrop;
  final Color contentColor;
  final GlassQuality? pinned;
  final ValueChanged<GlassQuality?> onPin;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      spacing: 8,
      children: <Widget>[
        Text(
          'Override the classification',
          style: TextStyle(
            color: contentColor.withValues(alpha: 0.62),
            fontSize: 13,
          ),
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: <Widget>[
            for (final GlassQuality? option in <GlassQuality?>[
              null,
              ...GlassQuality.values,
            ])
              LiquidButton(
                backdrop: backdrop,
                tint: option == pinned ? const Color(0xFF0088FF) : null,
                onPressed: () => onPin(option),
                children: <Widget>[
                  Text(
                    option?.name ?? 'device',
                    style: TextStyle(
                      color: option == pinned
                          ? const Color(0xFFFFFFFF)
                          : contentColor,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
          ],
        ),
      ],
    );
  }
}
