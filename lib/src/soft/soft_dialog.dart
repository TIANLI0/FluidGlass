import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'soft_frosted.dart';
import 'soft_pressable.dart';
import 'soft_theme.dart';

/// How a [SoftDialogAction] is drawn.
enum SoftDialogActionStyle {
  /// A neutral pill.
  normal,

  /// A neutral pill with red text, for an action that destroys something.
  destructive,

  /// The accent pill — the one action the dialog recommends.
  recommended,
}

/// One button of a [showSoftDialog].
@immutable
class SoftDialogAction<T> {
  const SoftDialogAction({
    required this.label,
    this.value,
    this.style = SoftDialogActionStyle.normal,
    this.enabled = true,
  });

  final String label;

  /// Returned by [showSoftDialog] when this button closes the dialog.
  final T? value;
  final SoftDialogActionStyle style;
  final bool enabled;
}

/// Shows a centred dialog: an optional icon, a title, a message and a row of
/// pill buttons on a translucent, blurred card.
///
/// The card is at most 360 wide, 16 from the screen edges and sits 16 above
/// centre, with 32 corners. The title is 18 medium and centred; the message is
/// 13 secondary text, centred while it fits one line and start-aligned once it
/// wraps. Buttons are 44-high pills 8 apart, in reading order (put the
/// dismissive action first, the affirmative one last); when a label is too
/// long for a row they stack. It scales up from 0.8 and fades in (250 ms) and
/// only fades out (150 ms), over a 20% (dark 60%) scrim.
Future<T?> showSoftDialog<T>(
  BuildContext context, {
  String? title,
  String? message,
  Widget? icon,
  Widget? content,
  List<SoftDialogAction<T>> actions = const [],
  bool barrierDismissible = true,
}) {
  final SoftThemeData theme = SoftTheme.of(context);
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: theme.scrim,
    transitionDuration: const Duration(milliseconds: 250),
    pageBuilder: (BuildContext context, _, _) => SoftTheme(
      data: theme,
      child: _SoftDialog<T>(
        title: title,
        message: message,
        icon: icon,
        content: content,
        actions: actions,
      ),
    ),
    transitionBuilder:
        (
          BuildContext context,
          Animation<double> animation,
          Animation<double> secondary,
          Widget child,
        ) {
          final bool reduce =
              MediaQuery.maybeDisableAnimationsOf(context) ?? false;
          if (reduce) return FadeTransition(opacity: animation, child: child);
          final bool leaving = animation.status == AnimationStatus.reverse;
          if (leaving) {
            // Out: a plain fade, 150 ms.
            return FadeTransition(
              opacity: CurvedAnimation(
                parent: animation,
                curve: const Interval(0.4, 1, curve: Cubic(0.3, 0, 1, 1)),
              ),
              child: child,
            );
          }
          final Animation<double> eased = CurvedAnimation(
            parent: animation,
            curve: const Cubic(0.3, 0, 0.1, 1),
          );
          return FadeTransition(
            opacity: eased,
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.8, end: 1).animate(eased),
              child: child,
            ),
          );
        },
  );
}

class _SoftDialog<T> extends StatelessWidget {
  const _SoftDialog({
    required this.title,
    required this.message,
    required this.icon,
    required this.content,
    required this.actions,
  });

  final String? title;
  final String? message;
  final Widget? icon;
  final Widget? content;
  final List<SoftDialogAction<T>> actions;

  @override
  Widget build(BuildContext context) {
    final SoftThemeData theme = SoftTheme.of(context);
    final Size screen = MediaQuery.sizeOf(context);
    final double width = math.min(360, screen.width - 32);
    final TextStyle messageStyle = theme.text(
      13,
      color: theme.labelSecondary,
      height: 1.35,
    );
    return Center(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 32),
        child: SizedBox(
          width: width,
          child: SoftFrosted(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(32),
            ),
            tint: theme.backgroundElevated.withValues(
              alpha: theme.isDark ? 0.78 : 0.82,
            ),
            sigma: 32,
            child: Material(
              type: MaterialType.transparency,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: math.min(632, screen.height - 64),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Flexible(
                      child: SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: <Widget>[
                            if (icon != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 24),
                                child: Center(child: icon),
                              ),
                            if (title != null)
                              Padding(
                                padding: EdgeInsets.fromLTRB(
                                  24,
                                  icon == null ? 24 : 24,
                                  24,
                                  6,
                                ),
                                child: Text(
                                  title!,
                                  textAlign: TextAlign.center,
                                  style: theme.text(
                                    18,
                                    weight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            if (message != null)
                              Padding(
                                padding: EdgeInsets.fromLTRB(
                                  24,
                                  title == null ? 22 : 0,
                                  24,
                                  16,
                                ),
                                child: LayoutBuilder(
                                  builder:
                                      (BuildContext context, BoxConstraints c) {
                                        final TextPainter painter = TextPainter(
                                          text: TextSpan(
                                            text: message,
                                            style: messageStyle,
                                          ),
                                          textDirection: Directionality.of(
                                            context,
                                          ),
                                          textScaler: MediaQuery.textScalerOf(
                                            context,
                                          ),
                                        )..layout(maxWidth: c.maxWidth);
                                        final bool oneLine =
                                            painter
                                                .computeLineMetrics()
                                                .length <=
                                            1;
                                        painter.dispose();
                                        return Text(
                                          message!,
                                          textAlign: oneLine
                                              ? TextAlign.center
                                              : TextAlign.start,
                                          style: messageStyle,
                                        );
                                      },
                                ),
                              ),
                            ?content,
                          ],
                        ),
                      ),
                    ),
                    if (actions.isNotEmpty)
                      _ButtonBar<T>(actions: actions, width: width),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ButtonBar<T> extends StatelessWidget {
  const _ButtonBar({required this.actions, required this.width});

  final List<SoftDialogAction<T>> actions;
  final double width;

  @override
  Widget build(BuildContext context) {
    final SoftThemeData theme = SoftTheme.of(context);
    final TextStyle style = theme.text(16, weight: FontWeight.w500);
    // Stack when any label would not fit its share of the row.
    final double cell = width / actions.length - 2 * 12 - 16 - 4;
    bool stack = false;
    for (final SoftDialogAction<T> action in actions) {
      final TextPainter painter = TextPainter(
        text: TextSpan(text: action.label, style: style),
        textDirection: Directionality.of(context),
        textScaler: MediaQuery.textScalerOf(context),
        maxLines: 1,
      )..layout();
      if (painter.width > cell) stack = true;
      painter.dispose();
    }
    if (stack) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            for (int i = actions.length - 1; i >= 0; i--)
              Padding(
                padding: EdgeInsets.only(top: i == actions.length - 1 ? 0 : 8),
                child: _DialogButton<T>(action: actions[i], style: style),
              ),
          ],
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      child: Row(
        children: <Widget>[
          for (int i = 0; i < actions.length; i++) ...<Widget>[
            if (i > 0) const SizedBox(width: 8),
            Expanded(
              child: _DialogButton<T>(action: actions[i], style: style),
            ),
          ],
        ],
      ),
    );
  }
}

class _DialogButton<T> extends StatelessWidget {
  const _DialogButton({required this.action, required this.style});

  final SoftDialogAction<T> action;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    final SoftThemeData theme = SoftTheme.of(context);
    final bool recommended = action.style == SoftDialogActionStyle.recommended;
    final Color fill = recommended
        ? (action.enabled ? theme.accent : theme.accent.withValues(alpha: 0.3))
        : (theme.isDark ? const Color(0x1AFFFFFF) : const Color(0x14000000));
    final Color text = !action.enabled
        ? theme.labelTertiary
        : recommended
        ? theme.onAccent
        : action.style == SoftDialogActionStyle.destructive
        ? theme.error
        : theme.labelPrimary;
    return Semantics(
      button: true,
      enabled: action.enabled,
      child: SoftPressable(
        enabled: action.enabled,
        onTap: () => Navigator.of(context).pop(action.value),
        child: Container(
          constraints: const BoxConstraints(minHeight: 44),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          alignment: Alignment.center,
          decoration: ShapeDecoration(
            color: fill,
            shape: const StadiumBorder(),
          ),
          child: Text(
            action.label,
            maxLines: 2,
            textAlign: TextAlign.center,
            style: style.copyWith(color: text),
          ),
        ),
      ),
    );
  }
}
