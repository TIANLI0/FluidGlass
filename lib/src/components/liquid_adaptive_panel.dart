import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../fluid_glass.dart';

/// Measures the average luminance of what a glass element samples.
///
/// Glass has no colour of its own worth speaking of: what a reader sees through
/// it is whatever it is over, and so is the contrast of anything drawn on it.
/// A panel tuned to look right on a dark wallpaper turns into a bright smear on
/// a white page, and the label on it stops being legible — not gradually, but
/// at whichever scroll position brings the white page underneath.
///
/// This closes that loop. Hand [onDrawBackdrop] to a [DrawBackdrop]; it records
/// a [resolution]×[resolution] thumbnail of the same pixels the glass is about
/// to refract, and a loop reads it back every [interval] and lands the Rec. 709
/// average in [value], spring-smoothed so the glass eases between readings
/// instead of stepping.
///
/// The cost is one tiny picture per *sample*, not per frame — the recorder only
/// arms itself again once the reader has consumed the last one. Reading pixels
/// back is asynchronous, so [value] trails what is on screen by design; nothing
/// here belongs on a per-frame path.
///
/// Dispose it with the State that owns it.
class BackdropLuminance extends ChangeNotifier {
  BackdropLuminance({
    required TickerProvider vsync,
    double initialValue = 0.5,
    this.resolution = 5,
    this.interval = const Duration(seconds: 1),
    this.smoothing = const Duration(milliseconds: 1000),
  }) : assert(resolution > 0, 'Resolution must be positive.'),
       _luminance = SpringValue(
         vsync: vsync,
         value: initialValue,
         visibilityThreshold: 0.001,
       ) {
    _luminance.addListener(notifyListeners);
    _schedule();
  }

  /// The thumbnail is this many pixels on a side. Five is plenty: the reading
  /// wanted is "is this light or dark", and a larger one only costs more to
  /// read back.
  final int resolution;

  /// How often the thumbnail is read back.
  final Duration interval;

  /// How long [value] takes to travel to a new reading.
  final Duration smoothing;

  final SpringValue _luminance;
  ui.Picture? _thumbnail;
  Timer? _timer;
  bool _wantsThumbnail = true;
  bool _running = true;

  /// The smoothed average luminance, 0 (black) to 1 (white).
  double get value => _luminance.value;

  /// Black on a light backdrop, white on a dark one — what to draw on the glass
  /// so it stays legible.
  Color get contentColor =>
      value > 0.5 ? const Color(0xFF000000) : const Color(0xFFFFFFFF);

  /// Repaint any glass that reads [value] from inside its effects callback.
  Listenable get repaint => _luminance;

  /// Hand this to [DrawBackdrop.onDrawBackdrop].
  void onDrawBackdrop(
    BackdropDrawContext context,
    void Function() drawBackdrop,
  ) {
    drawBackdrop();

    if (!_wantsThumbnail || context.size.isEmpty) return;
    _wantsThumbnail = false;
    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(recorder);
    canvas.scale(
      resolution / context.size.width,
      resolution / context.size.height,
    );
    context.backdrop.drawBackdrop(context.copyWith(canvas: canvas));
    _thumbnail?.dispose();
    _thumbnail = recorder.endRecording();
  }

  /// A cancellable timer rather than a `while` loop around `Future.delayed`:
  /// the loop would leave one delay pending past [dispose], which outlives the
  /// object, holds it alive until it fires, and fails any widget test that
  /// happens to end inside the window.
  void _schedule() {
    _timer = Timer(interval, () async {
      if (!_running) return;
      await _measure();
      if (_running) _schedule();
    });
  }

  Future<void> _measure() async {
    final ui.Picture? picture = _thumbnail;
    if (picture == null) {
      _wantsThumbnail = true;
      return;
    }
    final ui.Image image = picture.toImageSync(resolution, resolution);
    final ByteData? bytes = await image.toByteData(
      format: ui.ImageByteFormat.rawRgba,
    );
    image.dispose();
    if (bytes == null || !_running) return;

    final Uint8List data = bytes.buffer.asUint8List();
    final int count = resolution * resolution;
    double sum = 0;
    for (int i = 0; i < count; i++) {
      sum +=
          0.2126 * (data[i * 4] / 255.0) +
          0.7152 * (data[i * 4 + 1] / 255.0) +
          0.0722 * (data[i * 4 + 2] / 255.0);
    }
    final double average = sum / count;

    // Retargeting unconditionally would restart the tween every interval, so
    // the ticker would never stop and the whole glass chain would re-run at
    // 60 fps over a screen nobody is touching.
    if ((average - _luminance.targetValue).abs() > 0.002) {
      _luminance.tweenTo(average, smoothing);
    }
    _wantsThumbnail = true;
  }

  @override
  void dispose() {
    _running = false;
    _timer?.cancel();
    _timer = null;
    _thumbnail?.dispose();
    _thumbnail = null;
    _luminance
      ..removeListener(notifyListeners)
      ..dispose();
    super.dispose();
  }
}

/// A [LiquidPanel] that measures what it sits on and retunes itself to stay
/// legible over it.
///
/// Same surface as [LiquidPanel], but brightness, contrast and blur follow a
/// [BackdropLuminance] reading instead of being fixed: over a light backdrop it
/// brightens and flattens contrast and blurs harder, so text on it keeps its
/// ground; over a dark one it darkens slightly and blurs less, so the glass
/// does not turn into an opaque slab. [builder] receives the colour to draw
/// content in — black or white, whichever the current reading can carry.
///
/// Use it where the thing behind the glass is out of the app's control: a panel
/// over a user's wallpaper, over a photo, over a page that scrolls between
/// light and dark sections. Where the backdrop is known, a plain [LiquidPanel]
/// with a fixed tint is cheaper and steadier — this one reads pixels back on a
/// timer.
class LiquidAdaptivePanel extends StatefulWidget {
  const LiquidAdaptivePanel({
    super.key,
    required this.backdrop,
    required this.builder,
    this.shape = const RoundedRectangle(24),
    this.interval = const Duration(seconds: 1),
    this.saturation = 1.5,
    this.showHighlight = true,
    this.layerBlock,
    this.repaint,
  });

  /// What the glass refracts and measures. [nativeBackdrop] cannot be used:
  /// there are no pixels to read back from a compositor filter.
  final Backdrop backdrop;

  /// Builds the content, given the colour that is legible on the glass right
  /// now.
  final Widget Function(BuildContext context, Color contentColor) builder;

  final RoundedRectangularShape shape;

  /// How often the backdrop is sampled. See [BackdropLuminance.interval].
  final Duration interval;

  final double saturation;

  final bool showHighlight;

  /// An extra transform, as on [LiquidPanel]. The backdrop is
  /// counter-transformed automatically.
  final GlassLayerBlock? layerBlock;

  /// Anything else that should repaint the glass — whatever drives
  /// [layerBlock], typically. The luminance reading is merged in for you.
  final Listenable? repaint;

  @override
  State<LiquidAdaptivePanel> createState() => _LiquidAdaptivePanelState();
}

class _LiquidAdaptivePanelState extends State<LiquidAdaptivePanel>
    with TickerProviderStateMixin {
  late final BackdropLuminance _luminance = BackdropLuminance(
    vsync: this,
    interval: widget.interval,
  );

  @override
  void dispose() {
    _luminance.dispose();
    super.dispose();
  }

  static double _lerp(double a, double b, double t) => a + (b - a) * t;

  @override
  Widget build(BuildContext context) {
    return DrawBackdrop(
      backdrop: widget.backdrop,
      shape: () => widget.shape,
      effects: (BackdropEffectScope scope) {
        // Squared about the mid-point, sign kept: the correction stays out of
        // the way in the middle of the range, where the glass is legible
        // anyway, and comes on hard at the ends, where it is not.
        final double raw = _luminance.value * 2 - 1;
        final double l = raw.sign * raw * raw;
        scope
          ..colorControls(
            brightness: l > 0 ? _lerp(0.1, 0.5, l) : _lerp(0.1, -0.2, -l),
            contrast: l > 0 ? _lerp(1, 0, l) : 1,
            saturation: widget.saturation,
          )
          ..blur(l > 0 ? _lerp(8, 16, l) : _lerp(8, 2, -l))
          ..lens(24, scope.size.shortestSide / 2, depthEffect: true);
      },
      highlight: widget.showHighlight ? () => Highlight.plain : null,
      layerBlock: widget.layerBlock,
      onDrawBackdrop: _luminance.onDrawBackdrop,
      repaint: switch (widget.repaint) {
        null => _luminance.repaint,
        final Listenable extra => Listenable.merge(<Listenable>[
          _luminance.repaint,
          extra,
        ]),
      },
      child: ListenableBuilder(
        listenable: _luminance,
        builder: (BuildContext context, Widget? _) =>
            widget.builder(context, _luminance.contentColor),
      ),
    );
  }
}
