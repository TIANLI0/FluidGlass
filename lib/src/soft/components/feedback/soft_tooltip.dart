import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import '../../foundation/soft_motion.dart';
import '../../foundation/soft_pressable.dart';
import '../../foundation/soft_squircle.dart';
import '../../foundation/soft_theme.dart';

/// The preferred side of a tooltip. It flips to the opposite side when the
/// preferred one has no room; [start] and [end] follow the text direction.
enum SoftTooltipPosition { above, below, left, right, start, end }

/// The tooltip defaults.
abstract final class SoftTooltipDefaults {
  /// The gap between a tooltip and its anchor.
  static const double spacing = 8;

  /// The least gap to the left and right edges.
  static const double horizontalEdgeMargin = 16;

  /// The caret's width and height.
  static const Size caretSize = Size(16, 8);

  /// How long a tooltip shown from code stays, unless persistent.
  static const Duration duration = Duration(milliseconds: 1500);

  static const double plainMaxWidth = 200;
  static const double plainCornerRadius = 12;
  static const EdgeInsets plainPadding = EdgeInsets.symmetric(
    horizontal: 12,
    vertical: 8,
  );

  static const double richMaxWidth = 320;
  static const double richCornerRadius = 16;
  static const EdgeInsets richPadding = EdgeInsets.all(16);
  static const double richActionCornerRadius = 8;
  static const EdgeInsets richActionPadding = EdgeInsets.symmetric(
    horizontal: 12,
    vertical: 6,
  );

  /// The shadow: blur 10, black at 10 %.
  static const BoxShadow shadow = BoxShadow(
    color: Color(0x1A000000),
    blurRadius: 10,
  );

  /// The scale a tooltip enters from and leaves to.
  static const double hiddenScale = 0.9;

  /// Fading in: (0.27, 0).
  static final SpringDescription alphaEnter = softSpring(
    damping: 1,
    response: 0.27,
  );

  /// Fading out: (0.23, 0).
  static final SpringDescription alphaExit = softSpring(
    damping: 1,
    response: 0.23,
  );

  /// Growing in: (0.4, 0.1).
  static final SpringDescription scaleEnter = softSpring(
    damping: 0.9,
    response: 0.4,
  );

  /// Shrinking out: critically damped, stiffness 1500, so a dismiss during
  /// the entrance reverses with the velocity it had.
  static final SpringDescription scaleExit = softSpringStiffness(
    damping: 1,
    stiffness: 1500,
  );
}

/// Shows and hides the tooltip of a [SoftTooltipBox].
///
/// Only one tooltip is up at a time: showing one dismisses any other. A
/// tooltip shown from code ([show]) leaves after
/// [SoftTooltipDefaults.duration] unless [isPersistent]; one shown by a long
/// press or a hover stays until dismissed or tapped outside.
class SoftTooltipController extends ChangeNotifier {
  SoftTooltipController({this.isPersistent = false});

  /// Whether a tooltip shown from code stays until dismissed.
  final bool isPersistent;

  static SoftTooltipController? _current;

  bool _visible = false;
  Timer? _timer;
  bool _disposed = false;

  /// Whether the tooltip is meant to be up (it may still be animating).
  bool get isVisible => _visible;

  /// Shows the tooltip.
  void show() => _show(fromUser: false);

  void _show({required bool fromUser}) {
    final SoftTooltipController? other = _current;
    if (other != null && other != this) other.dismiss();
    _current = this;
    _timer?.cancel();
    _timer = null;
    if (!isPersistent && !fromUser) {
      _timer = Timer(SoftTooltipDefaults.duration, dismiss);
    }
    if (_visible) return;
    _visible = true;
    _notify();
  }

  /// Hides the tooltip.
  void dismiss() {
    _timer?.cancel();
    _timer = null;
    if (_current == this) _current = null;
    if (!_visible) return;
    _visible = false;
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    if (_current == this) _current = null;
    super.dispose();
  }
}

/// Anchors a tooltip to [child].
///
/// A long press on [child] (or a mouse hover) shows it, unless
/// [enableUserInput] is false; [controller] shows and hides it from code. It
/// fades in while growing from 0.9 and leaves the same way, each on its own
/// spring. The tooltip sits [spacing] off the [position] side of the anchor,
/// centred on it, flipped when there is no room and kept 16 off the side
/// edges.
///
/// A [focusable] tooltip (one with an action) catches the tap outside it that
/// dismisses it; a plain one lets that tap through.
class SoftTooltipBox extends StatefulWidget {
  const SoftTooltipBox({
    super.key,
    required this.tooltip,
    required this.child,
    this.controller,
    this.position = SoftTooltipPosition.below,
    this.spacing = SoftTooltipDefaults.spacing,
    this.focusable = false,
    this.enableUserInput = true,
  });

  /// The tooltip surface, usually a [SoftPlainTooltip] or [SoftRichTooltip].
  final Widget tooltip;
  final Widget child;
  final SoftTooltipController? controller;
  final SoftTooltipPosition position;
  final double spacing;
  final bool focusable;
  final bool enableUserInput;

  @override
  State<SoftTooltipBox> createState() => _SoftTooltipBoxState();
}

class _SoftTooltipBoxState extends State<SoftTooltipBox>
    with TickerProviderStateMixin {
  final OverlayPortalController _portal = OverlayPortalController();
  late final SoftSpring _alpha = SoftSpring(vsync: this);
  late final SoftSpring _scale = SoftSpring(
    vsync: this,
    value: SoftTooltipDefaults.hiddenScale,
  );
  final ValueNotifier<double> _caretX = ValueNotifier<double>(0);
  SoftTooltipController? _ownController;
  int _generation = 0;

  SoftTooltipController get _controller =>
      widget.controller ??
      (_ownController ??= SoftTooltipController(
        isPersistent: widget.focusable,
      ));

  @override
  void initState() {
    super.initState();
    _controller.addListener(_changed);
    if (_controller.isVisible) _changed();
  }

  @override
  void didUpdateWidget(SoftTooltipBox oldWidget) {
    super.didUpdateWidget(oldWidget);
    final SoftTooltipController old = oldWidget.controller ?? _ownController!;
    if (old != _controller) {
      old.removeListener(_changed);
      _controller.addListener(_changed);
      _changed();
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_changed);
    _controller.dismiss();
    _ownController?.dispose();
    _alpha.dispose();
    _scale.dispose();
    _caretX.dispose();
    super.dispose();
  }

  Future<void> _changed() async {
    final int generation = ++_generation;
    if (_controller.isVisible) {
      if (!_portal.isShowing) {
        _alpha.snapTo(0);
        _scale.snapTo(SoftTooltipDefaults.hiddenScale);
        _portal.show();
      }
      _alpha.animateTo(1, SoftTooltipDefaults.alphaEnter);
      _scale.animateTo(1, SoftTooltipDefaults.scaleEnter);
      return;
    }
    if (!_portal.isShowing) return;
    await Future.wait(<Future<void>>[
      _alpha.animateTo(0, SoftTooltipDefaults.alphaExit),
      _scale.animateTo(
        SoftTooltipDefaults.hiddenScale,
        SoftTooltipDefaults.scaleExit,
        threshold: 0.0001,
      ),
    ]);
    if (mounted && generation == _generation && !_controller.isVisible) {
      _portal.hide();
    }
  }

  SoftTooltipPosition _resolved(TextDirection direction) {
    final bool ltr = direction == TextDirection.ltr;
    return switch (widget.position) {
      SoftTooltipPosition.start =>
        ltr ? SoftTooltipPosition.left : SoftTooltipPosition.right,
      SoftTooltipPosition.end =>
        ltr ? SoftTooltipPosition.right : SoftTooltipPosition.left,
      final SoftTooltipPosition other => other,
    };
  }

  Widget _buildOverlay(BuildContext context) {
    final TextDirection direction = Directionality.of(context);
    final RenderBox? anchorBox = this.context.findRenderObject() as RenderBox?;
    final RenderBox? overlayBox =
        Overlay.of(this.context).context.findRenderObject() as RenderBox?;
    if (anchorBox == null || overlayBox == null || !anchorBox.hasSize) {
      return const SizedBox.shrink();
    }
    final Rect anchor = MatrixUtils.transformRect(
      anchorBox.getTransformTo(overlayBox),
      Offset.zero & anchorBox.size,
    );
    final SoftTooltipPosition resolved = _resolved(direction);
    Widget tooltip = AnimatedBuilder(
      animation: Listenable.merge(<Listenable>[_alpha, _scale]),
      builder: (BuildContext context, Widget? child) => Opacity(
        opacity: _alpha.value.clamp(0.0, 1.0),
        child: Transform.scale(scale: _scale.value, child: child),
      ),
      child: _SoftTooltipScope(
        position: resolved,
        caretX: _caretX,
        child: Semantics(
          container: true,
          liveRegion: true,
          child: widget.tooltip,
        ),
      ),
    );
    if (!widget.focusable) {
      tooltip = TapRegion(
        onTapOutside: (PointerDownEvent _) => _controller.dismiss(),
        child: tooltip,
      );
    }
    Widget positioned = _TooltipLayout(
      anchor: anchor,
      position: resolved,
      spacing: widget.spacing,
      caretX: _caretX,
      child: tooltip,
    );
    if (widget.focusable) {
      positioned = Stack(
        children: <Widget>[
          Positioned.fill(
            child: Listener(
              behavior: HitTestBehavior.opaque,
              onPointerDown: (PointerDownEvent _) => _controller.dismiss(),
            ),
          ),
          Positioned.fill(child: positioned),
        ],
      );
    }
    return positioned;
  }

  @override
  Widget build(BuildContext context) {
    Widget result = OverlayPortal(
      controller: _portal,
      overlayChildBuilder: _buildOverlay,
      child: widget.child,
    );
    if (widget.enableUserInput) {
      result = MouseRegion(
        onEnter: (PointerEnterEvent _) => _controller._show(fromUser: true),
        onExit: (PointerExitEvent _) {
          if (!_controller.isPersistent) _controller.dismiss();
        },
        // The whole anchor answers a long press, painted or not.
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onLongPress: () => _controller._show(fromUser: true),
          child: result,
        ),
      );
    }
    return result;
  }
}

/// What a tooltip surface needs to draw its caret.
class _SoftTooltipScope extends InheritedWidget {
  const _SoftTooltipScope({
    required this.position,
    required this.caretX,
    required super.child,
  });

  final SoftTooltipPosition position;
  final ValueNotifier<double> caretX;

  @override
  bool updateShouldNotify(_SoftTooltipScope oldWidget) =>
      oldWidget.position != position || oldWidget.caretX != caretX;
}

/// Places the tooltip next to [anchor] and reports where the anchor's centre
/// falls across the tooltip, for the caret.
class _TooltipLayout extends SingleChildRenderObjectWidget {
  const _TooltipLayout({
    required this.anchor,
    required this.position,
    required this.spacing,
    required this.caretX,
    required super.child,
  });

  final Rect anchor;
  final SoftTooltipPosition position;
  final double spacing;
  final ValueNotifier<double> caretX;

  @override
  _RenderTooltipLayout createRenderObject(BuildContext context) =>
      _RenderTooltipLayout(
        anchor: anchor,
        position: position,
        spacing: spacing,
        caretX: caretX,
      );

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderTooltipLayout renderObject,
  ) {
    renderObject
      ..anchor = anchor
      ..position = position
      ..spacing = spacing
      ..caretX = caretX;
  }
}

class _RenderTooltipLayout extends RenderShiftedBox {
  _RenderTooltipLayout({
    required Rect anchor,
    required SoftTooltipPosition position,
    required double spacing,
    required this.caretX,
  }) : _anchor = anchor,
       _position = position,
       _spacing = spacing,
       super(null);

  ValueNotifier<double> caretX;

  Rect _anchor;
  set anchor(Rect value) {
    if (value == _anchor) return;
    _anchor = value;
    markNeedsLayout();
  }

  SoftTooltipPosition _position;
  set position(SoftTooltipPosition value) {
    if (value == _position) return;
    _position = value;
    markNeedsLayout();
  }

  double _spacing;
  set spacing(double value) {
    if (value == _spacing) return;
    _spacing = value;
    markNeedsLayout();
  }

  @override
  void performLayout() {
    size = constraints.biggest;
    final RenderBox? child = this.child;
    if (child == null) return;
    child.layout(BoxConstraints.loose(size), parentUsesSize: true);
    final Size popup = child.size;
    final Rect a = _anchor;
    final double gap = _spacing;
    double x = a.left + (a.width - popup.width) / 2;
    double y = a.top + (a.height - popup.height) / 2;
    final double aboveY = a.top - popup.height - gap;
    final double belowY = a.bottom + gap;
    final double leftX = a.left - popup.width - gap;
    final double rightX = a.right + gap;
    switch (_position) {
      case SoftTooltipPosition.below:
        y = (belowY + popup.height <= size.height || aboveY < 0)
            ? belowY
            : aboveY;
      case SoftTooltipPosition.above:
        y = (aboveY >= 0 || belowY + popup.height > size.height)
            ? aboveY
            : belowY;
      case SoftTooltipPosition.left:
        x = (leftX >= 0 || rightX + popup.width > size.width) ? leftX : rightX;
      case SoftTooltipPosition.right:
        x = (rightX + popup.width <= size.width || leftX < 0) ? rightX : leftX;
      case SoftTooltipPosition.start:
      case SoftTooltipPosition.end:
        y = belowY;
    }
    final double minX = math.min(
      SoftTooltipDefaults.horizontalEdgeMargin,
      math.max(0, size.width - popup.width) / 2,
    );
    x = x.clamp(minX, math.max(minX, size.width - popup.width - minX));
    y = y.clamp(0, math.max(0, size.height - popup.height));
    (child.parentData! as BoxParentData).offset = Offset(x, y);
    caretX.value = a.center.dx - x;
  }

  @override
  bool hitTestSelf(Offset position) => false;
}

/// The tooltip surface: a smooth-cornered box with a soft shadow, an
/// optional caret pointing at the anchor when the tooltip is above or below
/// it, and [padding] around [child].
class _TooltipSurface extends StatelessWidget {
  const _TooltipSurface({
    required this.showCaret,
    required this.maxWidth,
    required this.cornerRadius,
    required this.color,
    required this.padding,
    required this.child,
  });

  final bool showCaret;
  final double maxWidth;
  final double cornerRadius;
  final Color color;
  final EdgeInsetsGeometry padding;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final SoftThemeData theme = SoftTheme.of(context);
    final _SoftTooltipScope? scope = context
        .dependOnInheritedWidgetOfExactType<_SoftTooltipScope>();
    final SoftTooltipPosition position =
        scope?.position ?? SoftTooltipPosition.below;
    final bool caret =
        showCaret &&
        scope != null &&
        (position == SoftTooltipPosition.above ||
            position == SoftTooltipPosition.below);
    final bool caretOnTop = position == SoftTooltipPosition.below;
    const double caretHeight = 8;
    Widget box = DecoratedBox(
      decoration: ShapeDecoration(
        color: color,
        shape: SoftSquircleBorder.all(
          cornerRadius,
          smooth: theme.smoothCorners,
        ),
        shadows: const <BoxShadow>[SoftTooltipDefaults.shadow],
      ),
      child: Padding(padding: padding, child: child),
    );
    if (caret) {
      box = CustomPaint(
        painter: _CaretPainter(
          caretX: scope.caretX,
          onTop: caretOnTop,
          color: color,
          cornerRadius: cornerRadius,
        ),
        child: Padding(
          padding: EdgeInsets.only(
            top: caretOnTop ? caretHeight : 0,
            bottom: caretOnTop ? 0 : caretHeight,
          ),
          child: box,
        ),
      );
    }
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: box,
    );
  }
}

class _CaretPainter extends CustomPainter {
  _CaretPainter({
    required this.caretX,
    required this.onTop,
    required this.color,
    required this.cornerRadius,
  }) : super(repaint: caretX);

  final ValueNotifier<double> caretX;
  final bool onTop;
  final Color color;
  final double cornerRadius;

  @override
  void paint(Canvas canvas, Size size) {
    const Size caret = SoftTooltipDefaults.caretSize;
    final double half = caret.width / 2;
    final double low = cornerRadius + half;
    final double high = size.width - cornerRadius - half;
    final double x = high < low
        ? size.width / 2
        : caretX.value.clamp(low, high);
    final Path path = Path();
    if (onTop) {
      path
        ..moveTo(x, 0)
        ..lineTo(x - half, caret.height)
        ..lineTo(x + half, caret.height);
    } else {
      path
        ..moveTo(x, size.height)
        ..lineTo(x - half, size.height - caret.height)
        ..lineTo(x + half, size.height - caret.height);
    }
    path.close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_CaretPainter old) =>
      old.caretX != caretX ||
      old.onTop != onTop ||
      old.color != color ||
      old.cornerRadius != cornerRadius;
}

/// A plain tooltip surface: a short label on the theme's `primary`, 12
/// corners, at most 200 wide. The default text colour inside is `onPrimary`.
class SoftPlainTooltip extends StatelessWidget {
  const SoftPlainTooltip({
    super.key,
    required this.child,
    this.showCaret = false,
    this.maxWidth = SoftTooltipDefaults.plainMaxWidth,
    this.cornerRadius = SoftTooltipDefaults.plainCornerRadius,
    this.containerColor,
    this.contentColor,
    this.padding = SoftTooltipDefaults.plainPadding,
  });

  final Widget child;

  /// Draws a caret pointing at the anchor.
  final bool showCaret;
  final double maxWidth;
  final double cornerRadius;

  /// `primary` by default.
  final Color? containerColor;

  /// `onPrimary` by default.
  final Color? contentColor;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final SoftThemeData theme = SoftTheme.of(context);
    return _TooltipSurface(
      showCaret: showCaret,
      maxWidth: maxWidth,
      cornerRadius: cornerRadius,
      color: containerColor ?? theme.colors.primary,
      padding: padding,
      child: DefaultTextStyle.merge(
        style: theme.textStyles.body2.copyWith(
          color: contentColor ?? theme.colors.onPrimary,
        ),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        child: child,
      ),
    );
  }
}

/// A rich tooltip surface: an optional title over the body [text] and an
/// optional end-aligned [action], 8 apart, on the theme's `surfaceContainer`
/// with 16 corners, at most 320 wide.
class SoftRichTooltip extends StatelessWidget {
  const SoftRichTooltip({
    super.key,
    required this.text,
    this.title,
    this.action,
    this.showCaret = false,
    this.maxWidth = SoftTooltipDefaults.richMaxWidth,
    this.cornerRadius = SoftTooltipDefaults.richCornerRadius,
    this.containerColor,
    this.contentColor,
    this.titleColor,
    this.padding = SoftTooltipDefaults.richPadding,
  });

  /// The body; its default style is body 2 in [contentColor].
  final Widget text;

  /// Its default style is the subtitle style in [titleColor].
  final Widget? title;
  final Widget? action;
  final bool showCaret;
  final double maxWidth;
  final double cornerRadius;

  /// `surfaceContainer` by default.
  final Color? containerColor;

  /// `onSurfaceContainerVariant` by default.
  final Color? contentColor;

  /// `onSurfaceContainer` by default.
  final Color? titleColor;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final SoftThemeData theme = SoftTheme.of(context);
    final Widget? title = this.title;
    final Widget? action = this.action;
    return _TooltipSurface(
      showCaret: showCaret,
      maxWidth: maxWidth,
      cornerRadius: cornerRadius,
      color: containerColor ?? theme.colors.surfaceContainer,
      padding: padding,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 8,
        children: <Widget>[
          if (title != null)
            DefaultTextStyle.merge(
              style: theme.textStyles.subtitle.copyWith(
                color: titleColor ?? theme.colors.onSurfaceContainer,
              ),
              child: title,
            ),
          DefaultTextStyle.merge(
            style: theme.textStyles.body2.copyWith(
              color: contentColor ?? theme.colors.onSurfaceContainerVariant,
            ),
            child: text,
          ),
          if (action != null)
            Align(alignment: AlignmentDirectional.centerEnd, child: action),
        ],
      ),
    );
  }
}

/// A plain tooltip with a text [message] on [child].
class SoftTooltip extends StatelessWidget {
  const SoftTooltip({
    super.key,
    required this.message,
    required this.child,
    this.controller,
    this.enabled = true,
    this.position = SoftTooltipPosition.below,
    this.showCaret = false,
    this.containerColor,
    this.contentColor,
  });

  final String message;
  final Widget child;
  final SoftTooltipController? controller;

  /// Whether a long press or hover shows it.
  final bool enabled;
  final SoftTooltipPosition position;
  final bool showCaret;
  final Color? containerColor;
  final Color? contentColor;

  @override
  Widget build(BuildContext context) {
    return SoftTooltipBox(
      controller: controller,
      position: position,
      enableUserInput: enabled,
      tooltip: SoftPlainTooltip(
        showCaret: showCaret,
        containerColor: containerColor,
        contentColor: contentColor,
        child: Text(message, maxLines: 2, overflow: TextOverflow.ellipsis),
      ),
      child: child,
    );
  }
}

/// A persistent rich tooltip on [child]: an optional [title], the [text] and
/// an optional text action that calls [onAction] and then dismisses it.
///
/// It stays until the action, a tap outside, or [SoftTooltipController.dismiss].
class SoftRichTooltipBox extends StatefulWidget {
  const SoftRichTooltipBox({
    super.key,
    required this.text,
    required this.child,
    this.controller,
    this.title,
    this.actionText,
    this.onAction,
    this.enabled = true,
    this.position = SoftTooltipPosition.below,
    this.showCaret = false,
  });

  final String text;
  final Widget child;

  /// Should be persistent; one is made when null.
  final SoftTooltipController? controller;
  final String? title;
  final String? actionText;
  final VoidCallback? onAction;
  final bool enabled;
  final SoftTooltipPosition position;
  final bool showCaret;

  @override
  State<SoftRichTooltipBox> createState() => _SoftRichTooltipBoxState();
}

class _SoftRichTooltipBoxState extends State<SoftRichTooltipBox> {
  SoftTooltipController? _own;

  SoftTooltipController get _controller =>
      widget.controller ?? (_own ??= SoftTooltipController(isPersistent: true));

  @override
  void dispose() {
    _own?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final SoftThemeData theme = SoftTheme.of(context);
    final String? title = widget.title;
    final String? actionText = widget.actionText;
    return SoftTooltipBox(
      controller: _controller,
      position: widget.position,
      focusable: true,
      enableUserInput: widget.enabled,
      tooltip: SoftRichTooltip(
        showCaret: widget.showCaret,
        title: title == null ? null : Text(title),
        text: Text(widget.text),
        action: actionText == null
            ? null
            : SoftPressable(
                onTap: () {
                  widget.onAction?.call();
                  _controller.dismiss();
                },
                borderRadius: BorderRadius.circular(
                  SoftTooltipDefaults.richActionCornerRadius,
                ),
                child: Padding(
                  padding: SoftTooltipDefaults.richActionPadding,
                  child: Text(
                    actionText,
                    style: theme.textStyles.button.copyWith(
                      color: theme.colors.primary,
                    ),
                  ),
                ),
              ),
      ),
      child: widget.child,
    );
  }
}
