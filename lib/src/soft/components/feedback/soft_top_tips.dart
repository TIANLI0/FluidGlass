import 'dart:async';

import 'package:flutter/widgets.dart';

import '../../foundation/soft_colors.dart';
import '../../foundation/soft_motion.dart';
import '../../foundation/soft_pressable.dart';
import '../../foundation/soft_squircle.dart';
import '../../foundation/soft_theme.dart';
import 'soft_text_action.dart';

/// The solid fill of a [SoftTopTips].
enum SoftTopTipsBackground {
  /// The card colour: white, or white at 10 % in the dark.
  white,

  /// Black at 4 %, or white at 10 % in the dark.
  gray,
}

/// The top tips defaults.
abstract final class SoftTopTipsDefaults {
  /// The corners of a titled or wrapped banner.
  static const double cornerRadius = 28;

  /// The corners of an untitled banner that fits one line: a capsule.
  static const double singleLineCornerRadius = 72;

  /// The padding above and below the text.
  static const double contentPadding = 12;

  /// The leading icon without a title, and the close button.
  static const double iconSize = 24;

  /// The leading icon next to a title.
  static const double titleIconSize = 36;

  /// The gap after an untitled icon.
  static const double iconSpacing = 8;

  /// The gap after a titled icon.
  static const double titleIconSpacing = 12;

  /// The inset of the icon from the start.
  static const double iconStartMargin = 16;

  /// The inset of the text (without an icon) and of the trailing buttons.
  static const double contentEndMargin = 16;
  static const double textMinHeight = 20;
  static const double titleMinHeight = 22;

  /// The gap between the text and each button.
  static const double textToButtonGap = 8;

  /// Above the wrapped button row.
  static const double buttonTopMargin = 8;

  /// Below the wrapped button row.
  static const double wrappedButtonBottomMargin = 12;

  /// The press padding of a text button.
  static const double actionPaddingHorizontal = 12;
  static const double actionPaddingVertical = 4;

  /// Showing and hiding: a 250 ms vertical scale, ease in and out.
  static const Duration showDuration = Duration(milliseconds: 250);
  static const Cubic showCurve = Cubic(0.42, 0, 0.58, 1);

  /// The close disc: black at 16 %, or white at 25 % in the dark.
  static const Color closeLight = Color(0x29000000);
  static const Color closeDark = Color(0x40FFFFFF);

  /// The marquee: 25 per second, starting 10 in, 80 between passes, 26
  /// fades at the clipped edges, 1 s before it starts.
  static const double marqueeSpeed = 25;
  static const double marqueeStart = 10;
  static const double marqueeInterval = 80;
  static const double marqueeFade = 26;
  static const Duration marqueeDelay = Duration(milliseconds: 1000);

  /// The fill of [background] in light or dark.
  static Color containerColor(SoftTopTipsBackground background, bool dark) {
    if (dark) return const Color(0x1AFFFFFF);
    return switch (background) {
      SoftTopTipsBackground.white => const Color(0xFFFFFFFF),
      SoftTopTipsBackground.gray => const Color(0x0A000000),
    };
  }

  /// The title: 16 medium.
  static TextStyle titleStyle(SoftThemeData theme) =>
      theme.textStyles.headline1.copyWith(fontWeight: FontWeight.w500);

  /// The message: 13.
  static TextStyle textStyle(SoftThemeData theme) => theme.textStyles.footnote1;

  /// The button labels: 13 medium.
  static TextStyle actionStyle(SoftThemeData theme) =>
      theme.textStyles.footnote1.copyWith(fontWeight: FontWeight.w500);
}

/// A tip banner for the top of a page: an optional icon, an optional title
/// over a one-line message, and trailing ignore / action text buttons and a
/// close button.
///
/// When the text and the buttons do not fit one row the buttons drop to
/// their own end-aligned row. An untitled one-row banner is a capsule;
/// otherwise the corners are 28. A message too long for its row scrolls
/// sideways (a marquee) unless [marqueeEnabled] is false or the platform
/// asks for reduced motion. Changing [visible] scales the banner vertically
/// over 250 ms.
class SoftTopTips extends StatefulWidget {
  const SoftTopTips({
    super.key,
    this.text = '',
    this.visible = true,
    this.title,
    this.startIcon,
    this.actionText,
    this.onAction,
    this.ignoreText,
    this.onIgnore,
    this.onClose,
    this.closeSemanticLabel,
    this.marqueeEnabled = true,
    this.background = SoftTopTipsBackground.gray,
    this.cornerRadius,
    this.containerColor,
    this.contentColor,
    this.actionColor,
    this.titleColor,
    this.closeButtonColor,
    this.closeIconColor = const Color(0xFFFFFFFF),
    this.content,
  });

  /// The message; ignored when [content] is set.
  final String text;
  final bool visible;
  final String? title;

  /// Laid out 24 square, or 36 next to a title.
  final Widget? startIcon;

  /// The primary text button.
  final String? actionText;
  final VoidCallback? onAction;

  /// The secondary text button, before the action.
  final String? ignoreText;
  final VoidCallback? onIgnore;

  /// Shows the close button.
  final VoidCallback? onClose;
  final String? closeSemanticLabel;
  final bool marqueeEnabled;
  final SoftTopTipsBackground background;

  /// Overrides the automatic 72 / 28 corners.
  final double? cornerRadius;
  final Color? containerColor;

  /// `onSurfaceSecondary` by default.
  final Color? contentColor;

  /// `primary` by default.
  final Color? actionColor;

  /// `onSurface` by default.
  final Color? titleColor;
  final Color? closeButtonColor;
  final Color closeIconColor;

  /// Replaces the message; it is not measured for the row decision and never
  /// scrolls.
  final Widget? content;

  @override
  State<SoftTopTips> createState() => _SoftTopTipsState();
}

class _SoftTopTipsState extends State<SoftTopTips>
    with SingleTickerProviderStateMixin {
  late final AnimationController _visibility = AnimationController(
    vsync: this,
    duration: SoftTopTipsDefaults.showDuration,
    value: widget.visible ? 1 : 0,
  )..addStatusListener(_statusChanged);

  @override
  void didUpdateWidget(SoftTopTips oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.visible != widget.visible) {
      if (widget.visible) {
        _visibility.animateTo(1, curve: SoftTopTipsDefaults.showCurve);
      } else {
        // animateBack, not animateTo: only a reverse run ends dismissed,
        // which is what takes the banner out of the tree.
        _visibility.animateBack(0, curve: SoftTopTipsDefaults.showCurve);
      }
    }
  }

  void _statusChanged(AnimationStatus status) {
    if (status == AnimationStatus.dismissed && mounted) setState(() {});
  }

  @override
  void dispose() {
    _visibility.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.visible && _visibility.value == 0) {
      return const SizedBox.shrink();
    }
    return AnimatedBuilder(
      animation: _visibility,
      builder: (BuildContext context, Widget? child) => Transform(
        alignment: Alignment.center,
        transform: Matrix4.diagonal3Values(1, _visibility.value, 1),
        child: child,
      ),
      child: _TopTipsBody(tips: widget),
    );
  }
}

double _labelWidth(String text, TextStyle style, TextScaler scaler) {
  final TextPainter painter = TextPainter(
    text: TextSpan(text: text, style: style),
    textScaler: scaler,
    textDirection: TextDirection.ltr,
    maxLines: 1,
  )..layout();
  final double width = painter.width;
  painter.dispose();
  return width;
}

class _TopTipsBody extends StatelessWidget {
  const _TopTipsBody({required this.tips});

  final SoftTopTips tips;

  @override
  Widget build(BuildContext context) {
    final SoftThemeData theme = SoftTheme.of(context);
    final SoftColors colors = theme.colors;
    final TextScaler scaler = MediaQuery.textScalerOf(context);
    final String? title = (tips.title?.isEmpty ?? true) ? null : tips.title;
    final String? action = (tips.actionText?.isEmpty ?? true)
        ? null
        : tips.actionText;
    final String? ignore = (tips.ignoreText?.isEmpty ?? true)
        ? null
        : tips.ignoreText;
    final TextStyle titleStyle = SoftTopTipsDefaults.titleStyle(theme);
    final TextStyle textStyle = SoftTopTipsDefaults.textStyle(theme);
    final TextStyle actionStyle = SoftTopTipsDefaults.actionStyle(
      theme,
    ).copyWith(color: tips.actionColor ?? colors.primary);
    final Color container =
        tips.containerColor ??
        SoftTopTipsDefaults.containerColor(tips.background, colors.isDark);

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        // The row decision: text, icon and buttons measured on one line.
        final double titleWidth = title == null
            ? 0
            : _labelWidth(title, titleStyle, scaler);
        final double textWidth = tips.content == null
            ? _labelWidth(tips.text, textStyle, scaler)
            : 0;
        final double leading = tips.startIcon == null
            ? SoftTopTipsDefaults.contentEndMargin
            : SoftTopTipsDefaults.iconStartMargin +
                  (title == null
                      ? SoftTopTipsDefaults.iconSize +
                            SoftTopTipsDefaults.iconSpacing
                      : SoftTopTipsDefaults.titleIconSize +
                            SoftTopTipsDefaults.titleIconSpacing);
        const double gap = SoftTopTipsDefaults.textToButtonGap;
        const double labelPadding =
            SoftTopTipsDefaults.actionPaddingHorizontal * 2;
        double trailing = 0;
        if (ignore != null) {
          trailing +=
              _labelWidth(ignore, actionStyle, scaler) + labelPadding + gap;
        }
        if (action != null) {
          trailing +=
              _labelWidth(action, actionStyle, scaler) + labelPadding + gap;
        }
        if (tips.onClose != null) {
          trailing += SoftTopTipsDefaults.iconSize + gap;
        }
        final double textMax = titleWidth > textWidth ? titleWidth : textWidth;
        final bool wrapped =
            leading + textMax + trailing > constraints.maxWidth;
        final double radius =
            tips.cornerRadius ??
            (title == null && !wrapped
                ? SoftTopTipsDefaults.singleLineCornerRadius
                : SoftTopTipsDefaults.cornerRadius);

        final List<Widget> textArea = _textArea(
          context,
          title,
          titleStyle.copyWith(color: tips.titleColor ?? colors.onSurface),
          textStyle.copyWith(
            color: tips.contentColor ?? colors.onSurfaceSecondary,
          ),
        );
        final Widget buttons = _trailing(
          action,
          ignore,
          actionStyle,
          colors,
          wrapped: wrapped,
        );
        final Widget body = wrapped
            ? Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Row(children: textArea),
                  Padding(
                    padding: const EdgeInsetsDirectional.only(
                      top: SoftTopTipsDefaults.buttonTopMargin,
                      end: SoftTopTipsDefaults.contentEndMargin,
                      bottom: SoftTopTipsDefaults.wrappedButtonBottomMargin,
                    ),
                    child: buttons,
                  ),
                ],
              )
            : Row(
                children: <Widget>[
                  ...textArea,
                  Padding(
                    padding: const EdgeInsetsDirectional.only(
                      end: SoftTopTipsDefaults.contentEndMargin,
                    ),
                    child: buttons,
                  ),
                ],
              );
        return DecoratedBox(
          decoration: ShapeDecoration(
            color: container,
            shape: SoftSquircleBorder.all(radius, smooth: theme.smoothCorners),
          ),
          child: body,
        );
      },
    );
  }

  List<Widget> _textArea(
    BuildContext context,
    String? title,
    TextStyle titleStyle,
    TextStyle textStyle,
  ) {
    final Widget? icon = tips.startIcon;
    final double start = icon == null
        ? SoftTopTipsDefaults.contentEndMargin
        : title == null
        ? SoftTopTipsDefaults.iconSpacing
        : SoftTopTipsDefaults.titleIconSpacing;
    return <Widget>[
      if (icon != null)
        Padding(
          padding: const EdgeInsetsDirectional.only(
            start: SoftTopTipsDefaults.iconStartMargin,
          ),
          child: SizedBox.square(
            dimension: title == null
                ? SoftTopTipsDefaults.iconSize
                : SoftTopTipsDefaults.titleIconSize,
            child: Center(child: icon),
          ),
        ),
      Expanded(
        child: Padding(
          padding: EdgeInsetsDirectional.only(
            start: start,
            top: SoftTopTipsDefaults.contentPadding,
            bottom: SoftTopTipsDefaults.contentPadding,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              if (title != null)
                ConstrainedBox(
                  constraints: const BoxConstraints(
                    minHeight: SoftTopTipsDefaults.titleMinHeight,
                  ),
                  child: Text(
                    title,
                    style: titleStyle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ConstrainedBox(
                constraints: const BoxConstraints(
                  minHeight: SoftTopTipsDefaults.textMinHeight,
                ),
                child:
                    tips.content ??
                    _MarqueeText(
                      text: tips.text,
                      style: textStyle,
                      enabled: tips.marqueeEnabled,
                    ),
              ),
            ],
          ),
        ),
      ),
    ];
  }

  Widget _trailing(
    String? action,
    String? ignore,
    TextStyle actionStyle,
    SoftColors colors, {
    required bool wrapped,
  }) {
    const Widget gap = SizedBox(width: SoftTopTipsDefaults.textToButtonGap);
    return Row(
      mainAxisSize: wrapped ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.end,
      children: <Widget>[
        if (ignore != null) ...<Widget>[
          SoftTextAction(
            label: ignore,
            style: actionStyle,
            onTap: tips.onIgnore,
          ),
          gap,
        ],
        if (action != null) ...<Widget>[
          SoftTextAction(
            label: action,
            style: actionStyle,
            onTap: tips.onAction,
          ),
          gap,
        ],
        if (tips.onClose != null)
          Semantics(
            label: tips.closeSemanticLabel,
            child: SoftPressable(
              onTap: tips.onClose,
              borderRadius: BorderRadius.circular(
                SoftTopTipsDefaults.iconSize / 2,
              ),
              child: CustomPaint(
                size: const Size.square(SoftTopTipsDefaults.iconSize),
                painter: _CloseGlyphPainter(
                  disc:
                      tips.closeButtonColor ??
                      (colors.isDark
                          ? SoftTopTipsDefaults.closeDark
                          : SoftTopTipsDefaults.closeLight),
                  cross: tips.closeIconColor,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// The close glyph: a 9 disc with a 1.6 round-capped cross reaching 2.736
/// from the centre.
class _CloseGlyphPainter extends CustomPainter {
  const _CloseGlyphPainter({required this.disc, required this.cross});

  final Color disc;
  final Color cross;

  @override
  void paint(Canvas canvas, Size size) {
    final Offset c = size.center(Offset.zero);
    canvas.drawCircle(c, 9, Paint()..color = disc);
    const double arm = 2.736;
    final Paint line = Paint()
      ..color = cross
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(c.translate(-arm, -arm), c.translate(arm, arm), line);
    canvas.drawLine(c.translate(-arm, arm), c.translate(arm, -arm), line);
  }

  @override
  bool shouldRepaint(_CloseGlyphPainter old) =>
      old.disc != disc || old.cross != cross;
}

/// One line of text that, when wider than its box, scrolls left at 25 per
/// second after a 1 s pause, looping with 80 between passes and fading the
/// clipped edges.
class _MarqueeText extends StatefulWidget {
  const _MarqueeText({
    required this.text,
    required this.style,
    required this.enabled,
  });

  final String text;
  final TextStyle style;
  final bool enabled;

  @override
  State<_MarqueeText> createState() => _MarqueeTextState();
}

class _MarqueeTextState extends State<_MarqueeText>
    with SingleTickerProviderStateMixin {
  late final AnimationController _scroll = AnimationController(vsync: this);
  TextPainter? _painter;
  Timer? _delay;
  Duration? _period;

  @override
  void dispose() {
    _delay?.cancel();
    _scroll.dispose();
    _painter?.dispose();
    super.dispose();
  }

  TextPainter _layout(TextScaler scaler, TextDirection direction) {
    final TextPainter? cached = _painter;
    if (cached != null &&
        cached.text == TextSpan(text: widget.text, style: widget.style) &&
        cached.textScaler == scaler &&
        cached.textDirection == direction) {
      return cached;
    }
    cached?.dispose();
    return _painter = TextPainter(
      text: TextSpan(text: widget.text, style: widget.style),
      textScaler: scaler,
      textDirection: direction,
      maxLines: 1,
    )..layout();
  }

  void _run(Duration period) {
    if (_period == period) return;
    _period = period;
    _delay?.cancel();
    _scroll
      ..stop()
      ..value = 0;
    _delay = Timer(SoftTopTipsDefaults.marqueeDelay, () {
      if (!mounted) return;
      _scroll.repeat(period: period);
    });
  }

  void _halt() {
    if (_period == null) return;
    _period = null;
    _delay?.cancel();
    _scroll
      ..stop()
      ..value = 0;
  }

  @override
  Widget build(BuildContext context) {
    final TextScaler scaler = MediaQuery.textScalerOf(context);
    final TextDirection direction = Directionality.of(context);
    final bool motion = widget.enabled && !softReduceMotion(context);
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final TextPainter painter = _layout(scaler, direction);
        if (!motion || painter.width <= constraints.maxWidth) {
          _halt();
          return Text(
            widget.text,
            style: widget.style,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          );
        }
        final double distance =
            painter.width + SoftTopTipsDefaults.marqueeInterval;
        final int millis = (distance / SoftTopTipsDefaults.marqueeSpeed * 1000)
            .round()
            .clamp(1, 1 << 30);
        _run(Duration(milliseconds: millis));
        return Semantics(
          label: widget.text,
          child: RepaintBoundary(
            child: CustomPaint(
              size: Size(constraints.maxWidth, painter.height),
              painter: _MarqueePainter(
                painter: painter,
                progress: _scroll,
                distance: distance,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _MarqueePainter extends CustomPainter {
  _MarqueePainter({
    required this.painter,
    required this.progress,
    required this.distance,
  }) : super(repaint: progress);

  final TextPainter painter;
  final Animation<double> progress;
  final double distance;

  @override
  void paint(Canvas canvas, Size size) {
    final Rect bounds = Offset.zero & size;
    final double offset =
        SoftTopTipsDefaults.marqueeStart - progress.value * distance;
    final double fade = SoftTopTipsDefaults.marqueeFade < size.width / 2
        ? SoftTopTipsDefaults.marqueeFade
        : size.width / 2;
    // The fades erase what is under them, so the line gets a layer of its
    // own (one text line high).
    canvas.saveLayer(bounds, Paint());
    canvas.clipRect(bounds);
    painter.paint(canvas, Offset(offset, 0));
    painter.paint(canvas, Offset(offset + distance, 0));
    if (fade > 0) {
      final Paint erase = Paint()..blendMode = BlendMode.dstOut;
      if (offset < 0) {
        canvas.drawRect(
          Rect.fromLTWH(0, 0, fade, size.height),
          erase
            ..shader = const LinearGradient(
              colors: <Color>[Color(0xFFFFFFFF), Color(0x00FFFFFF)],
            ).createShader(Rect.fromLTWH(0, 0, fade, size.height)),
        );
      }
      final Rect right = Rect.fromLTWH(size.width - fade, 0, fade, size.height);
      canvas.drawRect(
        right,
        erase
          ..shader = const LinearGradient(
            colors: <Color>[Color(0x00FFFFFF), Color(0xFFFFFFFF)],
          ).createShader(right),
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_MarqueePainter old) =>
      old.painter != painter ||
      old.progress != progress ||
      old.distance != distance;
}
