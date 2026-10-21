import 'package:flutter/widgets.dart';

import '../../foundation/soft_pressable.dart';

/// The bare accent label the feedback components use as a button: a label
/// carrying the reference's text press padding (12 × 4), with the theme's
/// state-layer tint clipped to a capsule while pressed.
///
/// Not exported; the snackbar, the top tips and the empty state share it.
class SoftTextAction extends StatelessWidget {
  const SoftTextAction({
    super.key,
    required this.label,
    required this.style,
    this.onTap,
    this.maxLines = 1,
    this.padding = const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
    this.minWidth = 0,
    this.minHeight = 0,
    this.radius,
    this.textAlign,
  });

  final String label;

  /// The label style, colour included.
  final TextStyle style;
  final VoidCallback? onTap;
  final int? maxLines;
  final EdgeInsetsGeometry padding;
  final double minWidth;
  final double minHeight;

  /// The tint's corner radius; a capsule by default.
  final double? radius;
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) {
    Widget label = Padding(
      padding: padding,
      child: Text(
        this.label,
        style: style,
        maxLines: maxLines,
        overflow: TextOverflow.ellipsis,
        textAlign: textAlign,
      ),
    );
    if (minWidth > 0 || minHeight > 0) {
      label = ConstrainedBox(
        constraints: BoxConstraints(minWidth: minWidth, minHeight: minHeight),
        child: Center(widthFactor: 1, heightFactor: 1, child: label),
      );
    }
    return SoftPressable(
      onTap: onTap,
      borderRadius: BorderRadius.circular(radius ?? 1000),
      child: label,
    );
  }
}
