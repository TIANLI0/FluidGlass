import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

import '../backdrop.dart';
import '../draw_backdrop.dart';
import '../internal/blur_sigma.dart';
import '../internal/shader_programs.dart';
import '../shapes/rounded_rectangular_shape.dart';
import 'blur.dart';

/// Which end of the run is blurred.
enum ProgressiveBlurDirection {
  /// Full radius at the top, clear at the bottom — chrome over a feed.
  blurredTopClearBottom,

  /// Full radius at the bottom, clear at the top — a tab bar, a fade-out.
  blurredBottomClearTop,
}

/// A blur that grows from nothing at one edge to [maxBlurRadius] at the
/// other, so chrome dissolves into the content under it instead of ending on
/// a line.
///
/// ```dart
/// ProgressiveBlur(maxBlurRadius: 20, child: title)
/// ```
///
/// ## How it is built
///
/// With [backdrop], each level samples that shared source and uses only
/// Flutter's native Gaussian and a native linear-gradient [ShaderMask]. Levels
/// use absolute sigma and overlap only adjacent blur strengths. The masks live
/// in logical coordinates, so route scaling and opacity do not shift them.
/// This is the preferred path when a page already has a shared backdrop, and
/// it also works without runtime shader filters. Do not include this widget in
/// its own source.
///
/// Without [backdrop], the compositor-only path below is used:
///
/// A stack of ordinary Gaussian `BackdropFilter`s, each clipped to a shorter
/// run from the blurred end and each reading the output of the one before
/// it, so the blur accumulates: band *k* adds just enough sigma to bring the
/// total to its target, and the targets grow geometrically towards the
/// blurred end. Every band runs the engine's own blur, which downsamples for
/// large radii and never undersamples — the reason this is a stack and not a
/// single shader.
///
/// Between bands, a one-sample fragment shader inside each band's filter
/// chain fades its input along a linear alpha ramp before the blur, so the
/// band's output slopes into the previous band's rather than stepping. The two
/// images being mixed are blurred by similar amounts, which is what keeps the
/// mix from reading as a double exposure — that artefact needs a sharp image
/// under a soft one, and the only band that sits on sharp content is the
/// first, whose sigma is under a logical pixel.
///
/// Without runtime shaders (Skia, the web) the bands keep their hard edges,
/// which with the default [bands] reads as a fine-grained ramp.
///
/// ## Why not the obvious constructions
///
/// * **One shader with a per-fragment sigma** samples a fixed number of taps
///   whatever the radius. A 24-pixel radius on a 4× display is a sigma of
///   ~56 device pixels; 25 taps across that are 6 pixels apart, and the result
///   is not a blur but the content copied several times at small offsets —
///   a ghost. Blurring that large correctly needs a downsampled input, which
///   the engine's Gaussian has and a shader in a backdrop filter does not.
/// * **A full-strength blur behind a gradient `ShaderMask`** fades that
///   layer's *opacity*, so halfway down the screen shows half a blurred
///   image over half a sharp one: the double exposure above.
/// * **A `BackdropFilter` nested in a `ShaderMask`** filters the mask's own
///   empty save layer rather than the scene, and draws as a dark slab.
///
/// ## Cost
///
/// [bands] backdrop reads over runs that shrink towards the blurred end, each
/// a downsampled Gaussian plus one trivial shader pass. For the default five
/// bands over a bar this is roughly a third of the texture samples the
/// single-shader version spent, with none of its aliasing. Fewer bands cost
/// less and step more; three still reads as continuous under text.
class ProgressiveBlur extends StatefulWidget {
  const ProgressiveBlur({
    super.key,
    this.maxBlurRadius = 20,
    this.direction = ProgressiveBlurDirection.blurredTopClearBottom,
    this.startOffset = 0,
    this.bands = 5,
    this.debugShowMask = false,
    this.backdrop,
    this.child,
  }) : assert(maxBlurRadius >= 0, 'A blur radius is a distance.'),
       assert(
         startOffset >= 0 && startOffset < 1,
         'The held stretch is a fraction of the run.',
       ),
       assert(bands >= 1 && bands <= 8, 'One to eight bands.');

  /// The radius at the blurred end, in logical pixels. Apple's own default for
  /// its variable blur is 20.
  final double maxBlurRadius;

  final ProgressiveBlurDirection direction;

  /// How much of the run, measured from the blurred end, stays at
  /// [maxBlurRadius] before the ramp starts.
  ///
  /// Chrome wants a little: the status bar has to stay legible whatever
  /// scrolls under it, and a ramp that starts at the very top edge is already
  /// halfway clear by the time it reaches the icons.
  final double startOffset;

  /// How many Gaussian layers make up the ramp. More is smoother and costs a
  /// backdrop read each; five is continuous under running text, three is the
  /// floor for chrome, one is a plain uniform blur.
  final int bands;

  /// Paints each band's alpha ramp — red where the band is opaque, green where
  /// it has faded out — instead of blurring. For checking on a device where
  /// the bands actually landed, which a screenshot answers and reasoning does
  /// not.
  final bool debugShowMask;

  /// Drawn over the blur, unfiltered — a tint, a title, nothing.
  final Widget? child;

  /// An explicit source enables native Gaussian filters and native gradient
  /// masks only, with no runtime shader filter. The source must not contain
  /// this blur. Prefer this when chrome already shares a [LayerBackdrop].
  /// Unlike a masked BackdropFilter, a masked sampled source has real pixels
  /// inside the mask's isolated layer, including during predictive back.
  final Backdrop? backdrop;

  @override
  State<ProgressiveBlur> createState() => _ProgressiveBlurState();
}

class _ProgressiveBlurState extends State<ProgressiveBlur> {
  // A filter materializes its native uniforms lazily, at paint time. Sharing
  // one mutable shader across bands (or pages) makes them all read the last
  // band's ramp. Keep one shader per live band, and release them with the owner.
  final Map<int, ui.FragmentShader> _shaders = <int, ui.FragmentShader>{};
  ui.FragmentProgram? _program;

  @override
  void initState() {
    super.initState();
    FluidGlassPrograms.instance.addListener(_programsChanged);
  }

  void _programsChanged() => setState(() {});

  void _clearShaders() {
    for (final ui.FragmentShader shader in _shaders.values) {
      shader.dispose();
    }
    _shaders.clear();
  }

  @override
  void dispose() {
    FluidGlassPrograms.instance.removeListener(_programsChanged);
    _clearShaders();
    super.dispose();
  }

  /// The sigma the first band adds, in logical pixels: what a sharp image can
  /// be mixed with before the mix reads as a ghost.
  static const double _firstBandSigma = 0.75;

  @override
  Widget build(BuildContext context) {
    final Widget content = widget.child ?? const SizedBox.expand();
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double run = constraints.maxHeight;
        assert(
          run.isFinite,
          'ProgressiveBlur needs a bounded height: the ramp is a fraction of '
          'it.',
        );
        final double dpr = MediaQuery.devicePixelRatioOf(context);
        final double sigmaMax = blurRadiusToSigma(
          widget.maxBlurRadius,
          devicePixelRatio: dpr,
        );
        if (sigmaMax <= 0 || !run.isFinite || run <= 0) return content;
        final ui.FragmentProgram? program =
            (widget.backdrop == null || widget.backdrop!.isCompositorOnly) &&
                isRuntimeShaderSupported()
            ? FluidGlassPrograms.instance.progressiveBlur
            : null;
        if (!identical(program, _program)) {
          _clearShaders();
          _program = program;
        }
        return Stack(
          fit: StackFit.expand,
          children: <Widget>[
            _band(
              _BandGeometry(
                run: run,
                dpr: dpr,
                sigmaMax: sigmaMax,
                startOffset: widget.startOffset,
                fractions: _fractions(sigmaMax),
                up:
                    widget.direction ==
                    ProgressiveBlurDirection.blurredTopClearBottom,
                program: program,
                debug: widget.debugShowMask,
              ),
              0,
            ),
            content,
          ],
        );
      },
    );
  }

  /// Each band's cumulative sigma as a fraction of [sigmaMax], smallest first
  /// and ending at 1. Geometric, so consecutive bands differ by a constant
  /// ratio — the mix between any two neighbours is equally safe — and the
  /// first band adds only [_firstBandSigma].
  List<double> _fractions(double sigmaMax) {
    final int bands = widget.bands;
    if (bands == 1) return const <double>[1];
    final double first = (_firstBandSigma / sigmaMax).clamp(0.02, 1.0);
    final double ratio = math.pow(1 / first, 1 / (bands - 1)).toDouble();
    return List<double>.generate(
      bands,
      (int i) => i == bands - 1 ? 1.0 : first * math.pow(ratio, i),
    );
  }

  /// Band [k], sized to its run, with band `k + 1` nested inside it so the
  /// inner band's backdrop is this one's output.
  Widget _band(_BandGeometry g, int k) {
    final int count = g.fractions.length;
    final double previous = k == 0 ? 0 : g.fractions[k - 1];
    final double target = g.fractions[k];
    final double sigma =
        g.sigmaMax * math.sqrt(target * target - previous * previous);
    // Distances from the blurred end, in logical pixels: where this band is
    // still fully opaque, and where it has faded out (its far edge).
    final double full = g.positionOf(target);
    final double clear = k == 0 ? g.run : g.positionOf(previous);

    final Backdrop? source = widget.backdrop;
    if (source != null && !source.isCompositorOnly) {
      // Every level samples the same original content, so use its absolute
      // sigma, not the incremental sigma of the nested backdrop-filter path.
      final double radius = math.max(
        0,
        (g.sigmaMax * target - 0.5 / g.dpr) / kBlurSigmaScale,
      );
      final Widget blurred = DrawBackdrop.plain(
        backdrop: source,
        shape: () => const Rectangle(),
        effects: (scope) => scope.blur(radius),
        // Keep sampling even in the plain tier: a compositor filter would
        // otherwise read the ShaderMask's empty save layer.
        onDrawBackdrop: (_, draw) => draw(),
        child: const SizedBox.expand(),
      );
      final Widget masked = k == 0
          ? blurred
          : ShaderMask(
              blendMode: ui.BlendMode.dstIn,
              shaderCallback: (bounds) => ui.Gradient.linear(
                g.up ? Offset(0, full) : Offset(0, clear - full),
                g.up ? Offset(0, clear) : Offset.zero,
                const <Color>[Color(0xFFFFFFFF), Color(0x00FFFFFF)],
              ),
              child: blurred,
            );
      return Stack(
        fit: StackFit.expand,
        children: <Widget>[
          if (g.debug)
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: g.up ? Alignment.topCenter : Alignment.bottomCenter,
                  end: g.up ? Alignment.bottomCenter : Alignment.topCenter,
                  colors: const <Color>[Color(0xFFFF0000), Color(0xFF00FF00)],
                  stops: <double>[full / clear, 1],
                ),
              ),
            )
          else
            masked,
          if (k < count - 1)
            Align(
              alignment: g.up ? Alignment.topCenter : Alignment.bottomCenter,
              child: SizedBox(
                width: double.infinity,
                height: g.positionOf(target),
                child: _band(g, k + 1),
              ),
            ),
        ],
      );
    }

    ui.ImageFilter filter = ui.ImageFilter.blur(
      sigmaX: sigma,
      sigmaY: sigma,
      // Clamp, not decal: the blurred end of the run is a texture edge, and
      // a blur that reads transparent past it thins the top rows to let the
      // sharp scene beneath show through.
      tileMode: ui.TileMode.clamp,
    );
    final ui.FragmentProgram? program = g.program;
    if (program != null && k > 0) {
      // The ramp fades the input before the blur, so the blur softens the
      // ramp too. The first band has no band beneath to fade into — its
      // whole run is the ramp from sharp to its own sub-pixel sigma, and a
      // hard edge at the clear end of a 0.75 px blur is not one the eye can
      // find.
      final ui.FragmentShader shader = _shaders[k] ??= program.fragmentShader();
      shader
        // Floats 0..1 are uTextureSize, which the engine overwrites.
        ..setFloat(0, 0)
        ..setFloat(1, 0)
        ..setFloat(2, full * g.dpr)
        ..setFloat(3, clear * g.dpr)
        ..setFloat(4, g.up ? 0 : 1)
        ..setFloat(5, g.debug ? 1 : 0);
      filter = ui.ImageFilter.compose(
        outer: filter,
        inner: ui.ImageFilter.shader(shader),
      );
    }

    final Widget inner = k == count - 1
        ? const SizedBox.expand()
        : Align(
            alignment: g.up ? Alignment.topCenter : Alignment.bottomCenter,
            child: SizedBox(
              width: double.infinity,
              height: g.positionOf(target),
              child: _band(g, k + 1),
            ),
          );
    // **The clip is not cosmetic.** A `BackdropFilter` with no clip filters
    // the whole screen and draws the result over the whole screen; the
    // widget's bounds only decide where its *child* goes.
    return ClipRect(
      child: BackdropFilter(filter: filter, child: inner),
    );
  }
}

class _BandGeometry {
  const _BandGeometry({
    required this.run,
    required this.dpr,
    required this.sigmaMax,
    required this.startOffset,
    required this.fractions,
    required this.up,
    required this.program,
    required this.debug,
  });

  final double run;
  final double dpr;
  final double sigmaMax;
  final double startOffset;
  final List<double> fractions;
  final bool up;
  final ui.FragmentProgram? program;
  final bool debug;

  /// Distance from the blurred end at which the linear mask has fallen to
  /// [fraction] of full: the mask holds 1 across [startOffset] of the run and
  /// then falls in a straight line to 0 at the far end, which is the ramp
  /// Apple's gradient mask draws.
  double positionOf(double fraction) =>
      run * (startOffset + (1 - fraction) * (1 - startOffset));
}
