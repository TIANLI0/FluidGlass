import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import '../../../effects/progressive_blur.dart';
import '../../foundation/soft_colors.dart';
import '../../foundation/soft_glass.dart';
import '../../foundation/soft_motion.dart';
import '../../foundation/soft_theme.dart';

/// The top app bar defaults.
abstract final class SoftTopAppBarDefaults {
  /// The horizontal padding of the title and the large title.
  static const double titlePadding = 16;

  /// The start padding of the navigation icon.
  static const double navigationIconPadding = 16;

  /// The end padding of the actions.
  static const double actionIconPadding = 16;

  /// The toolbar row: the collapsed bar, and the small bar's centre line.
  static const double collapsedHeight = 52;

  /// The expanded bar without a subtitle; it grows when the title needs more.
  static const double expandedHeight = 110;

  /// The large title's top, measured from the top of the bar.
  static const double largeTitleTopPadding = 54;

  /// Below the large title block when expanded, easing to 0 as it collapses.
  static const double largeTitleBottomPadding = 12;

  /// Below a small bar's subtitle when the stack outgrows the toolbar row.
  static const double subtitleBottomPadding = 8;

  /// Between the title and the subtitle.
  static const double subtitleMarginTop = 3.5;

  /// Between the navigation icon and the title.
  static const double navigationIconGap = 10;

  /// Between the title and the actions.
  static const double actionIconGap = 4;

  /// Between two actions.
  static const double actionSpacing = 10;

  /// The side of a toolbar action (the back and overflow keys).
  static const double actionItemSize = 40;

  /// The centred title's side margin in the compact, medium and expanded
  /// width classes (below 600, below 840, from 840).
  static const double centerTitleMarginCompat = 16;
  static const double centerTitleMarginMedium = 24;
  static const double centerTitleMarginExpanded = 40;

  /// The expanded large title.
  static const double largeTitleTextSize = 32;

  /// The collapsed title, and the small bar's title.
  static const double collapsedTitleTextSize = 24;

  /// The collapsed title over a subtitle.
  static const double collapsedTitleWithSubtitleTextSize = 18;

  /// The easing of the title morph (position and size).
  static const Cubic collapsingTitleEasing = Cubic(0.33, 0, 0.67, 1);

  /// The collapse fraction at which the morphing title is swapped for the
  /// collapsed one.
  static const double collapsedTitleSwapFraction = 0.9999;

  /// The snap that settles a half-collapsed bar after a scroll.
  static const Duration snapDuration = Duration(milliseconds: 180);
  static const Curve snapCurve = SoftDecelerateCurve();

  /// The bottom hairline.
  static const double dividerThickness = 0.33;

  /// The hairline's side margin while the bar is expanded or at rest; it
  /// narrows to 0 as the bar collapses or the content scrolls.
  static const double dividerExpandedMarginHorizontal = 24;

  /// The small bar's hairline fades in over this much scroll…
  static const double dividerAlphaChangeOffset = 10;

  /// …then its margin narrows, starting after this much…
  static const double dividerWidthStartCountOffset = 10;

  /// …over this much more.
  static const double dividerWidthChangeOffset = 25;

  /// The uniform glass: blur radius in physical pixels.
  static const double blurRadiusPx = 50;

  /// The uniform glass: the surface colour's alpha over the blur, light and
  /// dark.
  static const double backgroundAlpha = 0.8;
  static const double backgroundAlphaDark = 0.6;

  /// The gradient glass: the blur radius at its top edge, in physical
  /// pixels; it fades to sharp at the bottom.
  static const double gradientBlurRadiusPx = 30;

  /// How far the gradient glass reaches past the bar's bottom edge.
  static const double materialExtraHeight = 24;

  /// The gradient glass fades in over this much content scroll.
  static const double scrollAlphaThreshold = 30;

  /// The gradient glass base colour of the dark theme.
  static const Color darkMaterialColor = Color(0xFF303030);

  /// The gradient glass alpha ramp of the light theme, top to bottom.
  static const List<double> gradientStops = <double>[0, 0.6, 1];
  static const List<double> gradientAlphas = <double>[1, 0.7, 0];

  /// The dark theme's ramp: this alpha at the top, 0 at the bottom.
  static const double gradientAlphaDark = 0.4;

  /// The centred title margin for a window [width].
  static double centerTitleMargin(double width) {
    if (width <= 0) return 4;
    if (width >= 840) return centerTitleMarginExpanded;
    if (width >= 600) return centerTitleMarginMedium;
    return centerTitleMarginCompat;
  }

  /// The gradient glass alpha after [scrolled] of content scroll:
  /// `min(1, scrolled / 30)`, never below [minAlpha].
  static double scrollAlpha(double scrolled, {double minAlpha = 0}) {
    final double floor = minAlpha.clamp(0.0, 1.0);
    final double t = (scrolled.abs() / scrollAlphaThreshold).clamp(0.0, 1.0);
    return floor + (1 - floor) * t;
  }
}

/// A top app bar: a navigation icon, a single-line title (with an optional
/// subtitle under it) and actions, on a 52-high toolbar row under the status
/// bar.
///
/// The title starts 10 after the navigation icon, or [titlePadding] from the
/// edge without one, and stops 4 before the actions; with [centerTitle] it is
/// centred between the two icon slots, with the responsive 16 / 24 / 40 side
/// margin in place of the paddings.
///
/// With [scrollController], a hairline fades in at the bottom edge over the
/// first 10 of scroll, then widens from a 24 margin to the full width over
/// the next 25.
///
/// The surface is [color] (the theme's `surface`). With [blur] the content
/// behind is blurred and [color] is laid over it at 80 % (60 % on a dark
/// colour). With [gradientGlass] the bar is transparent and a material sits
/// behind it instead, reaching 24 past its bottom edge: an alpha ramp of the
/// surface colour over a blur that fades from the top down, both faded in
/// over the first 30 of [scrollController]'s scroll (always on without
/// one). The hairline is suppressed under the gradient glass.
class SoftTopAppBar extends StatelessWidget {
  const SoftTopAppBar({
    super.key,
    required this.title,
    this.subtitle,
    this.navigationIcon,
    this.actions = const <Widget>[],
    this.color,
    this.titleColor,
    this.subtitleColor,
    this.dividerColor,
    this.materialColor,
    this.scrollController,
    this.showDivider = true,
    this.centerTitle = false,
    this.blur = false,
    this.gradientGlass = false,
    this.windowInsetsPadding = true,
    this.titlePadding = SoftTopAppBarDefaults.titlePadding,
    this.navigationIconPadding = SoftTopAppBarDefaults.navigationIconPadding,
    this.actionIconPadding = SoftTopAppBarDefaults.actionIconPadding,
  });

  final String title;
  final String? subtitle;

  /// Laid out at the start, [navigationIconPadding] from the edge — usually
  /// a [SoftTopAppBarIconButton] with a [SoftBackIcon].
  final Widget? navigationIcon;

  /// Laid out at the end, 10 apart.
  final List<Widget> actions;

  /// The surface; the theme's `surface` by default.
  final Color? color;

  /// The theme's `onSurface` by default.
  final Color? titleColor;

  /// The theme's `onSurfaceVariantSummary` by default.
  final Color? subtitleColor;

  /// The theme's `dividerLine` by default.
  final Color? dividerColor;

  /// The gradient glass base colour: the theme's `surface`, or
  /// [SoftTopAppBarDefaults.darkMaterialColor] in the dark theme.
  final Color? materialColor;

  /// The content scrolling under the bar; drives the hairline and the
  /// gradient glass.
  final ScrollController? scrollController;
  final bool showDivider;
  final bool centerTitle;

  /// Blurs the content behind the bar.
  final bool blur;

  /// The gradient glass material in place of the surface.
  final bool gradientGlass;

  /// Keeps clear of horizontal system insets (cut-outs, side navigation).
  /// The top inset is always applied.
  final bool windowInsetsPadding;
  final double titlePadding;
  final double navigationIconPadding;
  final double actionIconPadding;

  @override
  Widget build(BuildContext context) {
    final SoftThemeData theme = SoftTheme.of(context);
    final SoftColors c = theme.colors;
    final EdgeInsets insets = MediaQuery.paddingOf(context);
    final double? margin = centerTitle
        ? SoftTopAppBarDefaults.centerTitleMargin(
            MediaQuery.sizeOf(context).width,
          )
        : null;
    final double navPadding = margin ?? navigationIconPadding;
    final double actionPadding = margin ?? actionIconPadding;
    final String? sub = subtitle;
    final List<Widget> children = <Widget>[
      if (navigationIcon != null)
        _BarChild(
          slot: _BarSlot.navigation,
          child: Padding(
            padding: EdgeInsetsDirectional.only(start: navPadding),
            child: navigationIcon,
          ),
        ),
      _BarChild(
        slot: _BarSlot.title,
        child: Text(
          title,
          maxLines: 1,
          softWrap: false,
          overflow: TextOverflow.ellipsis,
          style: theme.textStyles.title4.copyWith(
            fontSize: SoftTopAppBarDefaults.collapsedTitleWithSubtitleTextSize,
            fontWeight: FontWeight.w500,
            color: titleColor ?? c.onSurface,
          ),
        ),
      ),
      if (actions.isNotEmpty)
        _BarChild(
          slot: _BarSlot.actions,
          child: _Actions(padding: actionPadding, actions: actions),
        ),
      if (sub != null && sub.isNotEmpty)
        _BarChild(
          slot: _BarSlot.subtitle,
          child: _Subtitle(text: sub, color: subtitleColor),
        ),
    ];
    final Widget content = Padding(
      padding: EdgeInsets.only(
        top: insets.top,
        left: windowInsetsPadding ? insets.left : 0,
        right: windowInsetsPadding ? insets.right : 0,
      ),
      child: _BarLayout(
        large: false,
        centerTitle: centerTitle,
        titlePadding: margin ?? titlePadding,
        collapsedTitleScale: 1,
        hideSubtitleOnCollapse: true,
        divider: showDivider && !gradientGlass,
        dividerColor: dividerColor ?? c.dividerLine,
        scrollController: scrollController,
        textDirection: Directionality.of(context),
        children: children,
      ),
    );
    final ScrollController? controller = scrollController;
    return _BarSurface(
      color: color ?? c.surface,
      blur: blur,
      gradientGlass: gradientGlass,
      materialColor:
          materialColor ??
          (theme.isDark ? SoftTopAppBarDefaults.darkMaterialColor : c.surface),
      dark: theme.isDark,
      materialAlpha: controller == null
          ? const AlwaysStoppedAnimation<double>(1)
          : _DerivedAnimation(
              controller,
              () => controller.positions.length == 1
                  ? SoftTopAppBarDefaults.scrollAlpha(controller.offset)
                  : 0,
            ),
      child: content,
    );
  }
}

/// A large top app bar for a [CustomScrollView]: a sliver, pinned, that
/// shows a 32 large title under the toolbar row and collapses into a 52
/// toolbar as the content scrolls up, expanding again only at the top.
///
/// The bar is 110 high expanded (taller with a subtitle). While it
/// collapses the large title slides and scales into the 24 title after the
/// navigation icon (18 over a subtitle) on an eased curve, and is swapped for
/// it once fully collapsed. The subtitle rides the scroll, fading out unless
/// [hideSubtitleOnCollapse] is false. A hairline fades in at the bottom over
/// the whole collapse while its margin narrows from 24 to 0.
///
/// A scroll that stops with the bar part-collapsed snaps it to the nearer
/// end over 180 ms (unless [snap] is false).
///
/// The surface rules are [SoftTopAppBar]'s; the gradient glass fades in once
/// the content has scrolled 30 under the collapsed bar.
class SoftLargeTopAppBar extends StatefulWidget {
  const SoftLargeTopAppBar({
    super.key,
    required this.title,
    this.largeTitle,
    this.subtitle,
    this.navigationIcon,
    this.actions = const <Widget>[],
    this.color,
    this.titleColor,
    this.largeTitleColor,
    this.subtitleColor,
    this.dividerColor,
    this.materialColor,
    this.showDivider = true,
    this.hideSubtitleOnCollapse = true,
    this.blur = false,
    this.gradientGlass = false,
    this.snap = true,
    this.windowInsetsPadding = true,
    this.titlePadding = SoftTopAppBarDefaults.titlePadding,
    this.navigationIconPadding = SoftTopAppBarDefaults.navigationIconPadding,
    this.actionIconPadding = SoftTopAppBarDefaults.actionIconPadding,
  });

  /// The collapsed title.
  final String title;

  /// The expanded title; [title] by default.
  final String? largeTitle;
  final String? subtitle;
  final Widget? navigationIcon;
  final List<Widget> actions;
  final Color? color;
  final Color? titleColor;
  final Color? largeTitleColor;
  final Color? subtitleColor;
  final Color? dividerColor;
  final Color? materialColor;
  final bool showDivider;
  final bool hideSubtitleOnCollapse;
  final bool blur;
  final bool gradientGlass;
  final bool snap;
  final bool windowInsetsPadding;
  final double titlePadding;
  final double navigationIconPadding;
  final double actionIconPadding;

  @override
  State<SoftLargeTopAppBar> createState() => _SoftLargeTopAppBarState();
}

class _SoftLargeTopAppBarState extends State<SoftLargeTopAppBar> {
  final ValueNotifier<double> _shrink = ValueNotifier<double>(0);
  late final _DerivedAnimation _materialAlpha = _DerivedAnimation(
    _shrink,
    () => SoftTopAppBarDefaults.scrollAlpha(
      math.max(0, _shrink.value - _expansion),
    ),
  );
  ScrollPosition? _position;
  double _expansion = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final ScrollPosition? position = Scrollable.maybeOf(context)?.position;
    if (!identical(position, _position)) {
      _position?.isScrollingNotifier.removeListener(_onScrolling);
      _position = position;
      position?.isScrollingNotifier.addListener(_onScrolling);
    }
  }

  @override
  void dispose() {
    _position?.isScrollingNotifier.removeListener(_onScrolling);
    _shrink.dispose();
    super.dispose();
  }

  void _onScrolling() {
    final ScrollPosition? position = _position;
    if (!widget.snap || position == null) return;
    if (position.isScrollingNotifier.value) return;
    // Settle outside the notification that ended the scroll.
    scheduleMicrotask(_settle);
  }

  void _settle() {
    final ScrollPosition? position = _position;
    if (!mounted || position == null || !position.hasPixels) return;
    if (position.isScrollingNotifier.value) return;
    final double expansion = _expansion;
    if (expansion <= 0) return;
    final double shrink = _shrink.value.clamp(0.0, expansion);
    final double fraction = shrink / expansion;
    if (fraction < 0.01 || fraction >= 1) return;
    final double target = fraction < 0.5
        ? position.pixels - shrink
        : position.pixels + (expansion - shrink);
    if (softReduceMotion(context)) {
      position.jumpTo(target);
    } else {
      position.animateTo(
        target,
        duration: SoftTopAppBarDefaults.snapDuration,
        curve: SoftTopAppBarDefaults.snapCurve,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final SoftThemeData theme = SoftTheme.of(context);
    final SoftColors c = theme.colors;
    final EdgeInsets insets = MediaQuery.paddingOf(context);
    final TextScaler scaler = MediaQuery.textScalerOf(context);
    final TextDirection direction = Directionality.of(context);
    final String sub = widget.subtitle ?? '';
    final bool hasSubtitle = sub.isNotEmpty;
    final String largeTitle = widget.largeTitle ?? widget.title;

    final TextStyle largeStyle = theme.textStyles.title1.copyWith(
      fontSize: SoftTopAppBarDefaults.largeTitleTextSize,
      fontWeight: FontWeight.w600,
      color: widget.largeTitleColor ?? c.onSurface,
    );
    final double collapsedSize = hasSubtitle
        ? SoftTopAppBarDefaults.collapsedTitleWithSubtitleTextSize
        : SoftTopAppBarDefaults.collapsedTitleTextSize;
    final TextStyle collapsedStyle =
        (hasSubtitle ? theme.textStyles.title4 : theme.textStyles.title2)
            .copyWith(
              fontSize: collapsedSize,
              fontWeight: FontWeight.w500,
              color: widget.titleColor ?? c.onSurface,
            );
    final TextStyle subtitleStyle = theme.textStyles.body2;

    final double expanded = _expandedHeight(
      largeTitle,
      largeStyle,
      hasSubtitle ? sub : null,
      subtitleStyle,
      scaler,
      direction,
    );
    _expansion = math.max(0, expanded - SoftTopAppBarDefaults.collapsedHeight);

    final double navPadding = widget.navigationIconPadding;
    final List<Widget> children = <Widget>[
      if (widget.navigationIcon != null)
        _BarChild(
          slot: _BarSlot.navigation,
          child: Padding(
            padding: EdgeInsetsDirectional.only(start: navPadding),
            child: widget.navigationIcon,
          ),
        ),
      _BarChild(
        slot: _BarSlot.title,
        child: ExcludeSemantics(
          child: Text(
            widget.title,
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.ellipsis,
            style: collapsedStyle,
          ),
        ),
      ),
      if (widget.actions.isNotEmpty)
        _BarChild(
          slot: _BarSlot.actions,
          child: _Actions(
            padding: widget.actionIconPadding,
            actions: widget.actions,
          ),
        ),
      _BarChild(
        slot: _BarSlot.largeTitle,
        child: Semantics(
          header: true,
          child: Text(
            largeTitle,
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.ellipsis,
            style: largeStyle,
          ),
        ),
      ),
      if (hasSubtitle)
        _BarChild(
          slot: _BarSlot.subtitle,
          child: _Subtitle(text: sub, color: widget.subtitleColor),
        ),
    ];

    final Widget bar = _BarSurface(
      color: widget.color ?? c.surface,
      blur: widget.blur,
      gradientGlass: widget.gradientGlass,
      materialColor:
          widget.materialColor ??
          (theme.isDark ? SoftTopAppBarDefaults.darkMaterialColor : c.surface),
      dark: theme.isDark,
      materialAlpha: _materialAlpha,
      child: Padding(
        padding: EdgeInsets.only(
          top: insets.top,
          left: widget.windowInsetsPadding ? insets.left : 0,
          right: widget.windowInsetsPadding ? insets.right : 0,
        ),
        child: _BarLayout(
          large: true,
          centerTitle: false,
          titlePadding: widget.titlePadding,
          collapsedTitleScale:
              collapsedSize / SoftTopAppBarDefaults.largeTitleTextSize,
          hideSubtitleOnCollapse: widget.hideSubtitleOnCollapse,
          divider: widget.showDivider && !widget.gradientGlass,
          dividerColor: widget.dividerColor ?? c.dividerLine,
          scrollController: null,
          textDirection: direction,
          children: children,
        ),
      ),
    );
    return SliverPersistentHeader(
      pinned: true,
      delegate: _LargeBarDelegate(
        minExtent: insets.top + SoftTopAppBarDefaults.collapsedHeight,
        maxExtent: insets.top + expanded,
        child: bar,
        shrink: _shrink,
      ),
    );
  }

  static double _expandedHeight(
    String largeTitle,
    TextStyle largeStyle,
    String? subtitle,
    TextStyle subtitleStyle,
    TextScaler scaler,
    TextDirection direction,
  ) {
    double measure(String text, TextStyle style) {
      final TextPainter painter = TextPainter(
        text: TextSpan(text: text, style: style),
        maxLines: 1,
        textScaler: scaler,
        textDirection: direction,
      )..layout();
      final double h = painter.height;
      painter.dispose();
      return h;
    }

    final double titleHeight = measure(largeTitle, largeStyle);
    final double subtitleHeight = subtitle == null
        ? 0
        : measure(subtitle, subtitleStyle);
    final double content =
        SoftTopAppBarDefaults.largeTitleTopPadding +
        titleHeight +
        (subtitle == null
            ? 0
            : SoftTopAppBarDefaults.subtitleMarginTop + subtitleHeight);
    return math.max(
      SoftTopAppBarDefaults.expandedHeight + subtitleHeight,
      content + SoftTopAppBarDefaults.largeTitleBottomPadding,
    );
  }
}

class _LargeBarDelegate extends SliverPersistentHeaderDelegate {
  _LargeBarDelegate({
    required this.minExtent,
    required this.maxExtent,
    required this.child,
    required this.shrink,
  });

  @override
  final double minExtent;
  @override
  final double maxExtent;
  final Widget child;
  final ValueNotifier<double> shrink;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    // The bar reads its height from its constraints, so the same widget is
    // returned on every scroll frame and nothing below it rebuilds.
    shrink.value = shrinkOffset;
    return child;
  }

  @override
  bool shouldRebuild(_LargeBarDelegate oldDelegate) =>
      !identical(oldDelegate.child, child) ||
      oldDelegate.minExtent != minExtent ||
      oldDelegate.maxExtent != maxExtent ||
      !identical(oldDelegate.shrink, shrink);
}

/// An [Animation] whose value is computed from another listenable.
class _DerivedAnimation extends Animation<double> {
  _DerivedAnimation(this._source, this._compute);

  final Listenable _source;
  final double Function() _compute;

  @override
  void addListener(VoidCallback listener) => _source.addListener(listener);

  @override
  void removeListener(VoidCallback listener) =>
      _source.removeListener(listener);

  @override
  void addStatusListener(AnimationStatusListener listener) {}

  @override
  void removeStatusListener(AnimationStatusListener listener) {}

  @override
  AnimationStatus get status => AnimationStatus.forward;

  @override
  double get value => _compute().clamp(0.0, 1.0);
}

class _Actions extends StatelessWidget {
  const _Actions({required this.padding, required this.actions});

  final double padding;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsetsDirectional.only(end: padding),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: SoftTopAppBarDefaults.actionSpacing,
        children: actions,
      ),
    );
  }
}

class _Subtitle extends StatelessWidget {
  const _Subtitle({required this.text, required this.color});

  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final SoftThemeData theme = SoftTheme.of(context);
    return Text(
      text,
      maxLines: 1,
      softWrap: false,
      overflow: TextOverflow.ellipsis,
      style: theme.textStyles.body2.copyWith(
        color: color ?? theme.colors.onSurfaceVariantSummary,
      ),
    );
  }
}

/// The surface behind the bar: a fill, the uniform glass or the gradient
/// glass material.
class _BarSurface extends StatelessWidget {
  const _BarSurface({
    required this.color,
    required this.blur,
    required this.gradientGlass,
    required this.materialColor,
    required this.dark,
    required this.materialAlpha,
    required this.child,
  });

  final Color color;
  final bool blur;
  final bool gradientGlass;
  final Color materialColor;
  final bool dark;
  final Animation<double> materialAlpha;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (gradientGlass) {
      return Stack(
        clipBehavior: Clip.none,
        fit: StackFit.passthrough,
        children: <Widget>[
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            bottom: -SoftTopAppBarDefaults.materialExtraHeight,
            child: IgnorePointer(
              child: FadeTransition(
                opacity: materialAlpha,
                child: _GradientMaterial(
                  color: materialColor,
                  dark: dark,
                  blur: blur,
                ),
              ),
            ),
          ),
          child,
        ],
      );
    }
    // A transparent surface: the caller paints what is behind the bar.
    if (color.a == 0) return child;
    if (!blur) return ColoredBox(color: color, child: child);
    final double dpr = MediaQuery.devicePixelRatioOf(context);
    final double sigma = SoftGlassDefaults.sigmaOf(
      SoftTopAppBarDefaults.blurRadiusPx / dpr,
    );
    final double alpha = color.computeLuminance() < 0.5
        ? SoftTopAppBarDefaults.backgroundAlphaDark
        : SoftTopAppBarDefaults.backgroundAlpha;
    return ClipRect(
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(
          sigmaX: sigma,
          sigmaY: sigma,
          tileMode: TileMode.mirror,
        ),
        child: ColoredBox(
          color: color.withValues(alpha: alpha),
          child: child,
        ),
      ),
    );
  }
}

class _GradientMaterial extends StatelessWidget {
  const _GradientMaterial({
    required this.color,
    required this.dark,
    required this.blur,
  });

  final Color color;
  final bool dark;
  final bool blur;

  @override
  Widget build(BuildContext context) {
    final Widget ramp = CustomPaint(
      painter: _RampPainter(color: color, dark: dark),
      child: const SizedBox.expand(),
    );
    if (!blur) return ramp;
    final double dpr = MediaQuery.devicePixelRatioOf(context);
    return ProgressiveBlur(
      maxBlurRadius: SoftTopAppBarDefaults.gradientBlurRadiusPx / dpr,
      child: ramp,
    );
  }
}

class _RampPainter extends CustomPainter {
  const _RampPainter({required this.color, required this.dark});

  final Color color;
  final bool dark;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final List<Color> colors;
    final List<double> stops;
    if (dark) {
      colors = <Color>[
        color.withValues(alpha: SoftTopAppBarDefaults.gradientAlphaDark),
        color.withValues(alpha: 0),
      ];
      stops = const <double>[0, 1];
    } else {
      colors = <Color>[
        for (final double a in SoftTopAppBarDefaults.gradientAlphas)
          color.withValues(alpha: a),
      ];
      stops = SoftTopAppBarDefaults.gradientStops;
    }
    final Rect rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = ui.Gradient.linear(
          rect.topCenter,
          rect.bottomCenter,
          colors,
          stops,
        ),
    );
  }

  @override
  bool shouldRepaint(_RampPainter old) =>
      old.color != color || old.dark != dark;
}

enum _BarSlot { navigation, actions, title, largeTitle, subtitle }

class _BarParentData extends ContainerBoxParentData<RenderBox> {
  _BarSlot? slot;
  double alpha = 1;
  double scale = 1;
}

class _BarChild extends ParentDataWidget<_BarParentData> {
  const _BarChild({required this.slot, required super.child});

  final _BarSlot slot;

  @override
  void applyParentData(RenderObject renderObject) {
    final _BarParentData data = renderObject.parentData! as _BarParentData;
    if (data.slot != slot) {
      data.slot = slot;
      renderObject.parent?.markNeedsLayout();
    }
  }

  @override
  Type get debugTypicalAncestorWidgetClass => _BarLayout;
}

class _BarLayout extends MultiChildRenderObjectWidget {
  const _BarLayout({
    required this.large,
    required this.centerTitle,
    required this.titlePadding,
    required this.collapsedTitleScale,
    required this.hideSubtitleOnCollapse,
    required this.divider,
    required this.dividerColor,
    required this.scrollController,
    required this.textDirection,
    required super.children,
  });

  final bool large;
  final bool centerTitle;
  final double titlePadding;
  final double collapsedTitleScale;
  final bool hideSubtitleOnCollapse;
  final bool divider;
  final Color dividerColor;
  final ScrollController? scrollController;
  final TextDirection textDirection;

  @override
  _RenderBar createRenderObject(BuildContext context) => _RenderBar(
    large: large,
    centerTitle: centerTitle,
    titlePadding: titlePadding,
    collapsedTitleScale: collapsedTitleScale,
    hideSubtitleOnCollapse: hideSubtitleOnCollapse,
    divider: divider,
    dividerColor: dividerColor,
    scrollController: scrollController,
    textDirection: textDirection,
  );

  @override
  void updateRenderObject(BuildContext context, _RenderBar renderObject) {
    renderObject
      ..large = large
      ..centerTitle = centerTitle
      ..titlePadding = titlePadding
      ..collapsedTitleScale = collapsedTitleScale
      ..hideSubtitleOnCollapse = hideSubtitleOnCollapse
      ..divider = divider
      ..dividerColor = dividerColor
      ..scrollController = scrollController
      ..textDirection = textDirection;
  }
}

/// Lays out both bar forms. The large form reads its current height from
/// its constraints (the pinned sliver hands it the scrolled extent), so a
/// scroll only re-lays it out.
class _RenderBar extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _BarParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, _BarParentData> {
  _RenderBar({
    required bool large,
    required bool centerTitle,
    required double titlePadding,
    required double collapsedTitleScale,
    required bool hideSubtitleOnCollapse,
    required bool divider,
    required Color dividerColor,
    required ScrollController? scrollController,
    required TextDirection textDirection,
  }) : _large = large,
       _centerTitle = centerTitle,
       _titlePadding = titlePadding,
       _collapsedTitleScale = collapsedTitleScale,
       _hideSubtitleOnCollapse = hideSubtitleOnCollapse,
       _divider = divider,
       _dividerColor = dividerColor,
       _scrollController = scrollController,
       _textDirection = textDirection;

  bool _large;
  set large(bool v) {
    if (v == _large) return;
    _large = v;
    markNeedsLayout();
  }

  bool _centerTitle;
  set centerTitle(bool v) {
    if (v == _centerTitle) return;
    _centerTitle = v;
    markNeedsLayout();
  }

  double _titlePadding;
  set titlePadding(double v) {
    if (v == _titlePadding) return;
    _titlePadding = v;
    markNeedsLayout();
  }

  double _collapsedTitleScale;
  set collapsedTitleScale(double v) {
    if (v == _collapsedTitleScale) return;
    _collapsedTitleScale = v;
    markNeedsLayout();
  }

  bool _hideSubtitleOnCollapse;
  set hideSubtitleOnCollapse(bool v) {
    if (v == _hideSubtitleOnCollapse) return;
    _hideSubtitleOnCollapse = v;
    markNeedsLayout();
  }

  bool _divider;
  set divider(bool v) {
    if (v == _divider) return;
    _divider = v;
    markNeedsPaint();
  }

  Color _dividerColor;
  set dividerColor(Color v) {
    if (v == _dividerColor) return;
    _dividerColor = v;
    markNeedsPaint();
  }

  ScrollController? _scrollController;
  set scrollController(ScrollController? v) {
    if (identical(v, _scrollController)) return;
    if (attached) _scrollController?.removeListener(markNeedsPaint);
    _scrollController = v;
    if (attached) v?.addListener(markNeedsPaint);
    markNeedsPaint();
  }

  TextDirection _textDirection;
  set textDirection(TextDirection v) {
    if (v == _textDirection) return;
    _textDirection = v;
    markNeedsLayout();
  }

  /// The large form's collapse, 0 (expanded) to 1.
  double _fraction = 0;

  final LayerHandle<OpacityLayer> _subtitleLayer = LayerHandle<OpacityLayer>();

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _scrollController?.addListener(markNeedsPaint);
  }

  @override
  void detach() {
    _scrollController?.removeListener(markNeedsPaint);
    super.detach();
  }

  @override
  void dispose() {
    _subtitleLayer.layer = null;
    super.dispose();
  }

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _BarParentData) {
      child.parentData = _BarParentData();
    }
  }

  RenderBox? _slot(_BarSlot slot) {
    RenderBox? child = firstChild;
    while (child != null) {
      final _BarParentData data = child.parentData! as _BarParentData;
      if (data.slot == slot) return child;
      child = data.nextSibling;
    }
    return null;
  }

  void _place(RenderBox child, double x, double y, double width) {
    final _BarParentData data = child.parentData! as _BarParentData;
    final double dx = _textDirection == TextDirection.rtl
        ? width - x - child.size.width
        : x;
    data.offset = Offset(dx, y);
  }

  @override
  void performLayout() {
    final RenderBox? nav = _slot(_BarSlot.navigation);
    final RenderBox? actions = _slot(_BarSlot.actions);
    final RenderBox? title = _slot(_BarSlot.title);
    final RenderBox? largeTitle = _slot(_BarSlot.largeTitle);
    final RenderBox? subtitle = _slot(_BarSlot.subtitle);
    final BoxConstraints loose = BoxConstraints(
      maxWidth: constraints.maxWidth,
      maxHeight: double.infinity,
    );
    nav?.layout(loose, parentUsesSize: true);
    actions?.layout(loose, parentUsesSize: true);
    final double navWidth = nav?.size.width ?? 0;
    final double actionsWidth = actions?.size.width ?? 0;
    final double width = constraints.hasBoundedWidth
        ? constraints.maxWidth
        : navWidth + actionsWidth + 2 * _titlePadding + 200;
    for (RenderBox? c = firstChild; c != null; c = childAfter(c)) {
      final _BarParentData d = c.parentData! as _BarParentData;
      d
        ..alpha = 1
        ..scale = 1;
    }
    if (_large) {
      _layoutLarge(width, nav, actions, title, largeTitle, subtitle);
    } else {
      _layoutSmall(width, nav, actions, title, subtitle);
    }
  }

  void _layoutSmall(
    double width,
    RenderBox? nav,
    RenderBox? actions,
    RenderBox? title,
    RenderBox? subtitle,
  ) {
    const double row = SoftTopAppBarDefaults.collapsedHeight;
    const double centre = row / 2;
    final double navWidth = nav?.size.width ?? 0;
    final double actionsWidth = actions?.size.width ?? 0;
    final double start = nav != null
        ? navWidth + SoftTopAppBarDefaults.navigationIconGap
        : _titlePadding;
    final double end = actions != null
        ? width - actionsWidth - SoftTopAppBarDefaults.actionIconGap
        : width - _titlePadding;
    final double titleMax;
    if (_centerTitle) {
      final double outer = math.max(
        _titlePadding,
        math.max(navWidth, actionsWidth),
      );
      titleMax = math.max(0, width - 2 * outer);
    } else {
      titleMax = math.max(0, end - start);
    }
    final BoxConstraints textConstraints = BoxConstraints(maxWidth: titleMax);
    title?.layout(textConstraints, parentUsesSize: true);
    subtitle?.layout(textConstraints, parentUsesSize: true);
    final double titleWidth = title?.size.width ?? 0;
    final double titleHeight = title?.size.height ?? 0;
    final double subtitleHeight = subtitle?.size.height ?? 0;
    final double titleX = _centerTitle
        ? math.max(0, (width - titleWidth) / 2)
        : start;
    final double stack =
        titleHeight +
        (subtitle != null
            ? SoftTopAppBarDefaults.subtitleMarginTop + subtitleHeight
            : 0);
    final double titleY = subtitle != null
        ? math.max(0, (row - stack) / 2)
        : centre - titleHeight / 2;
    final double height = math.max(
      row,
      stack +
          (subtitle != null ? SoftTopAppBarDefaults.subtitleBottomPadding : 0),
    );
    if (nav != null) _place(nav, 0, centre - nav.size.height / 2, width);
    if (actions != null) {
      _place(
        actions,
        width - actionsWidth,
        centre - actions.size.height / 2,
        width,
      );
    }
    if (title != null) _place(title, titleX, titleY, width);
    if (subtitle != null) {
      _place(
        subtitle,
        titleX,
        titleY + titleHeight + SoftTopAppBarDefaults.subtitleMarginTop,
        width,
      );
    }
    size = constraints.constrain(Size(width, height));
  }

  void _layoutLarge(
    double width,
    RenderBox? nav,
    RenderBox? actions,
    RenderBox? title,
    RenderBox? largeTitle,
    RenderBox? subtitle,
  ) {
    const double collapsed = SoftTopAppBarDefaults.collapsedHeight;
    const double centre = collapsed / 2;
    final double navWidth = nav?.size.width ?? 0;
    final double actionsWidth = actions?.size.width ?? 0;
    final double collapsedTitleX = nav != null
        ? navWidth + SoftTopAppBarDefaults.navigationIconGap
        : _titlePadding;
    final double collapsedTitleEnd = actions != null
        ? width - actionsWidth - SoftTopAppBarDefaults.actionIconGap
        : width - _titlePadding;
    title?.layout(
      BoxConstraints(
        maxWidth: math.max(0, collapsedTitleEnd - collapsedTitleX),
      ),
      parentUsesSize: true,
    );
    final BoxConstraints wide = BoxConstraints(
      maxWidth: math.max(0, width - 2 * _titlePadding),
    );
    largeTitle?.layout(wide, parentUsesSize: true);
    subtitle?.layout(wide, parentUsesSize: true);
    final double titleHeight = title?.size.height ?? 0;
    final double largeHeight = largeTitle?.size.height ?? 0;
    final double subtitleHeight = subtitle?.size.height ?? 0;

    final double content =
        SoftTopAppBarDefaults.largeTitleTopPadding +
        largeHeight +
        (subtitle != null
            ? SoftTopAppBarDefaults.subtitleMarginTop + subtitleHeight
            : 0);
    final double expanded = math.max(
      SoftTopAppBarDefaults.expandedHeight + subtitleHeight,
      content + SoftTopAppBarDefaults.largeTitleBottomPadding,
    );
    final double expansion = math.max(0, expanded - collapsed);
    final double height = constraints.hasBoundedHeight
        ? constraints.maxHeight.clamp(collapsed, expanded)
        : expanded;
    final double offset = (height - expanded).clamp(-expansion, 0.0);
    final double fraction = expansion > 0
        ? (-offset / expansion).clamp(0.0, 1.0)
        : 0.0;
    _fraction = fraction;
    final double eased = SoftTopAppBarDefaults.collapsingTitleEasing.transform(
      fraction,
    );
    final bool subtitleStays = subtitle != null && !_hideSubtitleOnCollapse;
    final double collapsedTitleY = subtitleStays
        ? math.max(
            0,
            collapsed -
                subtitleHeight -
                SoftTopAppBarDefaults.subtitleMarginTop -
                titleHeight,
          )
        : centre - titleHeight / 2;
    final bool swapped =
        fraction >= SoftTopAppBarDefaults.collapsedTitleSwapFraction;

    if (nav != null) _place(nav, 0, centre - nav.size.height / 2, width);
    if (actions != null) {
      _place(
        actions,
        width - actionsWidth,
        centre - actions.size.height / 2,
        width,
      );
    }
    if (subtitle != null) {
      _place(
        subtitle,
        _titlePadding,
        expanded -
            subtitleHeight -
            SoftTopAppBarDefaults.largeTitleBottomPadding * (1 - fraction) +
            offset,
        width,
      );
      (subtitle.parentData! as _BarParentData).alpha = _hideSubtitleOnCollapse
          ? 1 - fraction
          : 1;
    }
    if (largeTitle != null) {
      final double x = ui.lerpDouble(_titlePadding, collapsedTitleX, eased)!;
      final double y =
          ui.lerpDouble(
            SoftTopAppBarDefaults.largeTitleTopPadding,
            collapsedTitleY + expansion,
            eased,
          )! +
          offset;
      _place(largeTitle, x, y, width);
      (largeTitle.parentData! as _BarParentData)
        ..scale = ui.lerpDouble(1, _collapsedTitleScale, eased)!
        ..alpha = swapped ? 0 : 1;
    }
    if (title != null) {
      _place(title, collapsedTitleX, collapsedTitleY, width);
      (title.parentData! as _BarParentData).alpha = swapped ? 1 : 0;
    }
    size = constraints.constrain(Size(width, height));
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    for (final _BarSlot slot in const <_BarSlot>[
      _BarSlot.actions,
      _BarSlot.navigation,
    ]) {
      final RenderBox? child = _slot(slot);
      if (child == null) continue;
      final _BarParentData data = child.parentData! as _BarParentData;
      final bool hit = result.addWithPaintOffset(
        offset: data.offset,
        position: position,
        hitTest: (BoxHitTestResult result, Offset transformed) =>
            child.hitTest(result, position: transformed),
      );
      if (hit) return true;
    }
    return false;
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    for (
      RenderBox? child = firstChild;
      child != null;
      child = childAfter(child)
    ) {
      final _BarParentData data = child.parentData! as _BarParentData;
      if (data.alpha <= 0) continue;
      final Offset at = offset + data.offset;
      if (data.slot == _BarSlot.subtitle && data.alpha < 1) {
        final RenderBox subtitle = child;
        _subtitleLayer.layer = context.pushOpacity(
          at,
          (data.alpha * 255).round(),
          (PaintingContext c, Offset o) => c.paintChild(subtitle, o),
          oldLayer: _subtitleLayer.layer,
        );
        continue;
      }
      if (data.scale != 1) {
        final double pivotX = _textDirection == TextDirection.rtl
            ? child.size.width
            : 0;
        final Matrix4 transform = Matrix4.identity()
          ..translateByDouble(pivotX, 0, 0, 1)
          ..scaleByDouble(data.scale, data.scale, 1, 1)
          ..translateByDouble(-pivotX, 0, 0, 1);
        final RenderBox scaled = child;
        context.pushTransform(
          needsCompositing,
          at,
          transform,
          (PaintingContext c, Offset o) => c.paintChild(scaled, o),
        );
        continue;
      }
      context.paintChild(child, at);
    }
    if (_divider) _paintDivider(context.canvas, offset);
  }

  void _paintDivider(Canvas canvas, Offset offset) {
    final double alpha;
    final double marginFraction;
    if (_large) {
      alpha = _fraction;
      marginFraction = _fraction;
    } else {
      final ScrollController? controller = _scrollController;
      final double scrolled =
          controller != null && controller.positions.length == 1
          ? controller.offset
          : 0;
      alpha = (scrolled / SoftTopAppBarDefaults.dividerAlphaChangeOffset).clamp(
        0.0,
        1.0,
      );
      marginFraction =
          ((scrolled - SoftTopAppBarDefaults.dividerWidthStartCountOffset) /
                  SoftTopAppBarDefaults.dividerWidthChangeOffset)
              .clamp(0.0, 1.0);
    }
    if (alpha <= 0) return;
    final double inset = ui.lerpDouble(
      SoftTopAppBarDefaults.dividerExpandedMarginHorizontal,
      0,
      marginFraction,
    )!;
    const double stroke = SoftTopAppBarDefaults.dividerThickness;
    final double y = offset.dy + size.height - stroke / 2;
    canvas.drawLine(
      Offset(offset.dx + inset, y),
      Offset(offset.dx + size.width - inset, y),
      Paint()
        ..color = _dividerColor.withValues(alpha: _dividerColor.a * alpha)
        ..strokeWidth = stroke,
    );
  }
}
