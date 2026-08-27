import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:fluid_glass/fluid_glass.dart';
import 'package:flutter/material.dart';

/// Glass over backgrounds that move without scrolling.
///
/// A scrolling feed is the easy live case — scroll notifications bubble out of
/// the subtree, so [BackdropLayer] hears about it before the frame is even
/// built. These two are the ones that used to freeze:
///
/// * **Animated** paints its aurora inside a `RepaintBoundary`.
///   `markNeedsPaint` stops there, so `RenderBackdropLayer` never repaints and
///   never learned that anything had changed; the glass kept re-drawing the
///   same capture over a background that was moving underneath it. The captured
///   layers are watched now, so a repaint anywhere inside is noticed without
///   the app declaring anything.
/// * **Pan & zoom** does not repaint at all — `InteractiveViewer` only changes
///   the transform above the source. The capture stays perfectly valid; what
///   changes is *where* the glass has to read it, which takes the whole matrix
///   between the two and not the offset between their origins. Pinch it: the
///   glass magnifies what is under it by exactly as much as the photo.
///
/// Neither needs [BackdropLayer.liveness]. Passing it is still worth it when
/// something already knows the content is about to change — it drops the
/// capture *before* the frame is built, which is one frame earlier than any
/// after-the-fact watch can manage.
class LiveBackgroundContent extends StatefulWidget {
  const LiveBackgroundContent({super.key});

  @override
  State<LiveBackgroundContent> createState() => _LiveBackgroundContentState();
}

enum _Background { animated, zoom }

class _LiveBackgroundContentState extends State<LiveBackgroundContent>
    with SingleTickerProviderStateMixin {
  final LayerBackdrop _backdrop = LayerBackdrop();
  late final AnimationController _clock = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 12),
  )..repeat();

  _Background _background = _Background.animated;

  @override
  void dispose() {
    _clock.dispose();
    _backdrop.dispose();
    super.dispose();
  }

  Widget _buildBackground() {
    switch (_background) {
      case _Background.animated:
        // The RepaintBoundary is the point of the demo, not an accident: it is
        // what a `Rive`, a `Lottie`, a video-ish shader or anyone being careful
        // about repaint scope puts around an animation.
        return RepaintBoundary(
          child: AnimatedBuilder(
            animation: _clock,
            builder: (BuildContext context, Widget? child) => CustomPaint(
              painter: _AuroraPainter(_clock.value),
              isComplex: true,
              willChange: true,
              child: const SizedBox.expand(),
            ),
          ),
        );
      case _Background.zoom:
        return InteractiveViewer(
          minScale: 1,
          maxScale: 4,
          child: SizedBox.expand(
            child: Image.asset('assets/wallpaper_light.webp', fit: BoxFit.cover),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final EdgeInsets viewPadding = MediaQuery.paddingOf(context);
    const Color ink = Color(0xFFFFFFFF);

    return Stack(
      clipBehavior: Clip.none,
      children: <Widget>[
        Positioned.fill(
          child: BackdropLayer(backdrop: _backdrop, child: _buildBackground()),
        ),

        // Pinned chrome: it never moves, so anything it shows that changes came
        // from re-sampling the background.
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: LiquidPanel(
            backdrop: _backdrop,
            shape: const UnevenRoundedRectangle(
              RectangleCornerRadii(
                topStart: 0,
                topEnd: 0,
                bottomEnd: 28,
                bottomStart: 28,
              ),
            ),
            child: Padding(
              padding: EdgeInsets.only(
                top: viewPadding.top + 12,
                // Clear of the catalog's own Back button, which floats over
                // every destination's top-left corner.
                left: 148,
                right: 20,
                bottom: 16,
              ),
              child: Row(
                children: <Widget>[
                  const Expanded(
                    child: Text(
                      'Live background',
                      style: TextStyle(
                        color: ink,
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Text(
                    switch (_background) {
                      _Background.animated => 'repainting',
                      _Background.zoom => 'pinch to zoom',
                    },
                    style: TextStyle(
                      color: ink.withValues(alpha: 0.7),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        // A floating pill in the middle of the screen, where the background is
        // busiest — the frozen capture used to be most obvious here.
        Align(
          child: DrawBackdrop(
            backdrop: _backdrop,
            shape: () => const Capsule(),
            effects: (BackdropEffectScope scope) => scope
              ..vibrancy()
              ..blur(4)
              ..lens(16, 32),
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 28, vertical: 18),
              child: Text(
                'refracting live',
                style: TextStyle(color: ink, fontSize: 17),
              ),
            ),
          ),
        ),

        Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: EdgeInsets.only(bottom: 16 + viewPadding.bottom),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                for (final _Background option in _Background.values)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: SizedBox(
                      height: 52,
                      child: LiquidButton(
                        onPressed: () => setState(() => _background = option),
                        backdrop: _backdrop,
                        tint: _background == option
                            ? const Color(0xFF0088FF)
                            : null,
                        children: <Widget>[
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            child: Text(
                              switch (option) {
                                _Background.animated => 'Animated',
                                _Background.zoom => 'Pan & zoom',
                              },
                              style: const TextStyle(color: ink, fontSize: 15),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Slow drifting blobs over a dark ground, with a hairline grid on top.
///
/// The grid matters: a smooth gradient blurred is very nearly itself, so a
/// backdrop made only of soft colour proves nothing about whether the glass is
/// re-sampling. Thin lines sliding under it do.
class _AuroraPainter extends CustomPainter {
  const _AuroraPainter(this.t);

  /// 0..1, one full cycle.
  final double t;

  static const List<Color> _blobs = <Color>[
    Color(0xFF0088FF),
    Color(0xFFE5484D),
    Color(0xFF00A972),
    Color(0xFF8E5BFF),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFF08080C),
    );

    final double radius = size.shortestSide * 0.55;
    for (int i = 0; i < _blobs.length; i++) {
      final double phase = t * 2 * math.pi + i * math.pi / 2;
      final Offset centre = Offset(
        size.width * (0.5 + 0.32 * math.cos(phase * (1 + i * 0.15))),
        size.height * (0.5 + 0.28 * math.sin(phase * (1 + i * 0.22))),
      );
      canvas.drawCircle(
        centre,
        radius,
        Paint()
          ..blendMode = BlendMode.plus
          ..shader = ui.Gradient.radial(centre, radius, <Color>[
            _blobs[i].withValues(alpha: 0.85),
            _blobs[i].withValues(alpha: 0.0),
          ]),
      );
    }

    // A grid that slides, so "is the glass re-sampling" is answerable by eye.
    final Paint line = Paint()
      ..color = const Color(0x33FFFFFF)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    const double step = 36;
    final double shift = (t * step * 4) % step;
    for (double x = shift - step; x < size.width + step; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), line);
    }
    for (double y = shift - step; y < size.height + step; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), line);
    }
  }

  @override
  bool shouldRepaint(_AuroraPainter oldDelegate) => oldDelegate.t != t;
}
