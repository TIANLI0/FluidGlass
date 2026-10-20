import 'package:flutter/material.dart';

import '../theme/liquid_glass_theme.dart';

enum LiquidNoticeSeverity { info, success, warning, error }

Color _noticeColor(BuildContext context, LiquidNoticeSeverity severity) {
  final colors = LiquidGlassTheme.of(context);
  return switch (severity) {
    LiquidNoticeSeverity.info => colors.accent,
    LiquidNoticeSeverity.success => colors.success,
    LiquidNoticeSeverity.warning =>
      Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFFFFC857)
          : const Color(0xFF8B5E00),
    LiquidNoticeSeverity.error => colors.destructive,
  };
}

IconData _noticeIcon(LiquidNoticeSeverity severity) => switch (severity) {
  LiquidNoticeSeverity.info => Icons.info_outline_rounded,
  LiquidNoticeSeverity.success => Icons.check_circle_outline_rounded,
  LiquidNoticeSeverity.warning => Icons.warning_amber_rounded,
  LiquidNoticeSeverity.error => Icons.error_outline_rounded,
};

/// An inline message. The caller owns its visibility and any recovery action.
/// The icon/text convey severity together; color is never the only signal.
class LiquidNotice extends StatelessWidget {
  const LiquidNotice({
    super.key,
    required this.title,
    this.message,
    this.severity = LiquidNoticeSeverity.info,
    this.actionLabel,
    this.onAction,
    this.onDismiss,
    this.dismissLabel = 'Dismiss',
    this.liveRegion = true,
  });
  final String title;
  final String? message;
  final LiquidNoticeSeverity severity;
  final String? actionLabel;
  final VoidCallback? onAction;
  final VoidCallback? onDismiss;
  final String dismissLabel;
  final bool liveRegion;

  @override
  Widget build(BuildContext context) {
    final colors = LiquidGlassTheme.of(context);
    final color = _noticeColor(context, severity);
    return Semantics(
      container: true,
      liveRegion: liveRegion,
      child: AnimatedContainer(
        duration: (MediaQuery.maybeDisableAnimationsOf(context) ?? false)
            ? Duration.zero
            : const Duration(milliseconds: 180),
        padding: const EdgeInsetsDirectional.fromSTEB(16, 14, 12, 14),
        decoration: BoxDecoration(
          color: Color.alphaBlend(
            color.withValues(alpha: 0.075),
            Theme.of(context).colorScheme.surface,
          ),
          border: Border.all(color: color.withValues(alpha: 0.22)),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            ExcludeSemantics(
              child: Icon(_noticeIcon(severity), color: color, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    title,
                    style: TextStyle(
                      color: colors.content,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      height: 1.5,
                    ),
                  ),
                  if (message != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        message!,
                        style: TextStyle(
                          color: colors.content.withValues(alpha: 0.75),
                          fontSize: 13,
                          height: 1.5,
                        ),
                      ),
                    ),
                  if (actionLabel != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: TextButton(
                        onPressed: onAction,
                        style: TextButton.styleFrom(
                          foregroundColor: color,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                        ),
                        child: Text(actionLabel!),
                      ),
                    ),
                ],
              ),
            ),
            if (onDismiss != null)
              IconButton(
                tooltip: dismissLabel,
                onPressed: onDismiss,
                icon: Icon(
                  Icons.close_rounded,
                  size: 18,
                  color: colors.content.withValues(alpha: 0.65),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Labeled progress, with an optional cancellation action.
/// Null [value] means unknown progress; a finite value must be between 0 and 1.
class LiquidProgress extends StatelessWidget {
  const LiquidProgress({
    super.key,
    this.value,
    this.label,
    this.description,
    this.onCancel,
    this.cancelLabel = 'Cancel',
    this.workingLabel = 'Working',
    this.showPercentage = true,
  }) : assert(value == null || value >= 0 && value <= 1);
  final double? value;
  final String? label;
  final String? description;
  final VoidCallback? onCancel;
  final String cancelLabel;
  final String workingLabel;
  final bool showPercentage;

  @override
  Widget build(BuildContext context) {
    final colors = LiquidGlassTheme.of(context);
    final bool still = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    Widget bar(double? value) => LinearProgressIndicator(
      value: value,
      minHeight: 5,
      color: colors.accent,
      backgroundColor: colors.track,
      borderRadius: BorderRadius.circular(5),
    );
    return Semantics(
      label: label ?? workingLabel,
      value: value == null ? workingLabel : '${(value! * 100).round()}%',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (label != null ||
              value != null && showPercentage ||
              onCancel != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 48),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: ExcludeSemantics(
                        child: Text(
                          label ?? workingLabel,
                          style: TextStyle(
                            color: colors.content,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                    if (value != null && showPercentage)
                      ExcludeSemantics(
                        child: Text(
                          '${(value! * 100).round()}%',
                          style: TextStyle(
                            color: colors.content.withValues(alpha: 0.7),
                            fontSize: 13,
                          ),
                        ),
                      ),
                    if (onCancel != null)
                      TextButton(onPressed: onCancel, child: Text(cancelLabel)),
                  ],
                ),
              ),
            ),
          ExcludeSemantics(
            child: value == null
                ? still
                      ? Container(
                          height: 5,
                          alignment: AlignmentDirectional.centerStart,
                          decoration: BoxDecoration(
                            color: colors.track,
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: FractionallySizedBox(
                            widthFactor: 0.35,
                            child: Container(
                              decoration: BoxDecoration(
                                color: colors.accent,
                                borderRadius: BorderRadius.circular(5),
                              ),
                            ),
                          ),
                        )
                      : bar(null)
                : still
                ? bar(value)
                : TweenAnimationBuilder<double>(
                    tween: Tween<double>(begin: value, end: value),
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOutCubic,
                    builder: (context, progress, child) => bar(progress),
                  ),
          ),
          if (description != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                description!,
                style: TextStyle(
                  color: colors.content.withValues(alpha: 0.7),
                  fontSize: 12,
                  height: 1.5,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// A scroll-safe empty state with an optional useful next action.
class LiquidEmptyState extends StatelessWidget {
  const LiquidEmptyState({
    super.key,
    required this.title,
    this.message,
    this.icon = Icons.inbox_outlined,
    this.actionLabel,
    this.onAction,
  });
  final String title;
  final String? message;
  final IconData icon;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final colors = LiquidGlassTheme.of(context);
    return Center(
      child: SingleChildScrollView(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                ExcludeSemantics(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: colors.accent.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: Icon(icon, size: 36, color: colors.accent),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: colors.content,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    height: 1.4,
                  ),
                ),
                if (message != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      message!,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: colors.content.withValues(alpha: 0.7),
                        fontSize: 14,
                        height: 1.5,
                      ),
                    ),
                  ),
                if (actionLabel != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: FilledButton(
                      onPressed: onAction,
                      child: Text(actionLabel!),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Shows an accessible floating notification through ScaffoldMessenger.
/// Queueing, action timeouts, swipe dismissal and route lifetime follow Flutter.
ScaffoldFeatureController<SnackBar, SnackBarClosedReason> showLiquidToast({
  required BuildContext context,
  required String message,
  String? title,
  LiquidNoticeSeverity severity = LiquidNoticeSeverity.info,
  String? actionLabel,
  VoidCallback? onAction,
  Duration duration = const Duration(seconds: 4),
  bool showCloseIcon = true,
}) {
  assert(onAction == null || actionLabel != null);
  final theme = Theme.of(context);
  final tone = _noticeColor(context, severity);
  return ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      behavior: SnackBarBehavior.floating,
      duration: duration,
      backgroundColor: Color.alphaBlend(
        tone.withValues(alpha: 0.16),
        theme.colorScheme.inverseSurface,
      ),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      showCloseIcon: showCloseIcon,
      closeIconColor: theme.colorScheme.onInverseSurface,
      content: Row(
        children: <Widget>[
          ExcludeSemantics(
            child: Icon(
              _noticeIcon(severity),
              size: 21,
              color: theme.colorScheme.onInverseSurface,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text.rich(
              TextSpan(
                children: <InlineSpan>[
                  if (title != null)
                    TextSpan(
                      text: '$title\n',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  TextSpan(text: message),
                ],
              ),
              style: TextStyle(
                color: theme.colorScheme.onInverseSurface,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
      action: actionLabel != null && onAction != null
          ? SnackBarAction(
              label: actionLabel,
              textColor: theme.colorScheme.onInverseSurface,
              onPressed: onAction,
            )
          : null,
    ),
  );
}
