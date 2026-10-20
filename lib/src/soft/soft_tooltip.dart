import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'soft_motion.dart';
import 'soft_theme.dart';

/// A bubble pointing at [child]: accent fill, 13 white text, 12-radius corners
/// and a 20 × 10 rounded arrow. It scales out of the arrow tip with a little
/// overshoot and fades in; tapping anywhere closes it.
///
/// Shown by [SoftTooltipController.show] (or by a long press on [child] when
/// no controller is given).
class SoftTooltip extends StatefulWidget {
  const SoftTooltip({
    super.key,
    required this.message,
    required this.child,
    this.controller,
    this.preferBelow = false,
  });

  final String message;
  final Widget child;
  final SoftTooltipController? controller;

  /// Open under [child] instead of above it.
  final bool preferBelow;

  @override
  State<SoftTooltip> createState() => _SoftTooltipState();
}

/// Opens and closes a [SoftTooltip].
class SoftTooltipController {
  _SoftTooltipState? _state;

  void show() => _state?._show();
  void hide() => _state?._hide();
}

class _SoftTooltipState extends State<SoftTooltip>
    with TickerProviderStateMixin {
  final OverlayPortalController _portal = OverlayPortalController();
  final LayerLink _link = LayerLink();
  late final AnimationController _scale = AnimationController.unbounded(
    vsync: this,
  );
  late final AnimationController _alpha = AnimationController.unbounded(
    vsync: this,
  );

  static final SpringDescription _scaleSpring = softSpring(0.4, bounce: 0.2);
  static final SpringDescription _alphaSpring = softSpring(0.3, bounce: 0.2);

  @override
  void initState() {
    super.initState();
    widget.controller?._state = this;
  }

  @override
  void didUpdateWidget(SoftTooltip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?._state = null;
      widget.controller?._state = this;
    }
  }

  @override
  void dispose() {
    widget.controller?._state = null;
    _scale.dispose();
    _alpha.dispose();
    super.dispose();
  }

  void _show() {
    final bool reduce = softReduceMotion(context);
    _portal.show();
    _scale.springTo(1, _scaleSpring, reduceMotion: reduce);
    _alpha.springTo(1, _alphaSpring, reduceMotion: reduce);
  }

  Future<void> _hide() async {
    final bool reduce = softReduceMotion(context);
    _alpha.springTo(0, _alphaSpring, reduceMotion: reduce);
    await _scale.springTo(0, softSpring(0.3), reduceMotion: reduce);
    if (mounted) _portal.hide();
  }

  @override
  Widget build(BuildContext context) {
    final SoftThemeData theme = SoftTheme.of(context);
    final bool below = widget.preferBelow;
    return OverlayPortal(
      controller: _portal,
      overlayChildBuilder: (BuildContext context) => Stack(
        children: <Widget>[
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: _hide,
            ),
          ),
          CompositedTransformFollower(
            link: _link,
            targetAnchor: below ? Alignment.bottomCenter : Alignment.topCenter,
            followerAnchor: below
                ? Alignment.topCenter
                : Alignment.bottomCenter,
            offset: Offset(0, below ? 2 : -2),
            child: AnimatedBuilder(
              animation: Listenable.merge(<Listenable>[_scale, _alpha]),
              builder: (BuildContext context, Widget? child) => Opacity(
                opacity: _alpha.value.clamp(0.0, 1.0),
                child: Transform.scale(
                  scale: math.max(0, _scale.value),
                  alignment: below
                      ? Alignment.topCenter
                      : Alignment.bottomCenter,
                  child: child,
                ),
              ),
              child: _Bubble(
                message: widget.message,
                color: theme.accent,
                textStyle: theme.text(13, color: const Color(0xFFFFFFFF)),
                below: below,
              ),
            ),
          ),
        ],
      ),
      child: CompositedTransformTarget(
        link: _link,
        child: widget.controller == null
            ? GestureDetector(onLongPress: _show, child: widget.child)
            : widget.child,
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({
    required this.message,
    required this.color,
    required this.textStyle,
    required this.below,
  });

  final String message;
  final Color color;
  final TextStyle textStyle;
  final bool below;

  @override
  Widget build(BuildContext context) {
    final Widget arrow = CustomPaint(
      size: const Size(20, 10),
      painter: _ArrowPainter(color: color, up: below),
    );
    final Widget body = ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 328),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: ShapeDecoration(
          color: color,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          shadows: const <BoxShadow>[
            BoxShadow(
              color: Color(0x29000000),
              blurRadius: 24,
              offset: Offset(0, 6),
            ),
          ],
        ),
        child: Text(message, style: textStyle),
      ),
    );
    return Material(
      type: MaterialType.transparency,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: below
            ? <Widget>[arrow, body]
            : <Widget>[
                body,
                Transform.translate(
                  offset: const Offset(0, -0.33),
                  child: arrow,
                ),
              ],
      ),
    );
  }
}

class _ArrowPainter extends CustomPainter {
  const _ArrowPainter({required this.color, required this.up});

  final Color color;
  final bool up;

  @override
  void paint(Canvas canvas, Size size) {
    if (!up) {
      canvas.translate(0, size.height);
      canvas.scale(1, -1);
    }
    // A rounded apex: wide feet blending into the bubble, a soft tip.
    final Path path = Path()
      ..moveTo(0, 10.1)
      ..arcToPoint(
        const Offset(4.5, 7.5),
        radius: const Radius.circular(5.19),
        clockwise: false,
      )
      ..lineTo(8.27, 1)
      ..arcToPoint(const Offset(11.73, 1), radius: const Radius.circular(2))
      ..lineTo(15.5, 7.5)
      ..arcToPoint(
        const Offset(20, 10.1),
        radius: const Radius.circular(5.19),
        clockwise: false,
      )
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_ArrowPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.up != up;
}
