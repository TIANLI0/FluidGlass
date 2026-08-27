import 'package:flutter/material.dart';

import '../../fluid_glass.dart';

/// One row of a [LiquidMenu].
@immutable
class LiquidMenuItem {
  const LiquidMenuItem({
    required this.label,
    this.icon,
    this.isDestructive = false,
    this.isSelected = false,
    this.onSelected,
  });

  final String label;

  /// Drawn at the trailing edge, the way a system menu marks its rows.
  final IconData? icon;

  /// Tints the row red, for a row that removes something.
  final bool isDestructive;

  /// Draws a check at the leading edge.
  final bool isSelected;

  final VoidCallback? onSelected;
}

/// Where the panel sits relative to its anchor.
enum LiquidMenuSide { below, above }

/// A pop-up menu that blooms out of its anchor as a [LiquidPanel].
///
/// The motion is one spring, read directly: a uniform scale from 35% about the
/// anchor corner, with the spring's own slight overshoot supplying the settle
/// — no easing curve is layered on top, which is what made earlier attempts
/// feel rubbery. The panel's refraction, rim and shadow ramp with the same
/// spring through [LiquidPanel.reveal], and the opacity resolves within the
/// first 40% of the travel so the glass never reads as a ghost.
///
/// Pressing a row washes that row alone; there is no panel-wide flash.
///
/// The panel lives in the [Overlay], not in the anchor's own box: Flutter
/// bounds-checks every ancestor while hit-testing, so a panel merely drawn
/// outside its parent would render but never receive a tap.
class LiquidMenu extends StatefulWidget {
  const LiquidMenu({
    super.key,
    required this.backdrop,
    required this.items,
    required this.anchorBuilder,
    this.side = LiquidMenuSide.below,
    this.alignment = Alignment.topLeft,
    this.panelWidth = 240,
    this.gap = 8,
  });

  /// What the panel's glass refracts.
  final Backdrop backdrop;

  final List<LiquidMenuItem> items;

  /// Builds the trigger. [isOpen] lets the anchor reflect the menu's state,
  /// and [toggle] opens or closes it.
  final Widget Function(BuildContext context, bool isOpen, VoidCallback toggle)
      anchorBuilder;

  final LiquidMenuSide side;

  /// Which edge of the anchor the panel lines up with. Only the horizontal
  /// component is read; [side] decides the vertical one.
  final Alignment alignment;

  final double panelWidth;

  /// The space between the anchor and the panel, in logical pixels.
  final double gap;

  @override
  State<LiquidMenu> createState() => _LiquidMenuState();
}

class _LiquidMenuState extends State<LiquidMenu> with TickerProviderStateMixin {
  static const double _rowHeight = 44.0;
  static const double _panelPadding = 6.0;

  /// Every live menu, so a menu being dismissed can hand the gesture to the
  /// sibling whose anchor was actually pressed.
  ///
  /// The dismiss barrier is opaque on purpose — a tap that closes a menu must
  /// not also press whatever it landed on — but that made switching between
  /// two menus cost two taps: the first was spent dismissing, and the second
  /// anchor never saw it. A menu bar behaves as one tracking surface, so the
  /// barrier resolves the press itself rather than forwarding the event.
  static final Set<_LiquidMenuState> _live = <_LiquidMenuState>{};

  final OverlayPortalController _portal = OverlayPortalController();
  final LayerLink _link = LayerLink();

  late final SpringValue _open = SpringValue(
    vsync: this,
    value: 0,
    visibilityThreshold: 0.001,
  );

  /// Both directions are critically damped. An underdamped open was measured
  /// blooming to 102.8% and then easing back for ~175ms — on a fully opaque
  /// panel that back-settle reads as a second animation, not as bounce.
  late final SpringDescription _openSpec = springOf(1.0, 550.0);
  late final SpringDescription _closeSpec = springOf(1.0, 650.0);

  bool _isOpen = false;

  /// Where the anchor sat when the menu opened, for screen-edge avoidance.
  Rect _anchorRect = Rect.zero;

  @override
  void initState() {
    super.initState();
    _live.add(this);
  }

  @override
  void dispose() {
    _live.remove(this);
    _open.dispose();
    super.dispose();
  }

  /// This menu's anchor, in global coordinates, right now.
  Rect? get _anchorRectNow {
    final RenderBox? box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.attached || !box.hasSize) return null;
    return box.localToGlobal(Offset.zero) & box.size;
  }

  /// The other menu whose anchor sits under [globalPosition], if any.
  _LiquidMenuState? _siblingAnchoredAt(Offset globalPosition) {
    for (final _LiquidMenuState menu in _live) {
      if (menu == this || !menu.mounted || menu._isOpen) continue;
      final Rect? rect = menu._anchorRectNow;
      if (rect != null && rect.contains(globalPosition)) return menu;
    }
    return null;
  }

  void _show() {
    if (_isOpen) return;
    final RenderBox? box = context.findRenderObject() as RenderBox?;
    if (box != null && box.hasSize) {
      _anchorRect = box.localToGlobal(Offset.zero) & box.size;
    }
    setState(() => _isOpen = true);
    // Never re-show a portal that is still mounted: show() assigns a fresh
    // z-order slot even when already showing, which REMOUNTS the overlay
    // child — reopening while the closing spring was still running made the
    // panel flash and replay its bloom. With the portal left alone, the same
    // spring simply retargets and the motion stays continuous.
    if (!_portal.isShowing) {
      _portal.show();
    }
    _open.animateTo(1.0, _openSpec);
  }

  void _close() {
    if (!_isOpen) return;
    setState(() => _isOpen = false);
    _open.animateTo(0.0, _closeSpec);
    // The panel stays mounted until the spring has run out, so it animates
    // away instead of vanishing.
    _open.whenSettled(() {
      if (mounted && !_isOpen) _portal.hide();
    });
  }

  void _toggle() => _isOpen ? _close() : _show();

  double get _panelHeight =>
      widget.items.length * _rowHeight + _panelPadding * 2;

  @override
  Widget build(BuildContext context) {
    final bool below = widget.side == LiquidMenuSide.below;
    final bool leading = widget.alignment.x <= 0;

    return OverlayPortal(
      controller: _portal,
      overlayChildBuilder: (BuildContext context) {
        // Screen-edge avoidance: on a narrow screen an anchor-aligned panel
        // can hang past the edge, shearing its rim off.
        final Size screen = MediaQuery.sizeOf(context);
        const double margin = 12.0;
        double dx = 0;
        if (leading) {
          final double overflow =
              _anchorRect.left + widget.panelWidth - (screen.width - margin);
          if (overflow > 0) dx = -overflow;
        } else {
          final double underflow =
              margin - (_anchorRect.right - widget.panelWidth);
          if (underflow > 0) dx = underflow;
        }

        return Stack(
          children: <Widget>[
            // Touching anywhere else dismisses, on the pointer DOWN — and the
            // barrier stops intercepting the moment the menu starts closing.
            // A barrier that lingered for the whole closing spring ate the
            // taps that followed, so quickly toggling the anchor made the
            // menu pop open and shut out of step with the finger.
            //
            // The press is absorbed rather than passed through, so dismissing
            // never doubles as pressing something. The one thing it resolves
            // itself is a press on a sibling menu's anchor, which opens that
            // menu — otherwise switching between two menus cost two taps.
            Positioned.fill(
              child: IgnorePointer(
                ignoring: !_isOpen,
                child: Listener(
                  behavior: HitTestBehavior.opaque,
                  onPointerDown: (PointerDownEvent event) {
                    final _LiquidMenuState? sibling =
                        _siblingAnchoredAt(event.position);
                    _close();
                    sibling?._show();
                  },
                ),
              ),
            ),
            CompositedTransformFollower(
              link: _link,
              showWhenUnlinked: false,
              targetAnchor: below
                  ? (leading ? Alignment.bottomLeft : Alignment.bottomRight)
                  : (leading ? Alignment.topLeft : Alignment.topRight),
              followerAnchor: below
                  ? (leading ? Alignment.topLeft : Alignment.topRight)
                  : (leading ? Alignment.bottomLeft : Alignment.bottomRight),
              offset: Offset(dx, below ? widget.gap : -widget.gap),
              child: _MenuPanel(
                open: _open,
                isOpen: _isOpen,
                backdrop: widget.backdrop,
                items: widget.items,
                width: widget.panelWidth,
                height: _panelHeight,
                rowHeight: _rowHeight,
                padding: _panelPadding,
                growFromTop: below,
                growFromLeft: leading,
                onSelected: (LiquidMenuItem item) {
                  _close();
                  item.onSelected?.call();
                },
              ),
            ),
          ],
        );
      },
      child: CompositedTransformTarget(
        link: _link,
        child: widget.anchorBuilder(context, _isOpen, _toggle),
      ),
    );
  }
}

class _MenuPanel extends StatelessWidget {
  const _MenuPanel({
    required this.open,
    required this.isOpen,
    required this.backdrop,
    required this.items,
    required this.width,
    required this.height,
    required this.rowHeight,
    required this.padding,
    required this.growFromTop,
    required this.growFromLeft,
    required this.onSelected,
  });

  final SpringValue open;

  /// Whether the menu is on its way in rather than on its way out.
  final bool isOpen;

  final Backdrop backdrop;
  final List<LiquidMenuItem> items;
  final double width;
  final double height;
  final double rowHeight;
  final double padding;
  final bool growFromTop;
  final bool growFromLeft;
  final ValueChanged<LiquidMenuItem> onSelected;

  /// The bloom out of the anchor corner: one uniform scale straight off the
  /// spring. The spring is allowed past 1.0, so the settle-back is its own
  /// physics, not a second curve fighting it.
  void _layerBlock(GlassLayer layer) {
    final double p = open.value;
    layer.transformOrigin = Offset(
      growFromLeft ? 0.08 : 0.92,
      growFromTop ? 0.02 : 0.98,
    );
    final double scale = 0.35 + 0.65 * p;
    layer.scaleX = scale;
    layer.scaleY = scale;
    // Opaque by 40% of the travel: late enough to soften the arrival, early
    // enough that the panel never hangs around as a ghost.
    layer.alpha = (p / 0.4).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final bool isLight = Theme.of(context).brightness == Brightness.light;
    final Color contentColor =
        isLight ? const Color(0xFF000000) : const Color(0xFFFFFFFF);
    final Color destructiveColor =
        isLight ? const Color(0xFFE5484D) : const Color(0xFFFF6369);
    final Color separatorColor = contentColor.withValues(alpha: 0.08);

    return ListenableBuilder(
      listenable: open,
      builder: (BuildContext context, Widget? child) {
        return IgnorePointer(
          // Rows land where they are drawn at every point of the bloom —
          // `RenderGlassTransform` inverts its own matrix when hit-testing —
          // so this gate is not about geometry. It is about intent: a panel
          // that is still fading in is not yet something you can have aimed
          // at, and one that has been dismissed is no longer something you
          // can aim at. Without the [isOpen] half, a tap meant for whatever
          // the menu had been covering selected a row instead, because the
          // panel stays mounted and live for the whole closing spring while
          // the dismiss barrier steps aside immediately.
          ignoring: !isOpen || open.value < 0.5,
          child: child,
        );
      },
      child: LiquidPanel(
        backdrop: backdrop,
        shape: RoundedRectangle(_radiusFor(width)),
        reveal: () => open.value.clamp(0.0, 1.0),
        repaint: open,
        layerBlock: _layerBlock,
        child: SizedBox(
          width: width,
          height: height,
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: padding),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                for (int i = 0; i < items.length; i++) ...<Widget>[
                  if (i > 0)
                    Divider(
                      height: 0,
                      thickness: 0.5,
                      indent: 16,
                      endIndent: 16,
                      color: separatorColor,
                    ),
                  _MenuRow(
                    item: items[i],
                    height: rowHeight,
                    contentColor: items[i].isDestructive
                        ? destructiveColor
                        : contentColor,
                    washColor: contentColor.withValues(alpha: 0.08),
                    onSelected: onSelected,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Big enough to read as a squircle at this size, not so big it turns into
  /// a capsule.
  static double _radiusFor(double width) =>
      width / 4 < 22.0 ? width / 4 : 22.0;
}

class _MenuRow extends StatefulWidget {
  const _MenuRow({
    required this.item,
    required this.height,
    required this.contentColor,
    required this.washColor,
    required this.onSelected,
  });

  final LiquidMenuItem item;
  final double height;
  final Color contentColor;
  final Color washColor;
  final ValueChanged<LiquidMenuItem> onSelected;

  @override
  State<_MenuRow> createState() => _MenuRowState();
}

class _MenuRowState extends State<_MenuRow> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    // Slop-free, like Compose's `clickable`: a finger that wanders while
    // choosing must not have its selection swallowed.
    //
    // The pressed wash is an inset rounded rectangle, not a full-bleed bar:
    // full-bleed collided with the panel's rounded corners on the first and
    // last rows, shearing the wash into a hard-edged strip.
    return DragInspector(
      behavior: HitTestBehavior.opaque,
      onDragStart: (Offset position, Size size) =>
          setState(() => _pressed = true),
      onDragEnd: () => setState(() => _pressed = false),
      onDragCancel: () => setState(() => _pressed = false),
      onTap: () => widget.onSelected(widget.item),
      child: SizedBox(
        height: widget.height,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 110),
            curve: Curves.easeOut,
            decoration: BoxDecoration(
              color: _pressed
                  ? widget.washColor
                  : widget.washColor.withValues(alpha: 0.0),
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Row(
              children: <Widget>[
                if (widget.item.isSelected)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Icon(Icons.check,
                        size: 18, color: widget.contentColor),
                  ),
                Expanded(
                  child: Text(
                    widget.item.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style:
                        TextStyle(color: widget.contentColor, fontSize: 16),
                  ),
                ),
                if (widget.item.icon != null)
                  Icon(widget.item.icon,
                      size: 19, color: widget.contentColor),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
