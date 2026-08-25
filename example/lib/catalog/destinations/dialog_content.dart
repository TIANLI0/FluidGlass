import 'package:fluid_glass/fluid_glass.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../backdrop_demo_scaffold.dart';
import '../utils/lorem_ipsum.dart';

class DialogContent extends StatelessWidget {
  const DialogContent({super.key});

  @override
  Widget build(BuildContext context) {
    final bool isLight = Theme.of(context).brightness == Brightness.light;
    final Color contentColor =
        isLight ? const Color(0xFF000000) : const Color(0xFFFFFFFF);
    final Color accentColor =
        isLight ? const Color(0xFF0088FF) : const Color(0xFF0091FF);
    final Color containerColor = isLight
        ? const Color(0xFFFAFAFA).withValues(alpha: 0.6)
        : const Color(0xFF121212).withValues(alpha: 0.4);
    final Color dimColor = isLight
        ? const Color(0xFF29293A).withValues(alpha: 0.23)
        : const Color(0xFF121212).withValues(alpha: 0.56);

    return BackdropDemoScaffold(
      // The dim sits inside the captured wallpaper, so the dialog refracts it.
      decorate: (Widget wallpaper) => Stack(
        fit: StackFit.expand,
        children: <Widget>[wallpaper, ColoredBox(color: dimColor)],
      ),
      builder: (BuildContext context, LayerBackdrop backdrop) {
        return <Widget>[
          Padding(
          padding: const EdgeInsets.all(40),
          child: DrawBackdrop(
            backdrop: backdrop,
            shape: () => const RoundedRectangle(48),
            effects: (BackdropEffectScope scope) => scope
              ..colorControls(brightness: isLight ? 0.2 : 0.0, saturation: 1.5)
              ..blur(isLight ? 16 : 8)
              ..lens(24, 48, depthEffect: true),
            highlight: () => Highlight.plain,
            onDrawSurface: (Canvas canvas, Size size) => canvas.drawRect(
              Offset.zero & size,
              Paint()..color = containerColor,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.fromLTRB(28, 24, 28, 12),
                  child: Text(
                    'Dialog Title',
                    style: TextStyle(
                      color: contentColor,
                      fontSize: 24,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                _DialogBody(isLight: isLight, contentColor: contentColor),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
                  child: Row(
                    spacing: 16,
                    children: <Widget>[
                      Expanded(
                        child: _DialogAction(
                          label: 'Cancel',
                          labelColor: contentColor,
                          background: containerColor.withValues(alpha: 0.2),
                        ),
                      ),
                      Expanded(
                        child: _DialogAction(
                          label: 'Okay',
                          labelColor: const Color(0xFFFFFFFF),
                          background: accentColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          ),
        ];
      },
    );
  }
}

class _DialogBody extends StatelessWidget {
  const _DialogBody({required this.isLight, required this.contentColor});

  final bool isLight;
  final Color contentColor;

  @override
  Widget build(BuildContext context) {
    final Widget text = Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 12),
      child: Text(
        kLoremIpsum,
        maxLines: 5,
        overflow: TextOverflow.clip,
        style: TextStyle(
          color: contentColor.withValues(alpha: 0.68),
          fontSize: 15,
        ),
      ),
    );
    if (isLight) {
      return text;
    }
    // On dark, the body text is added over the glass rather than drawn on it.
    return _BlendMode(blendMode: BlendMode.plus, child: text);
  }
}

/// Composites its child with a blend mode, the analogue of
/// `Modifier.graphicsLayer(blendMode = ...)`.
class _BlendMode extends SingleChildRenderObjectWidget {
  const _BlendMode({required this.blendMode, required Widget child})
      : super(child: child);

  final BlendMode blendMode;

  @override
  _RenderBlendMode createRenderObject(BuildContext context) =>
      _RenderBlendMode(blendMode);

  @override
  void updateRenderObject(BuildContext context, _RenderBlendMode renderObject) {
    renderObject.blendMode = blendMode;
  }
}

class _RenderBlendMode extends RenderProxyBox {
  _RenderBlendMode(this._blendMode);

  BlendMode _blendMode;
  set blendMode(BlendMode value) {
    if (_blendMode == value) return;
    _blendMode = value;
    markNeedsPaint();
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (child == null) return;
    context.canvas.saveLayer(offset & size, Paint()..blendMode = _blendMode);
    super.paint(context, offset);
    context.canvas.restore();
  }
}

class _DialogAction extends StatelessWidget {
  const _DialogAction({
    required this.label,
    required this.labelColor,
    required this.background,
  });

  final String label;
  final Color labelColor;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return ClipPath(
      clipper: const GlassShapeClipper(Capsule()),
      child: Material(
        color: background,
        child: InkWell(
          onTap: () {},
          child: SizedBox(
            height: 48,
            child: Center(
              child: Text(
                label,
                style: TextStyle(color: labelColor, fontSize: 16),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
