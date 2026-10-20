import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'soft_motion.dart';
import 'soft_theme.dart';

/// Shows a snackbar at the bottom of the screen: a raised pill (16-radius
/// card once it wraps) with 14 medium text and an optional accent action.
///
/// It springs in from 0.8 scale and transparent, and springs back out the same
/// way. Without [duration] it stays until the action is tapped or the returned
/// handle is closed.
SoftSnackBarHandle showSoftSnackBar(
  BuildContext context, {
  required String message,
  String? actionLabel,
  VoidCallback? onAction,
  Widget? icon,
  Duration? duration = const Duration(milliseconds: 3000),
}) {
  final OverlayState overlay = Overlay.of(context, rootOverlay: true);
  final SoftThemeData theme = SoftTheme.of(context);
  late final OverlayEntry entry;
  final GlobalKey<_SnackBarState> key = GlobalKey<_SnackBarState>();
  final SoftSnackBarHandle handle = SoftSnackBarHandle._(() async {
    await key.currentState?._hide();
    if (entry.mounted) entry.remove();
  });
  entry = OverlayEntry(
    builder: (BuildContext context) => SoftTheme(
      data: theme,
      child: _SnackBar(
        key: key,
        message: message,
        actionLabel: actionLabel,
        icon: icon,
        onAction: () {
          onAction?.call();
          handle.close();
        },
      ),
    ),
  );
  overlay.insert(entry);
  if (duration != null) {
    Timer(duration, handle.close);
  }
  return handle;
}

/// Closes a snackbar shown by [showSoftSnackBar].
class SoftSnackBarHandle {
  SoftSnackBarHandle._(this._close);

  final Future<void> Function() _close;
  bool _closed = false;

  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    await _close();
  }
}

class _SnackBar extends StatefulWidget {
  const _SnackBar({
    super.key,
    required this.message,
    this.actionLabel,
    this.icon,
    required this.onAction,
  });

  final String message;
  final String? actionLabel;
  final Widget? icon;
  final VoidCallback onAction;

  @override
  State<_SnackBar> createState() => _SnackBarState();
}

class _SnackBarState extends State<_SnackBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _progress = AnimationController.unbounded(
    vsync: this,
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _progress.springTo(
          1,
          softSpring(0.3),
          reduceMotion: softReduceMotion(context),
        );
      }
    });
  }

  Future<void> _hide() async {
    if (!mounted) return;
    await _progress.springTo(
      0,
      softSpring(0.25),
      reduceMotion: softReduceMotion(context),
    );
  }

  @override
  void dispose() {
    _progress.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final SoftThemeData theme = SoftTheme.of(context);
    final MediaQueryData media = MediaQuery.of(context);
    final double height = media.size.height;
    final double bottom = height < 280
        ? 32
        : height < 480
        ? 64
        : 88;
    final TextStyle textStyle = theme.text(
      14,
      weight: FontWeight.w500,
      height: 1.3,
    );
    final double maxWidth = math.min(368, media.size.width - 32);
    return Positioned(
      left: 0,
      right: 0,
      bottom: bottom + media.viewPadding.bottom,
      child: Center(
        child: AnimatedBuilder(
          animation: _progress,
          builder: (BuildContext context, Widget? child) {
            final double p = _progress.value.clamp(0.0, 1.0);
            return Opacity(
              opacity: p,
              child: Transform.scale(scale: 0.8 + 0.2 * p, child: child),
            );
          },
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: LayoutBuilder(
              builder: (BuildContext context, BoxConstraints c) {
                final TextPainter painter =
                    TextPainter(
                      text: TextSpan(text: widget.message, style: textStyle),
                      textDirection: Directionality.of(context),
                      textScaler: MediaQuery.textScalerOf(context),
                    )..layout(
                      maxWidth:
                          c.maxWidth -
                          32 -
                          (widget.actionLabel == null ? 0 : 80),
                    );
                final bool multiLine = painter.computeLineMetrics().length > 1;
                painter.dispose();
                return Material(
                  type: MaterialType.transparency,
                  child: Container(
                    decoration: ShapeDecoration(
                      color: theme.backgroundElevated,
                      shape: multiLine
                          ? RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            )
                          : const StadiumBorder(),
                      shadows: <BoxShadow>[
                        BoxShadow(
                          color: Colors.black.withValues(
                            alpha: theme.isDark ? 0.47 : 0.16,
                          ),
                          blurRadius: 28,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    padding: EdgeInsets.fromLTRB(
                      16,
                      multiLine ? 12 : 10,
                      widget.actionLabel == null ? 16 : 4,
                      multiLine ? 12 : 10,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        if (widget.icon != null) ...<Widget>[
                          SizedBox.square(dimension: 30, child: widget.icon),
                          const SizedBox(width: 16),
                        ],
                        Flexible(child: Text(widget.message, style: textStyle)),
                        if (widget.actionLabel != null)
                          GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: widget.onAction,
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(
                                  maxWidth: 110,
                                ),
                                child: Text(
                                  widget.actionLabel!,
                                  maxLines: 2,
                                  style: theme.text(
                                    14,
                                    weight: FontWeight.w500,
                                    color: theme.accentText,
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

/// An inline notice at the top of a page: an optional icon, an optional
/// title, the content, an optional action and close button, on a faint fill.
///
/// A pill while it fits on one line, a 28-radius card once it wraps.
class SoftTopTips extends StatelessWidget {
  const SoftTopTips({
    super.key,
    required this.content,
    this.title,
    this.icon,
    this.actionLabel,
    this.onAction,
    this.onClose,
    this.white = false,
  });

  final String content;
  final String? title;
  final Widget? icon;
  final String? actionLabel;
  final VoidCallback? onAction;
  final VoidCallback? onClose;

  /// The card colour instead of the faint grey fill.
  final bool white;

  @override
  Widget build(BuildContext context) {
    final SoftThemeData theme = SoftTheme.of(context);
    final Color fill = white
        ? theme.card
        : (theme.isDark ? const Color(0x1AFFFFFF) : const Color(0x0A000000));
    final TextStyle contentStyle = theme.text(
      13,
      color: theme.labelSecondary,
      height: 1.35,
    );
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double reserved =
            16 +
            (icon == null ? 0 : 24 + 8) +
            16 +
            (onClose == null ? 0 : 24 + 16) +
            (actionLabel == null ? 0 : 72);
        final TextPainter painter = TextPainter(
          text: TextSpan(text: content, style: contentStyle),
          textDirection: Directionality.of(context),
          textScaler: MediaQuery.textScalerOf(context),
        )..layout(maxWidth: math.max(0, constraints.maxWidth - reserved));
        final bool single =
            title == null && painter.computeLineMetrics().length <= 1;
        painter.dispose();
        return AnimatedContainer(
          duration: SoftMotion.fadeDuration,
          curve: SoftCurves.ease,
          decoration: ShapeDecoration(
            color: fill,
            shape: single
                ? const StadiumBorder()
                : RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(28),
                  ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              if (icon != null)
                Padding(
                  padding: const EdgeInsetsDirectional.only(start: 16),
                  child: SizedBox.square(dimension: 24, child: icon),
                ),
              Expanded(
                child: Padding(
                  padding: EdgeInsetsDirectional.fromSTEB(
                    icon == null ? 16 : 8,
                    12,
                    16,
                    12,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      if (title != null)
                        Text(
                          title!,
                          maxLines: 2,
                          style: theme.text(16, weight: FontWeight.w500),
                        ),
                      Text(content, style: contentStyle),
                    ],
                  ),
                ),
              ),
              if (actionLabel != null)
                GestureDetector(
                  onTap: onAction,
                  child: Container(
                    height: 28,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    alignment: Alignment.center,
                    decoration: ShapeDecoration(
                      color: theme.accentTint,
                      shape: const StadiumBorder(),
                    ),
                    child: Text(
                      actionLabel!,
                      style: theme.text(
                        12,
                        weight: FontWeight.w500,
                        color: theme.accentText,
                      ),
                    ),
                  ),
                ),
              if (onClose != null)
                Padding(
                  padding: EdgeInsetsDirectional.only(
                    start: actionLabel == null ? 0 : 12,
                    end: 16,
                  ),
                  child: GestureDetector(
                    onTap: onClose,
                    child: Icon(
                      Icons.close_rounded,
                      size: 20,
                      color: theme.labelTertiary,
                    ),
                  ),
                ),
              if (onClose == null && actionLabel != null)
                const SizedBox(width: 12),
            ],
          ),
        );
      },
    );
  }
}

/// An empty page: an optional illustration, a title, a subtitle and an
/// optional accent text action, centred in a 280-wide column placed at 45% of
/// the free height (half way when the space is under 200 high).
class SoftEmptyState extends StatelessWidget {
  const SoftEmptyState({
    super.key,
    required this.title,
    this.subtitle,
    this.illustration,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String? subtitle;

  /// Drawn in a 120 × 100 box above the text (hidden in small spaces).
  final Widget? illustration;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final SoftThemeData theme = SoftTheme.of(context);
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool small =
            constraints.hasBoundedHeight && constraints.maxHeight < 200;
        final Widget group = SizedBox(
          width: 280,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (illustration != null && !small)
                SizedBox(width: 120, height: 100, child: illustration),
              Text(
                title,
                maxLines: 2,
                textAlign: TextAlign.center,
                style: theme.text(16, weight: FontWeight.w500),
              ),
              if (subtitle != null)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    subtitle!,
                    maxLines: 3,
                    textAlign: TextAlign.center,
                    style: theme.text(12, color: theme.labelSecondary),
                  ),
                ),
              if (actionLabel != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: GestureDetector(
                    onTap: onAction,
                    child: Text(
                      actionLabel!,
                      style: theme.text(
                        14,
                        weight: FontWeight.w500,
                        color: theme.accentText,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
        if (!constraints.hasBoundedHeight) return Center(child: group);
        return Align(alignment: Alignment(0, small ? 0 : -0.1), child: group);
      },
    );
  }
}

/// Page dots: inactive faint, the active one strong, gliding between
/// positions (240 ms).
class SoftPageIndicator extends StatelessWidget {
  const SoftPageIndicator({
    super.key,
    required this.count,
    required this.index,
  });

  final int count;
  final int index;

  static const double _dot = 6;
  static const double _gap = 3;

  @override
  Widget build(BuildContext context) {
    final SoftThemeData theme = SoftTheme.of(context);
    final bool reduce = softReduceMotion(context);
    return SizedBox(
      width: count * _dot + (count - 1) * _gap,
      height: _dot,
      child: Stack(
        children: <Widget>[
          for (int i = 0; i < count; i++)
            Positioned(
              left: i * (_dot + _gap),
              child: Container(
                width: _dot,
                height: _dot,
                decoration: BoxDecoration(
                  color: theme.labelTertiary,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          AnimatedPositioned(
            duration: reduce
                ? Duration.zero
                : const Duration(milliseconds: 240),
            curve: const Cubic(0.25, 0.1, 0.25, 1),
            left: index.clamp(0, count - 1) * (_dot + _gap),
            child: Container(
              width: _dot,
              height: _dot,
              decoration: BoxDecoration(
                color: theme.labelPrimary,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
