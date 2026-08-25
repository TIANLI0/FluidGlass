import 'package:fluid_glass/fluid_glass.dart';
import 'package:flutter/material.dart';

import '../backdrop_demo_scaffold.dart';
import '../utils/lorem_ipsum.dart';

/// A text cursor with a glass loupe above it, magnifying the text, the cursor
/// and the wallpaper all at once.
class MagnifierContent extends StatefulWidget {
  const MagnifierContent({super.key});

  @override
  State<MagnifierContent> createState() => _MagnifierContentState();
}

class _MagnifierContentState extends State<MagnifierContent> {
  final LayerBackdrop _contentBackdrop = LayerBackdrop();
  final LayerBackdrop _cursorBackdrop = LayerBackdrop();

  Offset _offset = Offset.zero;

  @override
  void dispose() {
    _contentBackdrop.dispose();
    _cursorBackdrop.dispose();
    super.dispose();
  }

  /// Scales the sampled backdrop up by 1.5 about the loupe's centre, then
  /// shifts it down so the loupe shows what sits 80dp below it.
  void _onDrawBackdrop(BackdropDrawContext context, void Function() drawBackdrop) {
    final Canvas canvas = context.canvas;
    final double cx = context.size.width / 2;
    final double cy = context.size.height / 2;
    canvas.save();
    canvas.translate(cx, cy);
    canvas.scale(1.5, 1.5);
    canvas.translate(-cx, -cy);
    canvas.translate(0, -80);
    drawBackdrop();
    canvas.restore();
  }

  @override
  Widget build(BuildContext context) {
    final bool isLight = Theme.of(context).brightness == Brightness.light;
    final Color contentColor =
        isLight ? const Color(0xFF000000) : const Color(0xFFFFFFFF);
    final Color accentColor =
        isLight ? const Color(0xFF0088FF) : const Color(0xFF0091FF);
    final Color backgroundColor =
        isLight ? const Color(0xFFFFFFFF) : const Color(0xFF121212);

    return BackdropDemoScaffold(
      builder: (BuildContext context, LayerBackdrop backdrop) {
        return <Widget>[
            BackdropLayer(
              backdrop: _contentBackdrop,
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: ClipPath(
                  clipper: const GlassShapeClipper(RoundedRectangle(32)),
                  child: ColoredBox(
                    color: backgroundColor.withValues(alpha: 0.9),
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        kLoremIpsum,
                        style: TextStyle(color: contentColor, fontSize: 16),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Transform.translate(
              offset: _offset,
              child: GestureDetector(
                // Compose hit-tests by layout bounds; the child here draws nothing
                // hit-testable of its own.
                behavior: HitTestBehavior.opaque,
                onPanUpdate: (DragUpdateDetails details) =>
                    setState(() => _offset += details.delta),
                child: BackdropLayer(
                  backdrop: _cursorBackdrop,
                  child: DecoratedBox(
                    decoration: ShapeDecoration(
                      color: accentColor,
                      shape: const GlassShapeBorder(Capsule()),
                    ),
                    child: const SizedBox(width: 4, height: 24),
                  ),
                ),
              ),
            ),
            Transform.translate(
              offset: Offset(_offset.dx, _offset.dy - 80),
              child: DrawBackdrop(
                backdrop: CombinedBackdrop.of(
                  backdrop,
                  _contentBackdrop,
                  _cursorBackdrop,
                ),
                shape: () => const Capsule(),
                effects: (BackdropEffectScope scope) => scope.lens(
                  8,
                  24,
                  depthEffect: true,
                  chromaticAberration: true,
                ),
                innerShadow: () => GlassInnerShadow(radius: 16),
                onDrawBackdrop: _onDrawBackdrop,
                child: const SizedBox(width: 128, height: 96),
              ),
            ),
        ];
      },
    );
  }
}
