import 'package:flutter/widgets.dart';

import 'soft_dialog.dart';
import 'soft_dialog_button_bar.dart';

/// The alert-dialog defaults.
abstract final class SoftAlertDialogDefaults {
  /// The gap between the content and the button bar.
  static const double buttonBarMarginTop = 8;
}

/// Shows a centred alert: a [title], a [summary], an optional [content]
/// slot and a cancel / confirm button bar.
///
/// Unlike [showSoftDialog] the panel is centred on every window size, with
/// the centred transitions (scale from 0.8 and fade in over 250 ms, fade out
/// over 150 ms). It completes with true when [confirmText] is tapped and
/// false when [cancelText] is, or — with [dismissible] — on a tap outside or
/// back, which count as cancelling.
///
/// Without [cancelText] the bar holds the confirm button alone. With
/// [destructive] the confirm label turns `error`; with [recommended] the
/// confirm button is filled `primary`. The content slot spans the panel
/// edge to edge; pad it like the summary
/// ([SoftDialogDefaults.insideMargin]).
Future<bool> showSoftAlertDialog({
  required BuildContext context,
  required String confirmText,
  String? cancelText,
  String? title,
  String? summary,
  Widget? content,
  bool destructive = false,
  bool recommended = false,
  bool confirmEnabled = true,
  Color? titleColor,
  Color? summaryColor,
  Color? backgroundColor,
  bool dismissible = true,
  bool enableWindowDim = true,
  double maxWidth = SoftDialogDefaults.maxWidth,
  double? cornerRadius,
  bool useRootNavigator = true,
  RouteSettings? routeSettings,
  String? barrierLabel,
  VoidCallback? onDismissFinished,
}) async {
  final SoftDialogRoute<bool> route = SoftDialogRoute<bool>(
    title: title,
    summary: summary,
    titleColor: titleColor,
    summaryColor: summaryColor,
    backgroundColor: backgroundColor,
    dismissible: dismissible,
    enableWindowDim: enableWindowDim,
    largeScreen: true,
    maxWidth: maxWidth,
    cornerRadius: cornerRadius,
    barrierLabel: barrierLabel,
    settings: routeSettings,
    builder: (BuildContext context) => Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        ?content,
        Padding(
          padding: const EdgeInsets.only(
            top: SoftAlertDialogDefaults.buttonBarMarginTop,
          ),
          child: SoftDialogButtonBar(
            negative: cancelText == null
                ? null
                : SoftDialogAction(
                    label: cancelText,
                    onPressed: () => dismissSoftDialog<bool>(context, false),
                  ),
            positive: SoftDialogAction(
              label: confirmText,
              enabled: confirmEnabled,
              recommended: recommended,
              destructive: destructive,
              onPressed: () => dismissSoftDialog<bool>(context, true),
            ),
          ),
        ),
      ],
    ),
  );
  final bool? result = await pushSoftDialogRoute<bool>(
    context,
    route,
    useRootNavigator: useRootNavigator,
    onDismissFinished: onDismissFinished,
  );
  return result ?? false;
}
