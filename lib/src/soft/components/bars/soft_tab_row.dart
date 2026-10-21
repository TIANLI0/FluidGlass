import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../../foundation/soft_motion.dart';
import '../../foundation/soft_pressable.dart';
import '../../foundation/soft_theme.dart';

/// The tab row (segmented control) defaults.
abstract final class SoftTabRowDefaults {
  /// The height of both forms.
  static const double height = 40;

  /// The tiny form's height, contour inset and indicator radius.
  static const double tinyHeight = 32;
  static const double tinyContourPadding = 2;
  static const double tinyCornerRadius = 14;

  /// The frameless form's indicator radius: a capsule.
  static const double cornerRadius = 20;

  /// The contour form's indicator radius and inset.
  static const double contourCornerRadius = 16;
  static const double contourPadding = 4;

  /// The narrowest segment.
  static const double minWidth = 52;

  /// The horizontal padding around a segment's label.
  static const double segmentPadding = 12;

  /// The indicator's drop shadow: offset and blur.
  static const double shadowOffsetY = 2;
  static const double shadowBlurRadius = 1;

  static const Color containerLight = Color(0x0F000000);
  static const Color containerDark = Color(0x1FFFFFFF);
  static const Color indicatorLight = Color(0xB2FFFFFF);
  static const Color indicatorDark = Color(0x33FFFFFF);
  static const Color shadowLight = Color(0x0D000000);
  static const Color shadowDark = Color(0x14000000);

  /// The label colour crossfade on a selection change.
  static const Duration textColorDuration = Duration(milliseconds: 300);
  static const Cubic textColorCurve = Cubic(0.3, 0, 0.1, 1);

  /// The press scale spring, and the indicator's when the selected segment
  /// is pressed: (0.3, 0).
  static final SpringDescription pressSpring = softSpring(
    damping: 1,
    response: 0.3,
  );

  /// The indicator's initial width velocity on a move, in physical pixels per
  /// second.
  static const double widthInitialVelocityPx = 1000;

  /// How far a pressed segment of `width` × `height` shrinks: 0.92 up to a
  /// 48 × 48 area, easing to 0.98 at 328 × 220.
  static double pressedScale(double width, double height) {
    const double minArea = 48.0 * 48.0;
    const double maxArea = 328.0 * 220.0;
    final double area = width * height;
    if (area <= minArea) return 0.92;
    if (area >= maxArea) return 0.98;
    return 0.92 +
        0.06 *
            SoftMotion.inEase.transform((area - minArea) / (maxArea - minArea));
  }

  /// Distributes [available] among segments of [natural] width: narrow ones
  /// keep their width and the rest share what is left. When fewer than
  /// [minWidth] per segment fit, the natural widths stand and the row
  /// scrolls.
  static List<double> segmentWidths(
    List<double> natural,
    double available,
    double minWidth,
    double maxWidth,
  ) {
    final int count = natural.length;
    if (count == 0) return const <double>[];
    if (!available.isFinite || available <= 0 || available / count < minWidth) {
      return <double>[for (final double w in natural) math.min(w, maxWidth)];
    }
    final List<int> order = List<int>.generate(count, (int i) => i)
      ..sort((int a, int b) => natural[a].compareTo(natural[b]));
    final double fair = available / count;
    final List<double> widths = List<double>.filled(count, 0);
    double remaining = available;
    double share = fair;
    int locked = -1;
    int i = 0;
    while (i < count) {
      final double n = natural[order[i]];
      if (n < share) {
        widths[order[i]] = n;
        remaining -= n;
        i++;
      } else if (locked == i) {
        while (i < count) {
          widths[order[i]] = share;
          i++;
        }
        remaining = 0;
      } else {
        share = remaining / (count - i);
        locked = i;
      }
    }
    if (locked == -1) {
      return List<double>.filled(count, math.min(fair, maxWidth));
    }
    if (remaining > 0 && count > 1) {
      for (int j = 0; j < count - 1; j++) {
        widths[order[j]] += remaining / (count - 1);
      }
    }
    return <double>[for (final double w in widths) math.min(w, maxWidth)];
  }
}

/// The colours of a [SoftTabRow].
@immutable
class SoftTabRowColors {
  const SoftTabRowColors({
    required this.container,
    required this.content,
    required this.indicator,
    required this.selectedContent,
    required this.indicatorShadow,
  });

  /// The theme's colours: the translucent container and indicator of the
  /// light or dark scheme, `onSurface` labels.
  factory SoftTabRowColors.of(BuildContext context, {bool container = true}) {
    final SoftThemeData theme = SoftTheme.of(context);
    final bool dark = theme.isDark;
    return SoftTabRowColors(
      container: container
          ? (dark
                ? SoftTabRowDefaults.containerDark
                : SoftTabRowDefaults.containerLight)
          : const Color(0x00000000),
      content: theme.colors.onSurface,
      indicator: dark
          ? SoftTabRowDefaults.indicatorDark
          : SoftTabRowDefaults.indicatorLight,
      selectedContent: theme.colors.onSurface,
      indicatorShadow: dark
          ? SoftTabRowDefaults.shadowDark
          : SoftTabRowDefaults.shadowLight,
    );
  }

  final Color container;
  final Color content;
  final Color indicator;
  final Color selectedContent;
  final Color indicatorShadow;

  @override
  bool operator ==(Object other) =>
      other is SoftTabRowColors &&
      other.container == container &&
      other.content == content &&
      other.indicator == indicator &&
      other.selectedContent == selectedContent &&
      other.indicatorShadow == indicatorShadow;

  @override
  int get hashCode => Object.hash(
    container,
    content,
    indicator,
    selectedContent,
    indicatorShadow,
  );
}

/// A tab row — the reference's segmented control: labels laid out across
/// the row, with a sliding indicator under the selected one.
///
/// Each segment is as wide as its label plus 12 each side (at least 52); the
/// row's width is shared out, narrow labels keeping their width. When fewer
/// than 52 per segment fit, the segments keep their natural widths and the
/// row scrolls sideways, bringing the selected one to the centre.
///
/// A selection change moves the indicator's centre and width on two
/// separate springs (a wider jump settles with less bounce); the labels
/// crossfade their colour over 300 ms and switch weight at once. Pressing
/// a segment shrinks it (0.92–0.98 by area), and pressing the selected one
/// shrinks the indicator with it.
///
/// [SoftTabRow.new] has no container, a 40 capsule indicator; the
/// [SoftTabRow.contour] form sits in a translucent capsule with the
/// indicator inset by 4 (the tiny form: 32 high, 2 inset, radius 14).
class SoftTabRow extends StatefulWidget {
  /// The frameless form.
  const SoftTabRow({
    super.key,
    required this.tabs,
    required this.selectedIndex,
    required this.onTabSelected,
    this.colors,
    this.minWidth = SoftTabRowDefaults.minWidth,
    this.maxWidth = double.infinity,
    this.height = SoftTabRowDefaults.height,
    this.cornerRadius = SoftTabRowDefaults.cornerRadius,
    this.segmentPadding = SoftTabRowDefaults.segmentPadding,
    this.itemSpacing = 0,
    this.alignment = Alignment.center,
  }) : contourPadding = 0,
       _container = false;

  /// The form inside a container capsule.
  const SoftTabRow.contour({
    super.key,
    required this.tabs,
    required this.selectedIndex,
    required this.onTabSelected,
    this.colors,
    this.minWidth = SoftTabRowDefaults.minWidth,
    this.maxWidth = double.infinity,
    this.height = SoftTabRowDefaults.height,
    this.cornerRadius = SoftTabRowDefaults.contourCornerRadius,
    this.contourPadding = SoftTabRowDefaults.contourPadding,
    this.segmentPadding = SoftTabRowDefaults.segmentPadding,
    this.itemSpacing = 0,
    this.alignment = Alignment.center,
  }) : _container = true;

  final List<String> tabs;
  final int selectedIndex;
  final ValueChanged<int> onTabSelected;

  /// [SoftTabRowColors.of] by default.
  final SoftTabRowColors? colors;
  final double minWidth;
  final double maxWidth;
  final double height;

  /// The indicator's corner radius.
  final double cornerRadius;

  /// The inset between the container and the indicator.
  final double contourPadding;

  /// The horizontal padding around each label.
  final double segmentPadding;
  final double itemSpacing;

  /// Where a label sits in its segment.
  final AlignmentGeometry alignment;

  final bool _container;

  @override
  State<SoftTabRow> createState() => _SoftTabRowState();
}

class _SoftTabRowState extends State<SoftTabRow> with TickerProviderStateMixin {
  late final SoftSpring _centre = SoftSpring(vsync: this);
  late final SoftSpring _width = SoftSpring(vsync: this);
  late final SoftSpring _scale = SoftSpring(vsync: this, value: 1);
  final ScrollController _scroll = ScrollController();
  late final Listenable _repaint = Listenable.merge(<Listenable>[
    _centre,
    _width,
    _scale,
    _scroll,
  ]);

  List<double> _widths = const <double>[];
  List<double> _lefts = const <double>[];
  int _settledIndex = -1;
  bool _selectedPressed = false;

  /// The inputs of the last width computation.
  Object? _measureKey;

  @override
  void dispose() {
    _centre.dispose();
    _width.dispose();
    _scale.dispose();
    _scroll.dispose();
    super.dispose();
  }

  int get _index =>
      _widths.isEmpty ? 0 : widget.selectedIndex.clamp(0, _widths.length - 1);

  void _measure(double viewport, TextScaler scaler, TextStyle style) {
    final Object key = Object.hashAll(<Object>[
      ...widget.tabs,
      viewport,
      scaler,
      style,
      widget.minWidth,
      widget.maxWidth,
      widget.itemSpacing,
      widget.segmentPadding,
    ]);
    if (key == _measureKey) return;
    _measureKey = key;
    final List<double> natural = <double>[
      for (final String label in widget.tabs)
        math.max(
          _labelWidth(label, style, scaler) + 2 * widget.segmentPadding,
          widget.minWidth,
        ),
    ];
    final double available =
        viewport - widget.itemSpacing * math.max(0, widget.tabs.length - 1);
    _widths = SoftTabRowDefaults.segmentWidths(
      natural,
      available,
      widget.minWidth,
      widget.maxWidth,
    );
    final List<double> lefts = <double>[];
    double left = 0;
    for (final double w in _widths) {
      lefts.add(left);
      left += w + widget.itemSpacing;
    }
    _lefts = lefts;
  }

  static double _labelWidth(String label, TextStyle style, TextScaler scaler) {
    final TextPainter painter = TextPainter(
      text: TextSpan(text: label, style: style),
      maxLines: 1,
      textScaler: scaler,
      textDirection: TextDirection.ltr,
    )..layout();
    final double w = painter.width.ceilToDouble();
    painter.dispose();
    return w;
  }

  /// Points the indicator at the selection: a jump on the first layout or a
  /// re-layout, the two springs on a selection change.
  void _sync(double viewport) {
    if (_widths.isEmpty) return;
    final int index = _index;
    final double targetWidth = _widths[index];
    final double targetCentre = _lefts[index] + targetWidth / 2;
    final bool animate =
        _settledIndex >= 0 &&
        _settledIndex != widget.selectedIndex &&
        !softReduceMotion(context);
    if (!animate) {
      if (_centre.value != targetCentre || _width.value != targetWidth) {
        _centre.snapTo(targetCentre);
        _width.snapTo(targetWidth);
      }
    } else {
      final double current = _width.value;
      final double delta = (current - targetWidth).abs();
      final double larger = math.max(current, targetWidth);
      final double ratio = larger > 0 ? (delta / larger).clamp(0.0, 1.0) : 0;
      final double widthBounce = 0.5 - 0.4 * ratio * ratio;
      final double widthResponse = 0.6 - 0.2 * ratio * ratio;
      final double positionBounce = targetWidth > current && larger > 0
          ? 0.1 - 0.07 * delta / larger
          : 0.1;
      final double dpr = MediaQuery.devicePixelRatioOf(context);
      _centre.animateTo(
        targetCentre,
        softSpring(damping: 1 - positionBounce, response: 0.4),
        threshold: 0.05,
      );
      _width.animateTo(
        targetWidth,
        softSpring(damping: 1 - widthBounce, response: widthResponse),
        velocity: SoftTabRowDefaults.widthInitialVelocityPx / dpr,
        threshold: 0.05,
      );
    }
    _scrollIntoView(index, viewport, animate: animate);
    _settledIndex = widget.selectedIndex;
  }

  void _scrollIntoView(int index, double viewport, {required bool animate}) {
    if (!_scroll.hasClients) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _scroll.hasClients) {
          _scrollIntoView(index, viewport, animate: false);
        }
      });
      return;
    }
    final ScrollPosition position = _scroll.position;
    if (!position.hasContentDimensions || position.maxScrollExtent <= 0) {
      return;
    }
    final double target = (_lefts[index] - (viewport - _widths[index]) / 2)
        .clamp(position.minScrollExtent, position.maxScrollExtent);
    if (target == position.pixels) return;
    if (animate) {
      position.animateTo(
        target,
        duration: const Duration(milliseconds: 300),
        curve: SoftMotion.inEase,
      );
    } else {
      position.jumpTo(target);
    }
  }

  void _onSelectedPressed(bool pressed) {
    if (_selectedPressed == pressed) return;
    _selectedPressed = pressed;
    double target = 1;
    if (pressed && _widths.isNotEmpty) {
      target = SoftTabRowDefaults.pressedScale(
        _widths[_index],
        widget.height - 2 * widget.contourPadding,
      );
    }
    _scale.animateTo(target, SoftTabRowDefaults.pressSpring);
  }

  @override
  Widget build(BuildContext context) {
    final SoftThemeData theme = SoftTheme.of(context);
    final SoftTabRowColors colors =
        widget.colors ??
        SoftTabRowColors.of(context, container: widget._container);
    final TextScaler scaler = MediaQuery.textScalerOf(context);
    final TextStyle base = theme.textStyles.body2;
    final TextStyle measureStyle = base.copyWith(fontWeight: FontWeight.w500);
    return SizedBox(
      height: widget.height,
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final double pad = widget.contourPadding;
          final bool bounded = constraints.hasBoundedWidth;
          _measure(
            bounded ? constraints.maxWidth - 2 * pad : double.infinity,
            scaler,
            measureStyle,
          );
          final double content = _widths.isEmpty
              ? 0
              : _lefts.last + _widths.last;
          final double viewport = bounded
              ? constraints.maxWidth - 2 * pad
              : content;
          final bool scrolls = content > viewport + 0.5;
          _sync(viewport);
          return CustomPaint(
            painter: _IndicatorPainter(
              repaint: _repaint,
              state: this,
              colors: colors,
              cornerRadius: widget.cornerRadius,
              contourPadding: pad,
              rtl: Directionality.of(context) == TextDirection.rtl,
            ),
            child: SizedBox(
              width: bounded ? constraints.maxWidth : content + 2 * pad,
              child: Padding(
                padding: EdgeInsets.all(pad),
                child: ListView.builder(
                  controller: _scroll,
                  scrollDirection: Axis.horizontal,
                  physics: scrolls
                      ? const ClampingScrollPhysics()
                      : const NeverScrollableScrollPhysics(),
                  padding: EdgeInsets.zero,
                  itemCount: widget.tabs.length,
                  itemBuilder: (BuildContext context, int index) {
                    final bool last = index == widget.tabs.length - 1;
                    return Padding(
                      padding: EdgeInsetsDirectional.only(
                        end: last ? 0 : widget.itemSpacing,
                      ),
                      child: _Segment(
                        label: widget.tabs[index],
                        width: _widths[index],
                        selected: index == widget.selectedIndex,
                        color: index == widget.selectedIndex
                            ? colors.selectedContent
                            : colors.content,
                        style: base,
                        padding: widget.segmentPadding,
                        alignment: widget.alignment,
                        height: widget.height - 2 * pad,
                        onTap: () => widget.onTabSelected(index),
                        onSelectedPressed: _onSelectedPressed,
                      ),
                    );
                  },
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _Segment extends StatefulWidget {
  const _Segment({
    required this.label,
    required this.width,
    required this.selected,
    required this.color,
    required this.style,
    required this.padding,
    required this.alignment,
    required this.height,
    required this.onTap,
    required this.onSelectedPressed,
  });

  final String label;
  final double width;
  final bool selected;
  final Color color;
  final TextStyle style;
  final double padding;
  final AlignmentGeometry alignment;
  final double height;
  final VoidCallback onTap;
  final ValueChanged<bool> onSelectedPressed;

  @override
  State<_Segment> createState() => _SegmentState();
}

class _SegmentState extends State<_Segment> with TickerProviderStateMixin {
  late final SoftSpring _press = SoftSpring(vsync: this);
  late final AnimationController _colour = AnimationController(
    vsync: this,
    duration: SoftTabRowDefaults.textColorDuration,
    value: 1,
  );
  late Color _from = widget.color;
  bool _pressed = false;

  @override
  void didUpdateWidget(_Segment oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.color != widget.color) {
      _from = Color.lerp(
        _from,
        oldWidget.color,
        SoftTabRowDefaults.textColorCurve.transform(_colour.value),
      )!;
      if (softReduceMotion(context)) {
        _colour.value = 1;
      } else {
        _colour.forward(from: 0);
      }
    }
    if (oldWidget.selected != widget.selected && _pressed) {
      widget.onSelectedPressed(widget.selected);
    }
  }

  @override
  void dispose() {
    _press.dispose();
    _colour.dispose();
    super.dispose();
  }

  void _onPressed(bool pressed) {
    _pressed = pressed;
    _press.animateTo(pressed ? 1 : 0, SoftTabRowDefaults.pressSpring);
    if (widget.selected) widget.onSelectedPressed(pressed);
  }

  @override
  Widget build(BuildContext context) {
    final Widget label = AnimatedBuilder(
      animation: _colour,
      builder: (BuildContext context, Widget? _) {
        final double t = SoftTabRowDefaults.textColorCurve.transform(
          _colour.value,
        );
        return Text(
          widget.label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: widget.style.copyWith(
            color: Color.lerp(_from, widget.color, t),
            fontWeight: widget.selected ? FontWeight.w500 : FontWeight.w400,
          ),
        );
      },
    );
    return Semantics(
      selected: widget.selected,
      inMutuallyExclusiveGroup: true,
      child: SoftPressable(
        feedback: SoftPressFeedback.none,
        onTap: widget.onTap,
        onPressedChanged: _onPressed,
        child: SizedBox(
          width: widget.width,
          child: AnimatedBuilder(
            animation: _press,
            builder: (BuildContext context, Widget? child) {
              final double end = SoftTabRowDefaults.pressedScale(
                widget.width,
                widget.height,
              );
              return Transform.scale(
                scale: 1 - (1 - end) * _press.value,
                child: child,
              );
            },
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: widget.padding),
              child: Align(alignment: widget.alignment, child: label),
            ),
          ),
        ),
      ),
    );
  }
}

class _IndicatorPainter extends CustomPainter {
  _IndicatorPainter({
    required Listenable repaint,
    required this.state,
    required this.colors,
    required this.cornerRadius,
    required this.contourPadding,
    required this.rtl,
  }) : super(repaint: repaint);

  final _SoftTabRowState state;
  final SoftTabRowColors colors;
  final double cornerRadius;
  final double contourPadding;
  final bool rtl;

  @override
  void paint(Canvas canvas, Size size) {
    final double containerRadius = math.min(
      cornerRadius + contourPadding,
      size.height / 2,
    );
    final RRect container = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(containerRadius),
    );
    if (colors.container.a > 0) {
      canvas.drawRRect(container, Paint()..color = colors.container);
    }
    if (state._widths.isEmpty) return;
    final double pad = contourPadding;
    final double scale = state._scale.value;
    final double w = state._width.value * scale;
    final double h = (size.height - 2 * pad) * scale;
    if (w <= 0 || h <= 0) return;
    final double scroll = state._scroll.hasClients
        ? state._scroll.position.pixels
        : 0;
    final double inner = size.width - 2 * pad;
    double cx = state._centre.value - scroll;
    if (rtl) cx = inner - cx;
    cx += pad;
    final double cy = size.height / 2;
    final Rect rect = Rect.fromCenter(
      center: Offset(cx, cy),
      width: w,
      height: h,
    );
    final double r = math.min(cornerRadius, h / 2);
    final RRect indicator = RRect.fromRectAndRadius(rect, Radius.circular(r));
    canvas
      ..save()
      ..clipRRect(container);
    final Color shadow = colors.indicatorShadow;
    if (shadow.a > 0) {
      // The shadow only shows outside the translucent indicator.
      final Path outside = Path()
        ..fillType = PathFillType.evenOdd
        ..addRect(Offset.zero & size)
        ..addRRect(indicator);
      const double dy = SoftTabRowDefaults.shadowOffsetY;
      const double blur = SoftTabRowDefaults.shadowBlurRadius;
      canvas
        ..save()
        ..clipPath(outside)
        ..drawRRect(
          RRect.fromRectAndRadius(
            rect.shift(const Offset(0, dy)).inflate(blur),
            Radius.circular(r + blur),
          ),
          Paint()..color = shadow.withValues(alpha: shadow.a * 0.5),
        )
        ..drawRRect(
          indicator.shift(const Offset(0, dy)),
          Paint()..color = shadow,
        )
        ..restore();
    }
    canvas
      ..drawRRect(indicator, Paint()..color = colors.indicator)
      ..restore();
  }

  @override
  bool shouldRepaint(_IndicatorPainter old) =>
      old.colors != colors ||
      old.cornerRadius != cornerRadius ||
      old.contourPadding != contourPadding ||
      old.rtl != rtl ||
      !identical(old.state, state);
}
