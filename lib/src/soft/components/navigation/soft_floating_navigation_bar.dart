import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import '../../../backdrop.dart';
import '../../../quality/glass_quality.dart';
import '../../foundation/soft_glass.dart';
import '../../foundation/soft_meta_ball.dart';
import '../../foundation/soft_motion.dart';
import '../../foundation/soft_spot_light.dart';
import '../../foundation/soft_theme.dart';
import '../../foundation/soft_touch_motion.dart';
import '../badge/soft_badge.dart';

/// The floating navigation bar's metrics, colours and springs.
abstract final class SoftFloatingNavigationBarDefaults {
  /// The capsule's height.
  static const double barHeight = 56;

  /// The bar's minimum height, above the system inset.
  static const double minHeight = 88;

  /// The outside padding on a compact screen; none from 600 wide.
  static const double paddingHorizontal = 16;

  /// How far the capsule sits above the bar's bottom edge.
  static const double menuToScreenNaviDistance = 8;

  /// The round views at either side.
  static const double accessorySize = 56;

  /// The gap between the capsule and a round view.
  static const double sideSpacing = 12;

  static const double cornerRadius = 28;
  static const double itemHeight = 48;
  static const double itemMaxWidth = 70;
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

  /// The blur of the plain capsule, in physical pixels of sigma.
  static const double nativeBlurSigmaPx = 25;

  /// The plain capsule's tint over its blur: keeps the backdrop's colour and
  /// only remaps its lightness.
  static const List<SoftBlendLayer> blendLight = <SoftBlendLayer>[
    SoftBlendLayer(Color(0xB3666666), BlendMode.colorDodge),
    SoftBlendLayer(Color(0x99F5F5F5), BlendMode.luminosity),
  ];
  static const List<SoftBlendLayer> blendDark = <SoftBlendLayer>[
    SoftBlendLayer(Color(0x80666666), BlendMode.overlay),
    SoftBlendLayer(Color(0xB3262626), BlendMode.luminosity),
  ];

  /// The tint alpha of the merged body with round views.
  static double containerAlpha({required bool dark}) => dark ? 0.65 : 0.8;

  /// The rim strength of the merged body.
  static double rimAlpha({required bool dark}) => dark ? 0.8 : 0.25;

  /// The caustic light under the bar.
  static const Color causticColor = Color(0x42FFFFFF);

  /// The lift every view casts.
  static const SoftParticleShadow barShadow = SoftParticleShadow();

  /// A round view grows from half its size.
  static const double minScale = 0.5;

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

  /// The height a page leaves free at its bottom for the bar.
  static double extent(BuildContext context) =>
      minHeight + MediaQuery.viewPaddingOf(context).bottom;
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
  final bool enabled;

  /// A 40 icon that rises 14 out of the top of the cell.
  final bool largeIcon;

  /// A red badge on the icon: 0 for a dot, more for a count, null for none.
  final int? badge;

  /// Opens an overflow menu, typically.
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

  /// Whether the view is out; a hidden one still keeps its place.
  final bool visible;
  final String? semanticLabel;
}

/// The floating bottom navigation bar: a frosted 56-high capsule of items,
/// 8 above the bottom edge, and optionally a round view on either side.
///
/// The selected item differs only in colour — there is no pill. The whole
/// capsule answers a press: it sinks, follows the finger and stretches with
/// it, and a light follows the finger across it.
///
/// The capsule is as wide as its items at 70 each plus 12 at either end and
/// 8 between them, and is squeezed — items and all — into what the bar
/// leaves when they do not fit. Round views keep 56 + 12 at their side;
/// while either is configured, all the silhouettes are one frosted body, so
/// a round view pulled towards the capsule melts into it. That body samples
/// [backdrop] (a [LayerBackdrop] of the page); without one, or on a device
/// whose glass tier runs no fragment programs, the shapes are frosted
/// separately over the compositor's blur.
class SoftFloatingNavigationBar extends StatefulWidget {
  const SoftFloatingNavigationBar({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.onSelected,
    this.start,
    this.end,
    this.backdrop,
    this.color,
    this.quality,
    this.includeBottomInset = true,
    this.blur = true,
  });

  /// Whether the capsule is frosted. False paints it opaque in [color] —
  /// what the reference falls back to where there is nothing to blur, and
  /// what an app with its glass switched off (or high contrast on) wants.
  final bool blur;

  final List<SoftFloatingNavigationItem> items;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  /// The round view at the start edge.
  final SoftFloatingAccessory? start;

  /// The round view at the end edge.
  final SoftFloatingAccessory? end;

  /// The captured page the frosted body blurs.
  final Backdrop? backdrop;

  /// The bar colour; the theme's `bar` by default.
  final Color? color;

  /// Pins the glass tier of the merged body.
  final GlassQuality? quality;

  /// Whether the bar keeps clear of the system's bottom inset.
  final bool includeBottomInset;

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
      tuck = SoftSpring(vsync: vsync, value: visible ? 0 : 1);

  final SoftSpring alpha;
  final SoftSpring scale;
  final SoftSpring tuck;

  void show(bool visible) {
    alpha.animateTo(
      visible ? 1 : 0,
      SoftFloatingNavigationBarDefaults.alphaSpring,
    );
    scale.animateTo(
      visible ? 1 : SoftFloatingNavigationBarDefaults.minScale,
      SoftFloatingNavigationBarDefaults.scaleSpring,
    );
    tuck.animateTo(
      visible ? 0 : 1,
      SoftFloatingNavigationBarDefaults.translationSpring,
    );
  }

  List<Listenable> get listenables => <Listenable>[alpha, scale, tuck];

  void dispose() {
    alpha.dispose();
    scale.dispose();
    tuck.dispose();
  }
}

class _SoftFloatingNavigationBarState extends State<SoftFloatingNavigationBar>
    with TickerProviderStateMixin {
  final SoftTouchMotionState _menu = SoftTouchMotionState();
  final SoftTouchMotionState _startMotion = SoftTouchMotionState();
  final SoftTouchMotionState _endMotion = SoftTouchMotionState();
  late final _Expansion _startExpansion = _Expansion(
    this,
    widget.start?.visible ?? false,
  );
  late final _Expansion _endExpansion = _Expansion(
    this,
    widget.end?.visible ?? false,
  );
  late final Listenable _motion = Listenable.merge(<Listenable>[
    _menu,
    _startMotion,
    _endMotion,
    ..._startExpansion.listenables,
    ..._endExpansion.listenables,
  ]);

  @override
  void didUpdateWidget(SoftFloatingNavigationBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    final bool startVisible = widget.start?.visible ?? false;
    if (startVisible != (oldWidget.start?.visible ?? false)) {
      _startExpansion.show(startVisible);
    }
    final bool endVisible = widget.end?.visible ?? false;
    if (endVisible != (oldWidget.end?.visible ?? false)) {
      _endExpansion.show(endVisible);
    }
  }

  @override
  void dispose() {
    _menu.dispose();
    _startMotion.dispose();
    _endMotion.dispose();
    _startExpansion.dispose();
    _endExpansion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double bottomInset = widget.includeBottomInset
        ? MediaQuery.viewPaddingOf(context).bottom
        : 0;
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double width = constraints.maxWidth;
        final double padding = width < 600
            ? SoftFloatingNavigationBarDefaults.paddingHorizontal
            : 0;
        return Padding(
          padding: EdgeInsets.fromLTRB(
            padding,
            SoftFloatingNavigationBarDefaults.minHeight -
                SoftFloatingNavigationBarDefaults.barHeight -
                SoftFloatingNavigationBarDefaults.menuToScreenNaviDistance,
            padding,
            SoftFloatingNavigationBarDefaults.menuToScreenNaviDistance +
                bottomInset,
          ),
          child: SizedBox(
            height: SoftFloatingNavigationBarDefaults.barHeight,
            width: double.infinity,
            child: _buildBar(context, width - padding * 2),
          ),
        );
      },
    );
  }

  Widget _buildBar(BuildContext context, double width) {
    final SoftThemeData theme = SoftTheme.of(context);
    final bool dark = theme.isDark;
    const double accessory = SoftFloatingNavigationBarDefaults.accessorySize;
    const double gap = SoftFloatingNavigationBarDefaults.sideSpacing;
    final SoftFloatingAccessory? start = widget.start;
    final SoftFloatingAccessory? end = widget.end;
    final double startReserve = start != null ? accessory + gap : 0;
    final double endReserve = end != null ? accessory + gap : 0;
    final int count = widget.items.length;
    final double available = math.max(0, width - startReserve - endReserve);
    final double totalMax = count == 0
        ? 0
        : count * SoftFloatingNavigationBarDefaults.itemMaxWidth +
              2 * SoftFloatingNavigationBarDefaults.itemInnerPadding +
              (count - 1) * SoftFloatingNavigationBarDefaults.itemSpacing;
    final bool fits = totalMax <= available;
    final double capsuleWidth = fits ? totalMax : available;
    final double itemWidth = count == 0
        ? 0
        : fits
        ? SoftFloatingNavigationBarDefaults.itemMaxWidth
        : math.max(
            0.0,
            (available -
                    2 * SoftFloatingNavigationBarDefaults.itemInnerPadding -
                    (count - 1) *
                        SoftFloatingNavigationBarDefaults.itemSpacing) /
                count,
          );
    final double rowWidth = startReserve + capsuleWidth + endReserve;
    final double rowLeft = (width - rowWidth) / 2;
    final Rect capsule = Rect.fromLTWH(
      rowLeft + startReserve,
      0,
      capsuleWidth,
      SoftFloatingNavigationBarDefaults.barHeight,
    );
    final Offset startRest = Offset(
      rowLeft + accessory / 2,
      SoftFloatingNavigationBarDefaults.barHeight / 2,
    );
    final Offset endRest = Offset(
      rowLeft + rowWidth - accessory / 2,
      SoftFloatingNavigationBarDefaults.barHeight / 2,
    );
    final Color barColor = widget.color ?? theme.colors.bar;
    final SoftSpotLightParams light = SoftSpotLightParams.opaqueMedium2(dark);
    final BorderRadius capsuleRadius = BorderRadius.circular(
      SoftFloatingNavigationBarDefaults.cornerRadius,
    );

    final Widget row = _CapsuleRow(
      itemWidth: itemWidth,
      children: <Widget>[
        for (int i = 0; i < count; i++)
          _ItemCell(
            item: widget.items[i],
            selected: i == widget.selectedIndex,
            onTap: () => widget.onSelected(i),
          ),
      ],
    );

    if (start == null && end == null) {
      // The plain capsule: its own frosted panel, which deforms with it.
      final double dpr = MediaQuery.devicePixelRatioOf(context);
      final double sigma =
          SoftFloatingNavigationBarDefaults.nativeBlurSigmaPx / dpr;
      return Stack(
        clipBehavior: Clip.none,
        children: <Widget>[
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _menu,
              builder: (BuildContext context, _) => CustomPaint(
                painter: _ShadowPainter(
                  rect: _transformed(capsule, _menu),
                  radius: SoftFloatingNavigationBarDefaults.cornerRadius,
                ),
              ),
            ),
          ),
          Positioned.fromRect(
            rect: capsule,
            child: SoftTouchMotion(
              state: _menu,
              light: light,
              borderRadius: capsuleRadius,
              background: SoftGlass(
                borderRadius: capsuleRadius,
                blur: widget.blur,
                color: barColor,
                blurRadius: sigma / 0.45,
                layers: dark
                    ? SoftFloatingNavigationBarDefaults.blendDark
                    : SoftFloatingNavigationBarDefaults.blendLight,
                size: SoftGlassSize.medium,
              ),
              child: row,
            ),
          ),
        ],
      );
    }

    return AnimatedBuilder(
      animation: _motion,
      builder: (BuildContext context, _) {
        final Rect menuBounds = _transformed(capsule, _menu);
        final List<SoftMetaBallParticle> particles = <SoftMetaBallParticle>[
          SoftMetaBallParticle(
            center: capsule.center + _menu.translation,
            size: capsule.size,
            cornerRadius: SoftFloatingNavigationBarDefaults.cornerRadius,
            scaleX: _menu.scaleX,
            scaleY: _menu.scaleY,
          ),
        ];
        double startAlpha = 0;
        double endAlpha = 0;
        Offset startCentre = startRest;
        Offset endCentre = endRest;
        if (start != null) {
          final double scale = _startExpansion.scale.value;
          startCentre =
              startRest +
              Offset(_startExpansion.tuck.value * (accessory + gap), 0);
          startAlpha = _overlapAlpha(
            Rect.fromCenter(
              center: startCentre + _startMotion.translation,
              width: accessory * scale * _startMotion.scaleX,
              height: accessory * scale * _startMotion.scaleY,
            ),
            menuBounds,
            _startExpansion.alpha.value,
          );
          particles.add(
            SoftMetaBallParticle(
              center: startCentre + _startMotion.translation,
              size: Size.square(accessory * scale),
              scaleX: _startMotion.scaleX,
              scaleY: _startMotion.scaleY,
              alpha: startAlpha,
            ),
          );
        }
        if (end != null) {
          final double scale = _endExpansion.scale.value;
          endCentre =
              endRest - Offset(_endExpansion.tuck.value * (accessory + gap), 0);
          endAlpha = _overlapAlpha(
            Rect.fromCenter(
              center: endCentre + _endMotion.translation,
              width: accessory * scale * _endMotion.scaleX,
              height: accessory * scale * _endMotion.scaleY,
            ),
            menuBounds,
            _endExpansion.alpha.value,
          );
          particles.add(
            SoftMetaBallParticle(
              center: endCentre + _endMotion.translation,
              size: Size.square(accessory * scale),
              scaleX: _endMotion.scaleX,
              scaleY: _endMotion.scaleY,
              alpha: endAlpha,
            ),
          );
        }
        return Stack(
          clipBehavior: Clip.none,
          children: <Widget>[
            Positioned.fill(
              child: SoftMetaBallSurface(
                particles: particles,
                backdrop: widget.blur ? widget.backdrop : null,
                color: barColor,
                containerAlpha:
                    SoftFloatingNavigationBarDefaults.containerAlpha(
                      dark: dark,
                    ),
                rimAlpha: SoftFloatingNavigationBarDefaults.rimAlpha(
                  dark: dark,
                ),
                causticColor: SoftFloatingNavigationBarDefaults.causticColor,
                shadow: SoftFloatingNavigationBarDefaults.barShadow,
                quality: widget.quality,
              ),
            ),
            Positioned.fromRect(
              rect: capsule,
              child: SoftTouchMotion(
                state: _menu,
                light: light,
                borderRadius: capsuleRadius,
                child: row,
              ),
            ),
            if (start != null)
              _accessory(
                start,
                rest: startRest,
                centre: startCentre,
                expansion: _startExpansion,
                alpha: startAlpha,
                motion: _startMotion,
                light: light,
                foreground: theme.colors.onBackground,
              ),
            if (end != null)
              _accessory(
                end,
                rest: endRest,
                centre: endCentre,
                expansion: _endExpansion,
                alpha: endAlpha,
                motion: _endMotion,
                light: light,
                foreground: theme.colors.onBackground,
              ),
          ],
        );
      },
    );
  }

  Widget _accessory(
    SoftFloatingAccessory accessory, {
    required Offset rest,
    required Offset centre,
    required _Expansion expansion,
    required double alpha,
    required SoftTouchMotionState motion,
    required SoftSpotLightParams light,
    required Color foreground,
  }) {
    const double size = SoftFloatingNavigationBarDefaults.accessorySize;
    final double scale = expansion.scale.value;
    final bool live = alpha > 0.01;
    return Positioned.fromRect(
      rect: Rect.fromCenter(center: rest, width: size, height: size),
      child: IgnorePointer(
        ignoring: !live,
        child: Opacity(
          opacity: alpha.clamp(0.0, 1.0),
          child: Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..translateByDouble(centre.dx - rest.dx, 0, 0, 1)
              ..scaleByDouble(scale, scale, 1, 1),
            child: SoftTouchMotion(
              enabled: live,
              state: motion,
              light: light,
              borderRadius: BorderRadius.circular(size / 2),
              child: Semantics(
                button: true,
                label: accessory.semanticLabel,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: accessory.onTap,
                  child: Center(
                    child: IconTheme.merge(
                      data: IconThemeData(
                        size: SoftFloatingNavigationBarDefaults.iconSize,
                        color: foreground,
                      ),
                      child: live ? accessory.icon : const SizedBox.shrink(),
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

/// A round view fades only once more than half of it is under the capsule.
double _overlapAlpha(Rect accessory, Rect menu, double alpha) {
  final double area = accessory.width * accessory.height;
  if (area <= 0 || menu.isEmpty) return alpha;
  final double w = math.max(
    0.0,
    math.min(accessory.right, menu.right) - math.max(accessory.left, menu.left),
  );
  final double h = math.max(
    0.0,
    math.min(accessory.bottom, menu.bottom) - math.max(accessory.top, menu.top),
  );
  final double ratio = (w * h / area).clamp(0.0, 1.0);
  return alpha * (ratio <= 0.5 ? 1.0 : 2 * (1 - ratio));
}

class _ShadowPainter extends CustomPainter {
  const _ShadowPainter({required this.rect, required this.radius});

  final Rect rect;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    const SoftParticleShadow shadow =
        SoftFloatingNavigationBarDefaults.barShadow;
    final RRect shape = RRect.fromRectAndRadius(
      rect,
      Radius.circular(math.min(radius, rect.shortestSide / 2)),
    );
    canvas.save();
    canvas.clipPath(
      Path()
        ..fillType = PathFillType.evenOdd
        ..addRect(rect.inflate(40))
        ..addRRect(shape),
    );
    canvas.drawRRect(
      shape.shift(shadow.offset),
      Paint()
        ..color = shadow.color
        ..maskFilter = MaskFilter.blur(
          BlurStyle.normal,
          shadow.blurRadius * 0.57735 + 0.5,
        ),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_ShadowPainter old) =>
      old.rect != rect || old.radius != radius;
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

/// One item: icon and label pinned to the top of a 48-high cell.
class _ItemCell extends StatelessWidget {
  const _ItemCell({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final SoftFloatingNavigationItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final SoftThemeData theme = SoftTheme.of(context);
    final Color tint = !item.enabled
        ? theme.colors.onSurfaceVariantActions
        : selected
        ? theme.colors.onSurface
        : theme.colors.labelPrimaryVariant;
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
    final int? badge = item.badge;
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
                dotDiameter: SoftFloatingNavigationBarDefaults.redDotDiameter,
              ),
            ),
          ),
        ],
      );
    }
    return Semantics(
      selected: selected,
      button: true,
      enabled: item.enabled,
      label: item.semanticLabel ?? item.label,
      // The gesture below is excluded with the content, so the actions are
      // given here.
      onTap: item.enabled ? onTap : null,
      onLongPress: item.enabled ? item.onLongPress : null,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: item.enabled ? onTap : null,
        onLongPress: item.enabled ? item.onLongPress : null,
        // A large icon rises out of the cell; it is not clipped or squeezed.
        child: OverflowBox(
          alignment: Alignment.topCenter,
          minHeight: 0,
          maxHeight: double.infinity,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const SizedBox(
                height: SoftFloatingNavigationBarDefaults.iconTopMargin,
              ),
              Transform.translate(
                offset: Offset(
                  0,
                  large
                      ? -(SoftFloatingNavigationBarDefaults.largeIconOverflow +
                            SoftFloatingNavigationBarDefaults.iconTopMargin)
                      : 0,
                ),
                child: icon,
              ),
              // A large icon fills the cell on its own; its label is read
              // out, not drawn.
              if (!large) ...<Widget>[
                const SizedBox(
                  height: SoftFloatingNavigationBarDefaults.iconTitleGap,
                ),
                Text(
                  item.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  // The label is sized in pixels: a larger system font leaves
                  // it as it is.
                  textScaler: TextScaler.noScaling,
                  style: TextStyle(
                    fontSize: SoftFloatingNavigationBarDefaults.labelFontSize,
                    fontWeight: FontWeight.w500,
                    height:
                        SoftFloatingNavigationBarDefaults.labelLineHeight /
                        SoftFloatingNavigationBarDefaults.labelFontSize,
                    color: tint,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
