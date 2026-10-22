import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import '../../../backdrop.dart';
import '../../../quality/glass_device_tier.dart';
import '../../../quality/glass_quality.dart';
import '../../foundation/soft_glass.dart';
import '../../foundation/soft_meta_ball.dart';
import '../../foundation/soft_motion.dart';
import '../../foundation/soft_programs.dart';
import '../../foundation/soft_spot_light.dart';
import '../../foundation/soft_theme.dart';
import '../../foundation/soft_touch_motion.dart';
import '../badge/soft_badge.dart';

/// The floating navigation bar's metrics, colours and springs.
abstract final class SoftFloatingNavigationBarDefaults {
  /// The capsule's height.
  static const double barHeight = 56;

  /// The bar's height above the system inset: the capsule with 16 above and
  /// 16 below it.
  static const double minHeight = 88;

  /// The outside padding on a compact screen; none from [largeScreenWidth].
  static const double paddingHorizontal = 16;

  /// The window width from which the bar is laid out for a large screen: no
  /// outside padding, and items as wide as the bar allows.
  static const double largeScreenWidth = 600;

  /// How far the capsule sits above the system inset.
  static const double menuToScreenNaviDistance = 8;

  /// The round views at either side.
  static const double accessorySize = 56;

  /// The least gap between the capsule and a round view.
  static const double sideSpacing = 12;

  static const double cornerRadius = 28;
  static const double itemHeight = 48;
  static const double itemMaxWidth = 70;

  /// The item cap on a large screen: never reached, so the capsule fills
  /// the bar.
  static const double itemMaxWidthLarge = 1000;
  static const double itemSpacing = 8;

  /// The capsule's own padding at either end, inside its width.
  static const double itemInnerPadding = 12;
  static const double iconSize = 24;
  static const double iconTopMargin = 4;
  static const double iconTitleGap = 2;
  static const double largeIconSize = 40;
  static const double largeIconOverflow = 14;
  static const double redDotDiameter = 6;
  static const double redDotRightOverflow1Digit = 6;
  static const double redDotRightOverflow2Digit = 9;
  static const double redDotRightOverflow3Digit = 10;
  static const double redDotTopOverflow = 4;
  static const double labelFontSize = 10;
  static const double labelLineHeight = 13.6;

  /// How far a finger may stray from the item it pressed before lifting no
  /// longer clicks it, as a platform view's click allows.
  static const double clickSlop = 8;

  /// The blur of the bar's material, as the platform's blur radius in
  /// physical pixels.
  static const double nativeBlurRadiusPx = 25;

  /// The [SoftGlass.blurRadius] that lands on [nativeBlurRadiusPx]: the
  /// platform turns a radius `r` into a sigma of `0.57735 · r + 0.5` pixels.
  static double blurRadiusFor(double devicePixelRatio) =>
      (0.57735 * nativeBlurRadiusPx + 0.5) / devicePixelRatio / 0.45;

  /// The bar's tint over its blur: keeps the backdrop's colour and only
  /// remaps its lightness.
  static const List<SoftBlendLayer> blendLight = <SoftBlendLayer>[
    SoftBlendLayer(Color(0xB3666666), BlendMode.colorDodge),
    SoftBlendLayer(Color(0x99F5F5F5), BlendMode.luminosity),
  ];
  static const List<SoftBlendLayer> blendDark = <SoftBlendLayer>[
    SoftBlendLayer(Color(0x80666666), BlendMode.overlay),
    SoftBlendLayer(Color(0xB3262626), BlendMode.luminosity),
  ];

  /// The tint alpha where the blend layers cannot run.
  static double containerAlpha({required bool dark}) => dark ? 0.65 : 0.8;

  /// The strength of the lit edge.
  static double rimAlpha({required bool dark}) => dark ? 0.8 : 0.25;

  /// The width of the lit edge.
  static const double edgeLineWidth = 2.5;

  /// The caustic light under the bar.
  static const Color causticColor = Color(0x42FFFFFF);

  /// The lift every view casts, as measured beside the caustic light.
  static const SoftParticleShadow barShadow = SoftParticleShadow();

  /// A round view grows from half its size.
  static const double minScale = 0.5;

  /// A round view fades only once more than this share of it is under the
  /// capsule.
  static const double overlapFadeStart = 0.5;

  static final SpringDescription alphaSpring = softSpring(
    damping: 1,
    response: 0.35,
  );
  static final SpringDescription scaleSpring = softSpring(
    damping: 0.65,
    response: 0.55,
  );
  static final SpringDescription translationSpring = softSpring(
    damping: 0.65,
    response: 0.55,
  );

  /// The round views' springs where the views do not melt together.
  static final SpringDescription lowEndAlphaSpring = softSpring(
    damping: 1,
    response: 0.2,
  );
  static final SpringDescription lowEndScaleSpring = softSpring(
    damping: 0.7,
    response: 0.5,
  );
  static final SpringDescription lowEndTranslationSpring = softSpring(
    damping: 0.7,
    response: 0.5,
  );

  /// The capsule moving and resizing when an [SoftFloatingNavigationBar.
  /// expansion] comes and goes.
  static final SpringDescription moveSpring = softSpring(
    damping: 0.65,
    response: 0.55,
  );
  static final SpringDescription lowEndMoveSpring = softSpring(
    damping: 0.7,
    response: 0.5,
  );

  /// The capsule shrinks to this as it hides.
  static const double hiddenScale = 0.8;

  /// The blur the capsule dissolves into as it hides, as a platform blur
  /// radius in physical pixels.
  static const double hiddenBlurPx = 30;

  static final SpringDescription showAlphaSpring = softSpring(
    damping: 1,
    response: 0.2,
  );
  static final SpringDescription showScaleSpring = softSpring(
    damping: 0.65,
    response: 0.35,
  );
  static final SpringDescription showBlurSpring = softSpring(
    damping: 1,
    response: 0.3,
  );
  static final SpringDescription lowEndShowAlphaSpring = softSpring(
    damping: 1,
    response: 0.25,
  );
  static final SpringDescription lowEndShowScaleSpring = softSpring(
    damping: 0.7,
    response: 0.45,
  );

  /// The system inset the bar keeps clear of: the bottom view padding, or
  /// where there is none, the system gesture inset.
  static double bottomInsetOf(BuildContext context) {
    final double padding = MediaQuery.viewPaddingOf(context).bottom;
    if (padding > 0) return padding;
    return MediaQuery.systemGestureInsetsOf(context).bottom;
  }

  /// What the bar adds below its [minHeight] for a system [inset]: the
  /// capsule sits [menuToScreenNaviDistance] above the inset, and 24 above
  /// the screen's edge where there is none.
  static double navPad(double inset) => inset <= 0
      ? menuToScreenNaviDistance
      : math.max(
          0,
          inset - ((minHeight - barHeight) / 2 - menuToScreenNaviDistance),
        );

  /// The height a page leaves free at its bottom for the bar.
  static double extent(BuildContext context) =>
      minHeight + navPad(bottomInsetOf(context));
}

/// One destination of a [SoftFloatingNavigationBar].
@immutable
class SoftFloatingNavigationItem {
  const SoftFloatingNavigationItem({
    required this.icon,
    required this.label,
    this.selectedIcon,
    this.enabled = true,
    this.largeIcon = false,
    this.badge,
    this.onLongPress,
    this.semanticLabel,
  });

  /// What a screen reader announces; [label] by default. Put an unread count
  /// here — the badge itself is not read out.
  final String? semanticLabel;

  /// Usually an [Icon]; it is sized and tinted by the bar.
  final Widget icon;
  final Widget? selectedIcon;
  final String label;

  /// A disabled item cannot be selected, and hides its badge.
  final bool enabled;

  /// A 40 icon that rises 14 out of the top of the cell, its label below it.
  final bool largeIcon;

  /// A red badge on the icon: 0 for a dot, more for a count, null for none.
  final int? badge;

  /// Opens an overflow menu, typically. A long press never selects.
  final VoidCallback? onLongPress;
}

/// A round view beside the capsule of a [SoftFloatingNavigationBar].
@immutable
class SoftFloatingAccessory {
  const SoftFloatingAccessory({
    required this.icon,
    this.onTap,
    this.visible = true,
    this.semanticLabel,
  });

  /// Usually an [Icon].
  final Widget icon;
  final VoidCallback? onTap;

  /// Whether the view is out. A hidden view tucks into the capsule's end;
  /// beside the capsule it keeps its place, as an expansion it hands its
  /// room back to the capsule.
  final bool visible;
  final String? semanticLabel;
}

/// The floating bottom navigation bar: a frosted 56-high capsule of items,
/// 8 above the system inset, and optionally a round view on either side or
/// one expansion view at its end.
///
/// The selected item differs only in colour — there is no pill. The whole
/// capsule answers a press: it sinks, follows the finger and stretches with
/// it, and a light follows the finger across it. Sliding the finger along
/// the capsule selects the item under it on the spot, and lifting it there
/// goes to it.
///
/// The capsule is as wide as its items at 70 each plus 12 at either end and
/// 8 between them, and is squeezed — items and all — into what the bar
/// leaves when they do not fit; from 600 wide it fills the bar. Round views
/// keep 56 + 12 at their side. A round view coming out grows from inside
/// the capsule's end and, while it passes the capsule's edge, melts into it
/// as one frosted body; that body samples [backdrop] (a [LayerBackdrop] of
/// the page). Without one, without blur, or on a device whose glass tier
/// runs no fragment programs, round views fade and grow in place instead.
class SoftFloatingNavigationBar extends StatefulWidget {
  const SoftFloatingNavigationBar({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.onSelected,
    this.start,
    this.end,
    this.expansion,
    this.backdrop,
    this.color,
    this.selectedColor,
    this.unselectedColor,
    this.scrimColor,
    this.quality,
    this.includeBottomInset = true,
    this.blur = true,
    this.stroke = true,
    this.caustic = true,
    this.visible = true,
    this.dispatchWhenAlreadySelected = false,
  }) : assert(
         expansion == null || (start == null && end == null),
         'An expansion view replaces the round views at either side.',
       ),
       assert(
         items.length == 0
             ? selectedIndex == 0
             : selectedIndex >= 0 && selectedIndex < items.length,
       );

  final List<SoftFloatingNavigationItem> items;
  final int selectedIndex;

  /// Called with the item a tap or a slide lands on. A slide that comes
  /// back to the selected item reports it again.
  final ValueChanged<int> onSelected;

  /// The round view at the start edge.
  final SoftFloatingAccessory? start;

  /// The round view at the end edge.
  final SoftFloatingAccessory? end;

  /// One round view at the capsule's end — a floating action, say. While it
  /// is out on a compact screen, the capsule moves to the start edge to make
  /// room for it.
  final SoftFloatingAccessory? expansion;

  /// The captured page the frosted body blurs.
  final Backdrop? backdrop;

  /// The bar colour; the theme's `bar` by default.
  final Color? color;

  /// The selected item's colour; the theme's `onSurface` by default.
  final Color? selectedColor;

  /// The other items' colour; the theme's `labelPrimaryVariant` by default.
  final Color? unselectedColor;

  /// A fade from transparent to 80 % of this colour over the bar's whole
  /// box, behind the capsule — the page colour, typically, so content
  /// scrolling under the bar recedes. None when null.
  final Color? scrimColor;

  /// Pins the glass tier of the merged body.
  final GlassQuality? quality;

  /// Whether the bar keeps clear of the system's bottom inset.
  final bool includeBottomInset;

  /// Whether the capsule is frosted. False paints it opaque in [color] —
  /// what the reference falls back to where there is nothing to blur, and
  /// what an app with its glass switched off wants.
  final bool blur;

  /// Whether the capsule's edge is lit. Turn it off for high contrast, not
  /// with the blur: the opaque capsule keeps its edge.
  final bool stroke;

  /// Whether a faint light falls below the capsule.
  final bool caustic;

  /// Whether the capsule is shown. It fades, shrinks and blurs away, and
  /// back.
  final bool visible;

  /// Whether a tap on the selected item reports it again (to scroll back to
  /// the top, say).
  final bool dispatchWhenAlreadySelected;

  @override
  State<SoftFloatingNavigationBar> createState() =>
      _SoftFloatingNavigationBarState();
}

class _Expansion {
  _Expansion(TickerProvider vsync, bool visible)
    : alpha = SoftSpring(vsync: vsync, value: visible ? 1 : 0),
      scale = SoftSpring(
        vsync: vsync,
        value: visible ? 1 : SoftFloatingNavigationBarDefaults.minScale,
      ),
      tuck = SoftSpring(vsync: vsync, value: visible ? 0 : 1),
      shown = visible;

  final SoftSpring alpha;
  final SoftSpring scale;

  /// 0 at rest beside the capsule, 1 tucked into its end.
  final SoftSpring tuck;

  /// The target: out or tucked away.
  bool shown;

  void show(bool visible, {required bool lowEnd}) {
    shown = visible;
    alpha.animateTo(
      visible ? 1 : 0,
      lowEnd
          ? SoftFloatingNavigationBarDefaults.lowEndAlphaSpring
          : SoftFloatingNavigationBarDefaults.alphaSpring,
    );
    scale.animateTo(
      visible ? 1 : SoftFloatingNavigationBarDefaults.minScale,
      lowEnd
          ? SoftFloatingNavigationBarDefaults.lowEndScaleSpring
          : SoftFloatingNavigationBarDefaults.scaleSpring,
    );
    tuck.animateTo(
      visible ? 0 : 1,
      lowEnd
          ? SoftFloatingNavigationBarDefaults.lowEndTranslationSpring
          : SoftFloatingNavigationBarDefaults.translationSpring,
    );
  }

  void snap(bool visible) {
    shown = visible;
    alpha.snapTo(visible ? 1 : 0);
    scale.snapTo(visible ? 1 : SoftFloatingNavigationBarDefaults.minScale);
    tuck.snapTo(visible ? 0 : 1);
  }

  /// Whether it is out and done coming out: only then does it take a press.
  bool get settled => shown && !tuck.isAnimating && tuck.value == 0;

  /// Whether it takes part in the bar at all: out, or still on its way in.
  bool get live =>
      shown || tuck.isAnimating || scale.isAnimating || alpha.isAnimating;

  List<Listenable> get listenables => <Listenable>[alpha, scale, tuck];

  void dispose() {
    alpha.dispose();
    scale.dispose();
    tuck.dispose();
  }
}

/// A round view's place for one frame.
class _Side {
  const _Side({
    required this.accessory,
    required this.expansion,
    required this.motion,
    required this.rest,
    required this.centre,
    required this.scale,
    required this.alpha,
  });

  final SoftFloatingAccessory accessory;
  final _Expansion expansion;
  final SoftTouchMotionState motion;

  /// Where it rests when out; its box is laid out here.
  final Offset rest;
  final Offset centre;
  final double scale;
  final double alpha;
}

class _SoftFloatingNavigationBarState extends State<SoftFloatingNavigationBar>
    with TickerProviderStateMixin {
  final SoftTouchMotionState _menu = SoftTouchMotionState();
  final SoftTouchMotionState _startMotion = SoftTouchMotionState();
  final SoftTouchMotionState _endMotion = SoftTouchMotionState();
  final SoftTouchMotionState _expansionMotion = SoftTouchMotionState();
  late final _Expansion _startExpansion = _Expansion(
    this,
    widget.start?.visible ?? false,
  );
  late final _Expansion _endExpansion = _Expansion(
    this,
    widget.end?.visible ?? false,
  );
  late final _Expansion _expansionExpansion = _Expansion(
    this,
    widget.expansion?.visible ?? false,
  );
  late final SoftSpring _shownAlpha = SoftSpring(
    vsync: this,
    value: widget.visible ? 1 : 0,
  );
  late final SoftSpring _shownScale = SoftSpring(
    vsync: this,
    value: widget.visible ? 1 : SoftFloatingNavigationBarDefaults.hiddenScale,
  );
  late final SoftSpring _shownBlur = SoftSpring(
    vsync: this,
    value: widget.visible ? 0 : 1,
  );

  /// The capsule's left edge and width, which spring when an expansion
  /// comes or goes.
  late final SoftSpring _capsuleLeft = SoftSpring(vsync: this);
  late final SoftSpring _capsuleWidth = SoftSpring(vsync: this);
  Rect? _capsuleTarget;
  Size? _capsuleScreen;

  /// Where the expansion rested when it was last out, from the start edge.
  /// Going back in it springs from there into the capsule's end; without it
  /// a hidden expansion has no place beside the capsule and would jump into
  /// the capsule on the first frame.
  double? _expansionRest;

  late final Listenable _motion = Listenable.merge(<Listenable>[
    _menu.transformChanges,
    _startMotion.transformChanges,
    _endMotion.transformChanges,
    _expansionMotion.transformChanges,
    ..._startExpansion.listenables,
    ..._endExpansion.listenables,
    ..._expansionExpansion.listenables,
    _shownAlpha,
    _shownScale,
    _shownBlur,
    _capsuleLeft,
    _capsuleWidth,
  ]);

  /// Whether the round views melt into the capsule; decided each build.
  bool _melts = false;

  /// Whether the merged body samples [SoftFloatingNavigationBar.backdrop];
  /// decided each build.
  bool _captured = false;

  // Touch on the capsule, resolved the way the reference's own bar does it.
  // Pressing an item and lifting on it clicks it, however far the finger
  // wandered inside it; lifting on another item clicks that one. Sliding
  // onto another item selects it on the spot — its icon and colour change
  // under the finger — and the selection is delivered when the finger
  // lifts or the gesture is cancelled, wherever that happens. Only the
  // first finger counts.

  /// The pointer the gesture follows.
  int? _touchPointer;

  /// The item under the finger when it went down.
  int? _downIndex;

  /// Whether the finger has strayed out of [_downIndex]'s cell.
  bool _leftDown = false;

  /// The item shown as selected while a slide is under way.
  int? _slide;

  /// The item a slide has moved the selection to, delivered on lift.
  int? _pending;

  /// Set when a long press fired: the lift that ends it clicks nothing.
  bool _longPressed = false;

  // The capsule's item geometry, in its own frame, from the last build.
  double _itemWidth = 0;
  double _rowWidth = 0;
  bool _rtl = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _rtl = Directionality.of(context) == TextDirection.rtl;
  }

  Rect _cellRect(int index) {
    const double h = SoftFloatingNavigationBarDefaults.barHeight;
    final double ih = math.min(SoftFloatingNavigationBarDefaults.itemHeight, h);
    final double left =
        SoftFloatingNavigationBarDefaults.itemInnerPadding +
        index * (_itemWidth + SoftFloatingNavigationBarDefaults.itemSpacing);
    final double x = _rtl ? _rowWidth - left - _itemWidth : left;
    return Rect.fromLTWH(x, (h - ih) / 2, _itemWidth, ih);
  }

  bool _inCell(int index, Offset local, [double slop = 0]) {
    final Rect r = _cellRect(index).inflate(slop);
    return local.dx >= r.left &&
        local.dx <= r.right &&
        local.dy >= r.top &&
        local.dy <= r.bottom;
  }

  int? _itemAt(Offset local) {
    for (int i = 0; i < widget.items.length; i++) {
      if (_inCell(i, local)) return i;
    }
    return null;
  }

  void _clearTouch() {
    _touchPointer = null;
    _downIndex = null;
    _leftDown = false;
    _pending = null;
    _longPressed = false;
  }

  void _down(PointerDownEvent e) {
    if (_touchPointer != null) return;
    _clearTouch();
    _touchPointer = e.pointer;
    _downIndex = _itemAt(e.localPosition);
  }

  void _move(PointerMoveEvent e) {
    if (e.pointer != _touchPointer || _longPressed) return;
    final int? down = _downIndex;
    if (down != null &&
        !_inCell(
          down,
          e.localPosition,
          SoftFloatingNavigationBarDefaults.clickSlop,
        )) {
      _leftDown = true;
    }
    final int? index = _itemAt(e.localPosition);
    if (index == null || !widget.items[index].enabled) return;
    if (index == (_slide ?? widget.selectedIndex)) return;
    setState(() => _slide = index);
    _pending = index;
  }

  void _up(PointerUpEvent e) {
    if (e.pointer != _touchPointer) return;
    _resolve(_itemAt(e.localPosition), cancelled: false);
  }

  void _cancel(PointerCancelEvent e) {
    if (e.pointer != _touchPointer) return;
    _resolve(null, cancelled: true);
  }

  void _resolve(int? under, {required bool cancelled}) {
    final int? pending = _pending;
    final int? down = _downIndex;
    final bool leftDown = _leftDown;
    final bool longPressed = _longPressed;
    _clearTouch();
    if (_slide != null) setState(() => _slide = null);
    if (longPressed) return;
    final int count = widget.items.length;
    if (pending != null) {
      // A slide is delivered wherever it ends — on a lift outside any item,
      // on a cancel, and back on the item it started from.
      if (pending < count && widget.items[pending].enabled) {
        widget.onSelected(pending);
      }
      return;
    }
    if (cancelled) return;
    final int? target = under == down ? (leftDown ? null : under) : under;
    if (target == null || target >= count || !widget.items[target].enabled) {
      return;
    }
    if (target == widget.selectedIndex && !widget.dispatchWhenAlreadySelected) {
      return;
    }
    widget.onSelected(target);
  }

  void _longPress(int index) {
    if (_touchPointer == null) return;
    _longPressed = true;
    _pending = null;
    if (_slide != null) setState(() => _slide = null);
    widget.items[index].onLongPress?.call();
  }

  void _semanticTap(int index) {
    if (index == widget.selectedIndex && !widget.dispatchWhenAlreadySelected) {
      return;
    }
    widget.onSelected(index);
  }

  @override
  void didUpdateWidget(SoftFloatingNavigationBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedIndex != widget.selectedIndex) _slide = null;
    if (!identical(oldWidget.items, widget.items) &&
        oldWidget.items.length != widget.items.length) {
      _slide = null;
      _clearTouch();
    }
    final bool lowEnd = !_melts;
    final bool reduce = softReduceMotion(context);
    void sync(
      SoftFloatingAccessory? now,
      SoftFloatingAccessory? before,
      _Expansion expansion,
    ) {
      final bool visible = now?.visible ?? false;
      if (visible == (before?.visible ?? false)) return;
      if (before == null || now == null || reduce) {
        expansion.snap(visible);
      } else {
        expansion.show(visible, lowEnd: lowEnd);
      }
    }

    sync(widget.start, oldWidget.start, _startExpansion);
    sync(widget.end, oldWidget.end, _endExpansion);
    sync(widget.expansion, oldWidget.expansion, _expansionExpansion);
    if (widget.visible != oldWidget.visible) _show(widget.visible, lowEnd);
  }

  void _show(bool visible, bool lowEnd) {
    _shownAlpha.animateTo(
      visible ? 1 : 0,
      lowEnd
          ? SoftFloatingNavigationBarDefaults.lowEndShowAlphaSpring
          : SoftFloatingNavigationBarDefaults.showAlphaSpring,
      threshold: 1e-4,
    );
    _shownScale.animateTo(
      visible ? 1 : SoftFloatingNavigationBarDefaults.hiddenScale,
      lowEnd
          ? SoftFloatingNavigationBarDefaults.lowEndShowScaleSpring
          : SoftFloatingNavigationBarDefaults.showScaleSpring,
      threshold: 1e-4,
    );
    if (widget.blur) {
      _shownBlur.animateTo(
        visible ? 0 : 1,
        SoftFloatingNavigationBarDefaults.showBlurSpring,
        threshold: 1e-3,
      );
    } else {
      _shownBlur.snapTo(0);
    }
    if (!visible) {
      _slide = null;
      _clearTouch();
    }
  }

  @override
  void dispose() {
    _menu.dispose();
    _startMotion.dispose();
    _endMotion.dispose();
    _expansionMotion.dispose();
    _startExpansion.dispose();
    _endExpansion.dispose();
    _expansionExpansion.dispose();
    _shownAlpha.dispose();
    _shownScale.dispose();
    _shownBlur.dispose();
    _capsuleLeft.dispose();
    _capsuleWidth.dispose();
    super.dispose();
  }

  /// Whether the round views melt into the capsule. They do wherever
  /// motion is not reduced: with a captured [SoftFloatingNavigationBar.
  /// backdrop] the merged body samples it, and without one it is frosted by
  /// the compositor along a traced outline.
  bool _meltsHere(BuildContext context) => !softReduceMotion(context);

  /// Whether the merged body samples the captured backdrop.
  bool _capturedHere(BuildContext context) {
    if (!widget.blur || widget.backdrop == null) return false;
    final GlassDeviceTier tier = GlassDeviceTier.instance;
    final GlassQuality? pinned = widget.quality;
    final GlassQuality resolved = pinned == null
        ? tier.quality
        : pinned.atMost(tier.ceiling);
    return resolved.hasShaders && SoftPrograms.instance.metaBall != null;
  }

  @override
  Widget build(BuildContext context) {
    final double inset = widget.includeBottomInset
        ? SoftFloatingNavigationBarDefaults.navPad(
            SoftFloatingNavigationBarDefaults.bottomInsetOf(context),
          )
        : 0;
    const double above =
        (SoftFloatingNavigationBarDefaults.minHeight -
            SoftFloatingNavigationBarDefaults.barHeight) /
        2;
    final bool large =
        MediaQuery.sizeOf(context).width >=
        SoftFloatingNavigationBarDefaults.largeScreenWidth;
    final Color? scrim = widget.scrimColor;
    return ListenableBuilder(
      listenable: Listenable.merge(<Listenable>[
        SoftPrograms.instance,
        GlassDeviceTier.instance,
      ]),
      builder: (BuildContext context, _) {
        _melts = _meltsHere(context);
        _captured = _capturedHere(context);
        return LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final double width = constraints.maxWidth;
            final double padding = large
                ? 0
                : SoftFloatingNavigationBarDefaults.paddingHorizontal;
            final Widget bar = Padding(
              padding: EdgeInsets.fromLTRB(
                padding,
                above,
                padding,
                above + inset,
              ),
              child: SizedBox(
                height: SoftFloatingNavigationBarDefaults.barHeight,
                width: double.infinity,
                child: _buildBar(context, width - padding * 2, large: large),
              ),
            );
            if (scrim == null) return bar;
            // The fade takes no touches: beside the capsule, the page under
            // the bar stays reachable.
            return Stack(
              children: <Widget>[
                Positioned.fill(
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: <Color>[
                            scrim.withValues(alpha: 0),
                            scrim.withValues(alpha: scrim.a * 0.8),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                bar,
              ],
            );
          },
        );
      },
    );
  }

  /// The capsule's width and its items' width in [available].
  (double, double) _measure(double available, {required bool large}) {
    final int count = widget.items.length;
    if (count == 0) return (0, 0);
    const double inner = SoftFloatingNavigationBarDefaults.itemInnerPadding;
    const double space = SoftFloatingNavigationBarDefaults.itemSpacing;
    final double maxItem = large
        ? SoftFloatingNavigationBarDefaults.itemMaxWidthLarge
        : SoftFloatingNavigationBarDefaults.itemMaxWidth;
    final double totalMax = count * maxItem + 2 * inner + (count - 1) * space;
    if (totalMax <= available) return (totalMax, maxItem);
    final double dpr = MediaQuery.devicePixelRatioOf(context);
    // Squeezed items are whole device pixels wide, as the reference
    // measures them.
    final double item = math.max(
      0.0,
      ((available - 2 * inner - (count - 1) * space) * dpr / count)
              .floorToDouble() /
          dpr,
    );
    return (available, item);
  }

  /// [x] measured from the start edge, as a left offset in [width].
  double _fromStart(double x, double extent, double width) =>
      _rtl ? width - x - extent : x;

  /// Moves the capsule towards [target]: at once on the first layout, on a
  /// new screen size and without an expansion, with a spring otherwise.
  void _retarget(Rect target) {
    final Size screen = MediaQuery.sizeOf(context);
    final bool animate =
        _capsuleTarget != null &&
        _capsuleScreen == screen &&
        widget.expansion != null &&
        !softReduceMotion(context);
    if (target != _capsuleTarget) {
      if (animate) {
        final SpringDescription spring = _melts
            ? SoftFloatingNavigationBarDefaults.moveSpring
            : SoftFloatingNavigationBarDefaults.lowEndMoveSpring;
        // Logical pixels: settled once within a fiftieth of one.
        _capsuleLeft.animateTo(target.left, spring, threshold: 0.02);
        _capsuleWidth.animateTo(target.width, spring, threshold: 0.02);
      } else {
        _capsuleLeft.snapTo(target.left);
        _capsuleWidth.snapTo(target.width);
      }
      _capsuleTarget = target;
      _capsuleScreen = screen;
    }
  }

  Widget _buildBar(BuildContext context, double width, {required bool large}) {
    final SoftThemeData theme = SoftTheme.of(context);
    final bool dark = theme.isDark;
    const double accessory = SoftFloatingNavigationBarDefaults.accessorySize;
    const double reserve =
        accessory + SoftFloatingNavigationBarDefaults.sideSpacing;
    const double barHeight = SoftFloatingNavigationBarDefaults.barHeight;
    final SoftFloatingAccessory? start = widget.start;
    final SoftFloatingAccessory? end = widget.end;
    final SoftFloatingAccessory? expansion = widget.expansion;
    final bool expansionOut = expansion != null && expansion.visible;

    // Where the capsule and the round views rest, measured from the start
    // edge.
    final double startReserve = start != null ? reserve : 0;
    final double endReserve = end != null || expansionOut ? reserve : 0;
    final (double capsuleWidth, double itemWidth) = _measure(
      math.max(0, width - startReserve - endReserve),
      large: large,
    );
    double capsuleStart;
    double? startRest;
    double? endRest;
    if (expansion != null) {
      if (!expansionOut) {
        capsuleStart = (width - capsuleWidth) / 2;
      } else if (large) {
        capsuleStart = (width - capsuleWidth - reserve) / 2;
      } else {
        capsuleStart = 0;
      }
      endRest = expansionOut
          ? (large
                ? capsuleStart + capsuleWidth + reserve - accessory / 2
                : width - accessory / 2)
          : null;
      if (endRest != null) _expansionRest = endRest;
    } else if (large) {
      final double row = startReserve + capsuleWidth + endReserve;
      final double left = (width - row) / 2;
      capsuleStart = left + startReserve;
      if (start != null) startRest = left + accessory / 2;
      if (end != null) endRest = left + row - accessory / 2;
    } else {
      // A compact screen pins each round view to its own edge and centres
      // the capsule between them.
      capsuleStart =
          startReserve + (width - startReserve - endReserve - capsuleWidth) / 2;
      if (start != null) startRest = accessory / 2;
      if (end != null) endRest = width - accessory / 2;
    }
    _retarget(
      Rect.fromLTWH(
        _fromStart(capsuleStart, capsuleWidth, width),
        0,
        capsuleWidth,
        barHeight,
      ),
    );

    final Color barColor = widget.color ?? theme.colors.bar;
    final SoftSpotLightParams light = SoftSpotLightParams.opaqueMedium2(dark);
    final BorderRadius capsuleRadius = BorderRadius.circular(
      SoftFloatingNavigationBarDefaults.cornerRadius,
    );
    final double dpr = MediaQuery.devicePixelRatioOf(context);
    final double blurRadius = SoftFloatingNavigationBarDefaults.blurRadiusFor(
      dpr,
    );
    final List<SoftBlendLayer> layers = dark
        ? SoftFloatingNavigationBarDefaults.blendDark
        : SoftFloatingNavigationBarDefaults.blendLight;
    final double edgeAlpha = widget.stroke
        ? SoftFloatingNavigationBarDefaults.rimAlpha(dark: dark)
        : 0;

    final int shown = _slide ?? widget.selectedIndex;
    Widget buildRow() => Semantics(
      container: true,
      explicitChildNodes: true,
      role: widget.items.isEmpty ? null : SemanticsRole.tabBar,
      child: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: _down,
        onPointerMove: _move,
        onPointerUp: _up,
        onPointerCancel: _cancel,
        child: _CapsuleRow(
          itemWidth: _itemWidth,
          children: <Widget>[
            for (int i = 0; i < widget.items.length; i++)
              _ItemCell(
                item: widget.items[i],
                selected: i == shown,
                selectedColor: widget.selectedColor,
                unselectedColor: widget.unselectedColor,
                onSemanticTap: () => _semanticTap(i),
                onLongPress: widget.items[i].onLongPress == null
                    ? null
                    : () => _longPress(i),
              ),
          ],
        ),
      ),
    );

    return AnimatedBuilder(
      animation: _motion,
      builder: (BuildContext context, _) {
        final Rect capsule = Rect.fromLTWH(
          _capsuleLeft.value,
          0,
          _capsuleWidth.value,
          barHeight,
        );
        _rowWidth = capsule.width;
        // The items follow the animated width; they are only re-measured
        // when it no longer holds them.
        _itemWidth = capsule.width >= capsuleWidth - 0.01
            ? itemWidth
            : _measure(capsule.width, large: large).$2;
        final Widget row = buildRow();
        final List<_Side> sides = <_Side>[];
        void side(
          SoftFloatingAccessory? view,
          double? rest,
          _Expansion expansion,
          SoftTouchMotionState motion, {
          required bool atStart,
        }) {
          if (view == null) return;
          // A hidden view rests inside the capsule's end.
          final double tucked = atStart
              ? capsule.left + accessory / 2
              : capsule.right - accessory / 2;
          final double restX = rest == null
              ? tucked
              : _fromStart(rest - accessory / 2, accessory, width) +
                    accessory / 2;
          final double restY = capsule.center.dy;
          final bool melt = _melts;
          final double tuck = melt ? expansion.tuck.value : 0;
          double centreX = ui.lerpDouble(restX, tucked, tuck)!;
          // The ball's edge lands on whole pixels, as the reference snaps
          // its scale.
          final double box = accessory * dpr;
          double scale = (box * expansion.scale.value).roundToDouble() / box;
          final Rect menu = capsule.shift(_menu.translation);
          double ratio = _overlapRatio(
            Rect.fromCenter(
              center: Offset(centreX, restY),
              width: accessory * scale,
              height: accessory * scale,
            ),
            menu,
          );
          if (melt &&
              !expansion.shown &&
              expansion.tuck.isAnimating &&
              ratio >= 1) {
            // Fully under the capsule: no bounce plays out unseen.
            expansion.snap(false);
            centreX = tucked;
            scale = SoftFloatingNavigationBarDefaults.minScale;
            ratio = 1;
          }
          final double alpha = melt
              ? _overlapAlpha(ratio)
              : expansion.alpha.value;
          if (!expansion.live && alpha <= 0) return;
          sides.add(
            _Side(
              accessory: view,
              expansion: expansion,
              motion: motion,
              rest: Offset(restX, restY),
              centre: Offset(centreX, restY),
              scale: scale,
              alpha: alpha,
            ),
          );
        }

        side(start, startRest, _startExpansion, _startMotion, atStart: !_rtl);
        side(end, endRest, _endExpansion, _endMotion, atStart: _rtl);
        side(
          expansion,
          expansionOut ? endRest : _expansionRest,
          _expansionExpansion,
          _expansionMotion,
          atStart: _rtl,
        );

        final double shownAlpha = _shownAlpha.value.clamp(0.0, 1.0);
        final double shownScale = _shownScale.value;
        final bool melting = sides.isNotEmpty;
        final Rect menuBounds = _transformed(capsule, _menu);

        // The round views and the capsule melted into one body.
        Widget body = const SizedBox.shrink();
        if (melting) {
          body = SoftMetaBallSurface(
            particles: <SoftMetaBallParticle>[
              SoftMetaBallParticle(
                center: capsule.center + _menu.translation,
                size: capsule.size,
                cornerRadius: SoftFloatingNavigationBarDefaults.cornerRadius,
                scaleX: _menu.scaleX * shownScale,
                scaleY: _menu.scaleY * shownScale,
                alpha: shownAlpha,
              ),
              for (final _Side s in sides)
                SoftMetaBallParticle(
                  center: s.centre + s.motion.translation,
                  size: Size.square(accessory * s.scale),
                  scaleX: s.motion.scaleX,
                  scaleY: s.motion.scaleY,
                  alpha: s.alpha,
                ),
            ],
            backdrop: _captured ? widget.backdrop : null,
            compositor: !_captured,
            blur: widget.blur,
            color: barColor,
            layers: layers,
            containerAlpha: SoftFloatingNavigationBarDefaults.containerAlpha(
              dark: dark,
            ),
            blurRadius: blurRadius,
            rimAlpha: edgeAlpha,
            causticColor: widget.caustic
                ? SoftFloatingNavigationBarDefaults.causticColor
                : null,
            shadow: SoftFloatingNavigationBarDefaults.barShadow,
            quality: widget.quality,
          );
        }

        // The capsule on its own: its own frosted panel and lit edge, which
        // deform with it.
        final Widget? panel = melting
            ? null
            : Stack(
                fit: StackFit.expand,
                children: <Widget>[
                  SoftGlass(
                    borderRadius: capsuleRadius,
                    blur: widget.blur,
                    color: barColor,
                    blurRadius: blurRadius,
                    containerAlpha:
                        SoftFloatingNavigationBarDefaults.containerAlpha(
                          dark: dark,
                        ),
                    layers: layers,
                    rim: const SoftGlassRim(alpha: 0),
                  ),
                  if (edgeAlpha > 0)
                    CustomPaint(
                      painter: _EdgePainter(
                        radius: SoftFloatingNavigationBarDefaults.cornerRadius,
                        alpha: edgeAlpha,
                        dpr: dpr,
                      ),
                    ),
                ],
              );

        final bool atRest =
            shownAlpha >= 1 && shownScale == 1 && _shownBlur.value <= 0;
        final double hiddenSigma = _shownBlur.value <= 0
            ? 0
            : (0.57735 *
                          SoftFloatingNavigationBarDefaults.hiddenBlurPx *
                          _shownBlur.value +
                      0.5) /
                  dpr;
        // The tree keeps its shape whether or not the capsule is animating:
        // at rest the opacity, scale and filter below add no layer.
        final Widget menu = IgnorePointer(
          ignoring: !widget.visible,
          child: Opacity(
            opacity: atRest ? 1 : shownAlpha,
            child: Transform.scale(
              scale: atRest ? 1 : shownScale,
              child: ImageFiltered(
                enabled: hiddenSigma > 0,
                imageFilter: ui.ImageFilter.blur(
                  sigmaX: hiddenSigma,
                  sigmaY: hiddenSigma,
                ),
                child: SoftTouchMotion(
                  state: _menu,
                  light: light,
                  borderRadius: capsuleRadius,
                  enabled: widget.visible,
                  background: panel,
                  child: row,
                ),
              ),
            ),
          ),
        );

        return Stack(
          clipBehavior: Clip.none,
          children: <Widget>[
            Positioned.fill(key: const ValueKey<String>('body'), child: body),
            Positioned.fromRect(
              key: const ValueKey<String>('menu'),
              rect: capsule,
              child: menu,
            ),
            // Painted over the capsule so its own blur does not take it in;
            // it is clipped to outside the capsule.
            Positioned.fill(
              key: const ValueKey<String>('lift'),
              child: IgnorePointer(
                child: melting
                    ? const SizedBox.shrink()
                    : CustomPaint(
                        painter: _LiftPainter(
                          rect: menuBounds,
                          scale: shownScale,
                          alpha: shownAlpha,
                          radius:
                              SoftFloatingNavigationBarDefaults.cornerRadius,
                          caustic: widget.caustic
                              ? SoftFloatingNavigationBarDefaults.causticColor
                              : null,
                          background: theme.colors.background,
                          dpr: dpr,
                          repaint: SoftPrograms.instance,
                        ),
                      ),
              ),
            ),
            for (final _Side s in sides)
              _accessory(
                s,
                key: ValueKey<_Expansion>(s.expansion),
                light: light,
                foreground: theme.colors.onBackground,
              ),
          ],
        );
      },
    );
  }

  Widget _accessory(
    _Side side, {
    required Key key,
    required SoftSpotLightParams light,
    required Color foreground,
  }) {
    const double size = SoftFloatingNavigationBarDefaults.accessorySize;
    final bool live = side.alpha > 0.01;
    final bool pressable = live && side.expansion.settled;
    return Positioned.fromRect(
      key: key,
      rect: Rect.fromCenter(center: side.rest, width: size, height: size),
      child: IgnorePointer(
        ignoring: !pressable,
        child: Opacity(
          opacity: side.alpha.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(side.centre.dx - side.rest.dx, 0),
            child: SoftTouchMotion(
              enabled: pressable,
              state: side.motion,
              light: light,
              borderRadius: BorderRadius.circular(size / 2),
              child: Semantics(
                button: true,
                label: side.accessory.semanticLabel,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: side.accessory.onTap,
                  child: Transform.scale(
                    scale: side.scale,
                    child: Center(
                      child: IconTheme.merge(
                        data: IconThemeData(
                          size: SoftFloatingNavigationBarDefaults.iconSize,
                          color: foreground,
                        ),
                        child: live
                            ? side.accessory.icon
                            : const SizedBox.shrink(),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// [rect] with [motion]'s transform applied about its centre.
Rect _transformed(Rect rect, SoftTouchMotionState motion) {
  return Rect.fromCenter(
    center: rect.center + motion.translation,
    width: rect.width * motion.scaleX,
    height: rect.height * motion.scaleY,
  );
}

/// How much of [accessory] lies under [menu], 0–1.
double _overlapRatio(Rect accessory, Rect menu) {
  final double area = accessory.width * accessory.height;
  if (area <= 0 || menu.isEmpty) return 0;
  final double w = math.max(
    0.0,
    math.min(accessory.right, menu.right) - math.max(accessory.left, menu.left),
  );
  final double h = math.max(
    0.0,
    math.min(accessory.bottom, menu.bottom) - math.max(accessory.top, menu.top),
  );
  return (w * h / area).clamp(0.0, 1.0);
}

/// A round view is opaque until more than half of it is under the capsule,
/// and fades out as the rest slides in.
double _overlapAlpha(double ratio) {
  const double start = SoftFloatingNavigationBarDefaults.overlapFadeStart;
  if (ratio <= start) return 1;
  return (1 - (ratio - start) / (1 - start)).clamp(0.0, 1.0);
}

/// The capsule's lit edge.
class _EdgePainter extends CustomPainter {
  _EdgePainter({required this.radius, required this.alpha, required this.dpr})
    : super(repaint: SoftPrograms.instance);

  final double radius;
  final double alpha;
  final double dpr;

  @override
  void paint(Canvas canvas, Size size) {
    paintSoftCapsuleEdge(
      canvas,
      size,
      cornerRadius: radius,
      alpha: alpha,
      devicePixelRatio: dpr,
      lineWidth: SoftFloatingNavigationBarDefaults.edgeLineWidth,
    );
  }

  @override
  bool shouldRepaint(_EdgePainter old) =>
      old.radius != radius || old.alpha != alpha || old.dpr != dpr;
}

/// The lone capsule's lift: its shadow and the caustic light below it, both
/// outside its outline.
class _LiftPainter extends CustomPainter {
  _LiftPainter({
    required this.rect,
    required this.scale,
    required this.alpha,
    required this.radius,
    required this.caustic,
    required this.background,
    required this.dpr,
    super.repaint,
  });

  final Rect rect;
  final double scale;
  final double alpha;
  final double radius;
  final Color? caustic;
  final Color background;
  final double dpr;

  @override
  void paint(Canvas canvas, Size size) {
    if (alpha <= 0) return;
    final Rect r = Rect.fromCenter(
      center: rect.center,
      width: rect.width * scale,
      height: rect.height * scale,
    );
    final RRect shape = RRect.fromRectAndRadius(
      r,
      Radius.circular(math.min(radius * scale, r.shortestSide / 2)),
    );
    canvas.save();
    canvas.clipPath(
      Path()
        ..fillType = PathFillType.evenOdd
        ..addRect(r.inflate(60))
        ..addRRect(shape),
    );
    const SoftParticleShadow shadow =
        SoftFloatingNavigationBarDefaults.barShadow;
    canvas.drawRRect(
      shape.shift(shadow.offset),
      Paint()
        ..color = shadow.color.withValues(alpha: shadow.color.a * alpha)
        ..maskFilter = MaskFilter.blur(
          BlurStyle.normal,
          shadow.blurRadius * 0.57735 + 0.5,
        ),
    );
    final Color? light = caustic;
    if (light != null) {
      paintSoftCaustic(
        canvas,
        center: r.center,
        size: r.size,
        cornerRadius: math.min(radius * scale, r.shortestSide / 2),
        profile: SoftCausticProfile.bar,
        color: light,
        background: background,
        devicePixelRatio: dpr,
        alpha: alpha,
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_LiftPainter old) =>
      old.rect != rect ||
      old.scale != scale ||
      old.alpha != alpha ||
      old.radius != radius ||
      old.caustic != caustic ||
      old.background != background ||
      old.dpr != dpr;
}

/// Lays the items out at an exact width each: 12 in from the capsule's ends,
/// 8 apart, centred vertically.
class _CapsuleRow extends MultiChildRenderObjectWidget {
  const _CapsuleRow({required this.itemWidth, required super.children});

  final double itemWidth;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderCapsuleRow(itemWidth, Directionality.of(context));

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderCapsuleRow renderObject,
  ) {
    renderObject
      ..itemWidth = itemWidth
      ..textDirection = Directionality.of(context);
  }
}

class _CapsuleParentData extends ContainerBoxParentData<RenderBox> {}

class _RenderCapsuleRow extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _CapsuleParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, _CapsuleParentData> {
  _RenderCapsuleRow(this._itemWidth, this._textDirection);

  double _itemWidth;
  set itemWidth(double v) {
    if (v == _itemWidth) return;
    _itemWidth = v;
    markNeedsLayout();
  }

  TextDirection _textDirection;
  set textDirection(TextDirection v) {
    if (v == _textDirection) return;
    _textDirection = v;
    markNeedsLayout();
  }

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _CapsuleParentData) {
      child.parentData = _CapsuleParentData();
    }
  }

  @override
  void performLayout() {
    size = constraints.biggest;
    const double inner = SoftFloatingNavigationBarDefaults.itemInnerPadding;
    const double space = SoftFloatingNavigationBarDefaults.itemSpacing;
    final bool rtl = _textDirection == TextDirection.rtl;
    int index = 0;
    RenderBox? child = firstChild;
    while (child != null) {
      child.layout(
        BoxConstraints.tightFor(
          width: _itemWidth,
          height: math.min(
            SoftFloatingNavigationBarDefaults.itemHeight,
            size.height,
          ),
        ),
        parentUsesSize: true,
      );
      final double left = inner + index * (_itemWidth + space);
      (child.parentData! as _CapsuleParentData).offset = Offset(
        rtl ? size.width - left - _itemWidth : left,
        (size.height - child.size.height) / 2,
      );
      index++;
      child = childAfter(child);
    }
  }

  @override
  void paint(PaintingContext context, Offset offset) =>
      defaultPaint(context, offset);

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      defaultHitTestChildren(result, position: position);
}

/// One item: icon and label pinned to the top of a 48-high cell. Taps are
/// resolved by the bar, not here.
class _ItemCell extends StatelessWidget {
  const _ItemCell({
    required this.item,
    required this.selected,
    required this.onSemanticTap,
    required this.onLongPress,
    this.selectedColor,
    this.unselectedColor,
  });

  final SoftFloatingNavigationItem item;
  final bool selected;
  final VoidCallback onSemanticTap;
  final VoidCallback? onLongPress;
  final Color? selectedColor;
  final Color? unselectedColor;

  @override
  Widget build(BuildContext context) {
    final SoftThemeData theme = SoftTheme.of(context);
    final Color tint = !item.enabled
        ? theme.colors.onSurfaceVariantActions
        : selected
        ? selectedColor ?? theme.colors.onSurface
        : unselectedColor ?? theme.colors.labelPrimaryVariant;
    final bool large = item.largeIcon;
    final double iconSize = large
        ? SoftFloatingNavigationBarDefaults.largeIconSize
        : SoftFloatingNavigationBarDefaults.iconSize;
    Widget icon = IconTheme.merge(
      data: IconThemeData(size: iconSize, color: tint),
      child: SizedBox.square(
        dimension: iconSize,
        child: Center(
          child: selected ? (item.selectedIcon ?? item.icon) : item.icon,
        ),
      ),
    );
    final int? badge = item.enabled ? item.badge : null;
    if (badge != null) {
      final double right;
      final double top;
      if (large) {
        right = 0;
        top = SoftFloatingNavigationBarDefaults.largeIconOverflow;
      } else {
        right = badge <= 0
            ? 0
            : badge < 10
            ? SoftFloatingNavigationBarDefaults.redDotRightOverflow1Digit
            : badge < 100
            ? SoftFloatingNavigationBarDefaults.redDotRightOverflow2Digit
            : SoftFloatingNavigationBarDefaults.redDotRightOverflow3Digit;
        top = badge > 0
            ? -SoftFloatingNavigationBarDefaults.redDotTopOverflow
            : 0;
      }
      icon = Stack(
        clipBehavior: Clip.none,
        children: <Widget>[
          icon,
          PositionedDirectional(
            top: 0,
            end: 0,
            child: Transform.translate(
              offset: Offset(
                Directionality.of(context) == TextDirection.rtl
                    ? -right
                    : right,
                top,
              ),
              child: SoftBadge(
                count: badge,
                animate: false,
                dotDiameter: SoftFloatingNavigationBarDefaults.redDotDiameter,
              ),
            ),
          ),
        ],
      );
    }
    final Widget label = Text(
      item.label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      // A label that fits is centred by the column; one that does not is
      // cut at its end, from the start.
      textAlign: TextAlign.start,
      // The label is sized in pixels: a larger system font leaves it as it
      // is.
      textScaler: TextScaler.noScaling,
      style: TextStyle(
        fontSize: SoftFloatingNavigationBarDefaults.labelFontSize,
        fontWeight: FontWeight.w500,
        height:
            SoftFloatingNavigationBarDefaults.labelLineHeight /
            SoftFloatingNavigationBarDefaults.labelFontSize,
        color: tint,
      ),
    );
    Widget content = OverflowBox(
      alignment: Alignment.topCenter,
      minHeight: 0,
      maxHeight: double.infinity,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const SizedBox(
            height: SoftFloatingNavigationBarDefaults.iconTopMargin,
          ),
          if (large)
            // The large icon rises out of the cell with its label right
            // below it, 26 from the cell's top.
            Transform.translate(
              offset: const Offset(
                0,
                -(SoftFloatingNavigationBarDefaults.largeIconOverflow +
                    SoftFloatingNavigationBarDefaults.iconTopMargin),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[icon, label],
              ),
            )
          else ...<Widget>[
            icon,
            const SizedBox(
              height: SoftFloatingNavigationBarDefaults.iconTitleGap,
            ),
            label,
          ],
        ],
      ),
    );
    if (onLongPress != null) {
      content = GestureDetector(
        behavior: HitTestBehavior.opaque,
        onLongPress: onLongPress,
        child: content,
      );
    }
    return Semantics(
      container: true,
      role: SemanticsRole.tab,
      selected: selected,
      button: true,
      inMutuallyExclusiveGroup: true,
      enabled: item.enabled,
      label: item.semanticLabel ?? item.label,
      // The bar resolves taps itself, so the actions are given here.
      onTap: item.enabled ? onSemanticTap : null,
      onLongPress: item.enabled ? item.onLongPress : null,
      excludeSemantics: true,
      child: content,
    );
  }
}
