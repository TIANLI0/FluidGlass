import 'package:flutter/widgets.dart';

import '../../foundation/soft_colors.dart';
import '../../foundation/soft_theme.dart';
import 'soft_text_action.dart';

/// How much of the free height a [SoftEmptyState] leaves above its content.
enum SoftEmptyStateSize {
  /// Picked from the available size.
  auto,

  /// Shorter than 200: the illustration hides.
  small,

  /// Narrower than 320 or shorter than 480.
  medium,

  large,
}

/// The empty state defaults.
abstract final class SoftEmptyStateDefaults {
  /// The illustration box.
  static const double illustrationWidth = 120;
  static const double illustrationHeight = 100;

  /// The width of the title and subtitle.
  static const double contentWidth = 280;

  /// The height the title and subtitle scroll within.
  static const double contentMaxHeight = 92;
  static const double subtitleMarginTop = 2;
  static const double actionMarginTop = 8;
  static const EdgeInsets actionPadding = EdgeInsets.symmetric(
    horizontal: 12,
    vertical: 4,
  );

  /// The share of the free height above the content: half in a short box,
  /// 45 % otherwise.
  static const double marginTopRatioSmall = 0.5;
  static const double marginTopRatioNormal = 0.45;

  static const double heightThresholdSmall = 200;
  static const double heightThresholdMedium = 480;
  static const double widthThresholdMedium = 320;

  /// The size bucket of a [width] × [height] box.
  static SoftEmptyStateSize sizeFor(double width, double height) {
    if (height < heightThresholdSmall) return SoftEmptyStateSize.small;
    if (width < widthThresholdMedium || height < heightThresholdMedium) {
      return SoftEmptyStateSize.medium;
    }
    return SoftEmptyStateSize.large;
  }

  static double marginTopRatio(SoftEmptyStateSize size) =>
      size == SoftEmptyStateSize.small
      ? marginTopRatioSmall
      : marginTopRatioNormal;

  /// The title: 16 medium, line height 1.05.
  static TextStyle titleStyle(SoftThemeData theme) => theme.textStyles.headline2
      .copyWith(height: 1.05, fontWeight: FontWeight.w500);

  /// The subtitle: 12, line height 1.
  static TextStyle subtitleStyle(SoftThemeData theme) =>
      theme.textStyles.footnote1.copyWith(fontSize: 12, height: 1);

  /// The action: 14 medium, line height 1.1.
  static TextStyle actionStyle(SoftThemeData theme) =>
      theme.textStyles.body2.copyWith(height: 1.1, fontWeight: FontWeight.w500);
}

/// An empty page: an optional illustration, a centred title (two lines) and
/// subtitle (three lines) in a 280-wide area that scrolls past 92 tall, and
/// an optional accent action.
///
/// Given a fixed height it leaves 45 % of the free height above the content
/// (half in a small box), so the group sits a little above the middle;
/// otherwise it lays out at the top. The illustration, 120 × 100, hides in
/// [SoftEmptyStateSize.small].
class SoftEmptyState extends StatelessWidget {
  const SoftEmptyState({
    super.key,
    required this.title,
    this.subtitle,
    this.actionText,
    this.onAction,
    this.illustration,
    this.size = SoftEmptyStateSize.auto,
    this.titleColor,
    this.subtitleColor,
    this.actionColor,
  });

  final String title;
  final String? subtitle;
  final String? actionText;
  final VoidCallback? onAction;
  final Widget? illustration;
  final SoftEmptyStateSize size;

  /// `onSurface` by default.
  final Color? titleColor;

  /// `onSurfaceSecondary` by default.
  final Color? subtitleColor;

  /// `primary` by default.
  final Color? actionColor;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final SoftEmptyStateSize resolved = size == SoftEmptyStateSize.auto
            ? SoftEmptyStateDefaults.sizeFor(
                constraints.maxWidth,
                constraints.maxHeight,
              )
            : size;
        final Widget content = _content(
          context,
          resolved != SoftEmptyStateSize.small,
        );
        if (!constraints.hasTightHeight) return content;
        final int above =
            (SoftEmptyStateDefaults.marginTopRatio(resolved) * 1000).round();
        return Column(
          children: <Widget>[
            Spacer(flex: above),
            content,
            Spacer(flex: 1000 - above),
          ],
        );
      },
    );
  }

  Widget _content(BuildContext context, bool showIllustration) {
    final SoftThemeData theme = SoftTheme.of(context);
    final SoftColors colors = theme.colors;
    final Widget? illustration = this.illustration;
    final String? subtitle = (this.subtitle?.isEmpty ?? true)
        ? null
        : this.subtitle;
    final String? actionText = (this.actionText?.isEmpty ?? true)
        ? null
        : this.actionText;
    return SizedBox(
      width: double.infinity,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (showIllustration && illustration != null)
            SizedBox(
              width: SoftEmptyStateDefaults.illustrationWidth,
              height: SoftEmptyStateDefaults.illustrationHeight,
              child: Center(child: illustration),
            ),
          SizedBox(
            width: SoftEmptyStateDefaults.contentWidth,
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxHeight: SoftEmptyStateDefaults.contentMaxHeight,
              ),
              child: ScrollConfiguration(
                behavior: ScrollConfiguration.of(
                  context,
                ).copyWith(scrollbars: false),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      Text(
                        title,
                        style: SoftEmptyStateDefaults.titleStyle(
                          theme,
                        ).copyWith(color: titleColor ?? colors.onSurface),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (subtitle != null)
                        Padding(
                          padding: const EdgeInsets.only(
                            top: SoftEmptyStateDefaults.subtitleMarginTop,
                          ),
                          child: Text(
                            subtitle,
                            style: SoftEmptyStateDefaults.subtitleStyle(theme)
                                .copyWith(
                                  color:
                                      subtitleColor ??
                                      colors.onSurfaceSecondary,
                                ),
                            textAlign: TextAlign.center,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (actionText != null)
            Padding(
              padding: const EdgeInsets.only(
                top: SoftEmptyStateDefaults.actionMarginTop,
              ),
              child: SoftTextAction(
                label: actionText,
                maxLines: null,
                textAlign: TextAlign.center,
                padding: SoftEmptyStateDefaults.actionPadding,
                style: SoftEmptyStateDefaults.actionStyle(
                  theme,
                ).copyWith(color: actionColor ?? colors.primary),
                onTap: onAction ?? () {},
              ),
            ),
        ],
      ),
    );
  }
}
