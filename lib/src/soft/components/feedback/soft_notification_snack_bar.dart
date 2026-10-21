// Derived from coui17 basic/NotificationSnackBar.kt, Apache-2.0.
import 'package:flutter/widgets.dart';
import '../../../internal/control_focus.dart';
import '../../foundation/soft_pressable.dart';
import '../../foundation/soft_theme.dart';
import '../basic/soft_glyph_icon.dart';

enum SoftNotificationImageType { square, vertical, horizontal }

abstract final class SoftNotificationSnackBarDefaults {
  static const double cornerRadius = 16,
      contentStart = 16,
      contentVertical = 16;
  static const double layoutEnd = 6, iconGap = 8, subtitleGap = 2;
  static const double closeSize = 20,
      closePadding = 2,
      closeStart = 2,
      closeTop = 6;
  static const double actionMinWidth = 52,
      actionMaxWidth = 120,
      actionMinHeight = 28;
  static const double actionGap = 12;
}

/// The notification card. Geometry, two-line truncation, action
/// treatment and top-end close placement follow NotificationSnackBar.kt.
/// The caller owns display lifetime; [onPressed] is an optional app extension.
class SoftNotificationSnackBar extends StatelessWidget {
  const SoftNotificationSnackBar({
    super.key,
    required this.title,
    this.message,
    this.image,
    this.imageType = SoftNotificationImageType.square,
    this.actionLabel,
    this.onAction,
    this.onPressed,
    this.onClose,
    this.closeIcon,
    this.closeLabel = 'Dismiss',
    this.color,
    this.titleColor,
    this.subtitleColor,
    this.actionColor = const Color(0xFFFFFFFF),
    this.closeColor,
    this.cornerRadius = 16,
  });
  final String title;
  final String? message, actionLabel;
  final Widget? image, closeIcon;
  final SoftNotificationImageType imageType;
  final VoidCallback? onAction, onPressed, onClose;
  final String closeLabel;
  final Color? color, titleColor, subtitleColor, closeColor;
  final Color actionColor;
  final double cornerRadius;

  @override
  Widget build(BuildContext context) {
    final SoftThemeData theme = SoftTheme.of(context);
    final Color foreground = titleColor ?? theme.colors.onSurface;
    final Size imageSize = switch (imageType) {
      SoftNotificationImageType.square => const Size(44, 44),
      SoftNotificationImageType.vertical => const Size(36, 48),
      SoftNotificationImageType.horizontal => const Size(58, 44),
    };
    final Widget content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: theme.textStyles.body2.copyWith(
            color: foreground,
            fontWeight: FontWeight.w500,
          ),
        ),
        if (message != null) ...<Widget>[
          const SizedBox(height: 2),
          Text(
            message!,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textStyles.footnote2.copyWith(
              color: subtitleColor ?? theme.colors.onSurfaceSecondary,
            ),
          ),
        ],
      ],
    );
    return Padding(
      padding: const EdgeInsetsDirectional.only(end: 6),
      child: Semantics(
        container: true,
        liveRegion: true,
        child: Stack(
          children: <Widget>[
            DecoratedBox(
              decoration: BoxDecoration(
                color: color ?? theme.colors.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(cornerRadius),
              ),
              child: Padding(
                padding: EdgeInsetsDirectional.fromSTEB(
                  16,
                  16,
                  onClose != null ? 22 : 6,
                  16,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: <Widget>[
                    if (image != null) ...<Widget>[
                      IconTheme(
                        data: IconThemeData(color: foreground),
                        child: SizedBox.fromSize(
                          size: imageSize,
                          child: FittedBox(child: image),
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    Expanded(
                      child: onPressed == null
                          ? content
                          : SoftPressable(onTap: onPressed, child: content),
                    ),
                    if (actionLabel != null)
                      Padding(
                        padding: const EdgeInsetsDirectional.only(start: 12),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(
                            minWidth: 52,
                            maxWidth: 120,
                            minHeight: 28,
                          ),
                          child: ControlFocus(
                            enabled: onAction != null,
                            onActivate: onAction,
                            borderRadius: BorderRadius.circular(100),
                            child: SoftPressable(
                              onTap: onAction,
                              borderRadius: BorderRadius.circular(100),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 4,
                                ),
                                child: Text(
                                  actionLabel!,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textStyles.body2.copyWith(
                                    color: actionColor,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            if (onClose != null)
              PositionedDirectional(
                end: 0,
                top: 6,
                child: Semantics(
                  label: closeLabel,
                  child: Padding(
                    padding: const EdgeInsetsDirectional.only(start: 2),
                    child: ControlFocus(
                      onActivate: onClose,
                      borderRadius: BorderRadius.circular(10),
                      child: SoftPressable(
                        onTap: onClose,
                        borderRadius: BorderRadius.circular(10),
                        child: SizedBox.square(
                          dimension: 20,
                          child: Padding(
                            padding: const EdgeInsets.all(2),
                            child: IconTheme(
                              data: IconThemeData(
                                size: 16,
                                color:
                                    closeColor ??
                                    theme.colors.onSurfaceVariantActions,
                              ),
                              child:
                                  closeIcon ??
                                  const SoftGlyphIcon(SoftGlyph.close),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
