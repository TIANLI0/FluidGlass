import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

import 'soft_motion.dart';
import 'soft_pressable.dart';
import 'soft_theme.dart';

/// A 24 checkbox: a rounded-square outline when off; on, an accent square with
/// a white tick that draws itself along its stroke (300 ms) while the box
/// bumps to 1.08 and back. [value] null is the partial state (a white bar).
class SoftCheckbox extends StatefulWidget {
  const SoftCheckbox({
    super.key,
    required this.value,
    required this.onChanged,
    this.tristate = false,
    this.semanticLabel,
  });

  final bool? value;

  /// Null disables the box.
  final ValueChanged<bool?>? onChanged;
  final bool tristate;
  final String? semanticLabel;

  @override
  State<SoftCheckbox> createState() => _SoftCheckboxState();
}

class _SoftCheckboxState extends State<SoftCheckbox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _t = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 300),
    value: widget.value == false ? 0 : 1,
  );
  late bool? _from = widget.value;

  @override
  void didUpdateWidget(SoftCheckbox oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != oldWidget.value) {
      _from = oldWidget.value;
      if (softReduceMotion(context)) {
        _t.value = widget.value == false ? 0 : 1;
      } else if (widget.value == false) {
        _t.reverse(from: 1);
      } else {
        _t.forward(from: 0);
      }
    }
  }

  @override
  void dispose() {
    _t.dispose();
    super.dispose();
  }

  void _toggle() {
    final ValueChanged<bool?>? onChanged = widget.onChanged;
    if (onChanged == null) return;
    onChanged(switch (widget.value) {
      false => true,
      true => widget.tristate ? null : false,
      null => false,
    });
  }

  @override
  Widget build(BuildContext context) {
    final SoftThemeData theme = SoftTheme.of(context);
    final bool enabled = widget.onChanged != null;
    return Semantics(
      checked: widget.value ?? false,
      mixed: widget.value == null,
      enabled: enabled,
      label: widget.semanticLabel,
      onTap: enabled ? _toggle : null,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: enabled ? _toggle : null,
        child: SizedBox.square(
          dimension: 24,
          child: AnimatedBuilder(
            animation: _t,
            builder: (BuildContext context, _) => CustomPaint(
              painter: _CheckboxPainter(
                t: _t.value,
                partial:
                    widget.value == null ||
                    (_from == null && widget.value == false && _t.isAnimating),
                accent: enabled
                    ? theme.accent
                    : theme.accent.withValues(alpha: 0.3),
                outline: enabled ? theme.labelTertiary : theme.labelQuaternary,
                glyph: enabled
                    ? const Color(0xFFFFFFFF)
                    : (theme.isDark
                          ? const Color(0x29FFFFFF)
                          : const Color(0x8AFFFFFF)),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CheckboxPainter extends CustomPainter {
  const _CheckboxPainter({
    required this.t,
    required this.partial,
    required this.accent,
    required this.outline,
    required this.glyph,
  });

  final double t;
  final bool partial;
  final Color accent;
  final Color outline;
  final Color glyph;

  static const Curve _ease = SoftCurves.moveEase;

  @override
  void paint(Canvas canvas, Size size) {
    // The bump: 1 → 1.08 → 1 over the run.
    final double bump = t < 0.5
        ? lerpDouble(1, 1.08, _ease.transform(t * 2))!
        : lerpDouble(1.08, 1, _ease.transform((t - 0.5) * 2))!;
    canvas.translate(12, 12);
    canvas.scale(t > 0 && t < 1 ? bump : 1);
    canvas.translate(-12, -12);

    // Outline, fading as the fill arrives.
    final double fill = (t * 2).clamp(0.0, 1.0);
    if (fill < 1) {
      canvas.drawRRect(
        RRect.fromLTRBR(3.8, 3.8, 20.2, 20.2, const Radius.circular(3.2)),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.3
          ..color = outline.withValues(alpha: outline.a * (1 - fill)),
      );
    }
    if (fill > 0) {
      canvas.drawRRect(
        RRect.fromLTRBR(3, 3, 21, 21, const Radius.circular(4)),
        Paint()
          ..color = accent.withValues(alpha: accent.a * _ease.transform(fill)),
      );
    }
    if (partial) {
      final double grow = _ease.transform(t);
      canvas.drawRRect(
        RRect.fromLTRBR(
          7,
          11.2,
          7 + 10 * grow,
          12.8,
          const Radius.circular(0.8),
        ),
        Paint()..color = glyph,
      );
      return;
    }
    // The tick, drawn on along its length.
    final Path tick = Path()
      ..moveTo(7.29, 11.92)
      ..lineTo(10.85, 15.48)
      ..lineTo(17.66, 8.62);
    final double drawn = _ease.transform(t);
    if (drawn <= 0) return;
    final Path partialTick = Path();
    for (final metric in tick.computeMetrics()) {
      partialTick.addPath(
        metric.extractPath(0, metric.length * drawn),
        Offset.zero,
      );
    }
    canvas.drawPath(
      partialTick,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.3 * 1.15
        ..strokeJoin = StrokeJoin.round
        ..color = glyph,
    );
  }

  @override
  bool shouldRepaint(_CheckboxPainter old) =>
      old.t != t ||
      old.partial != partial ||
      old.accent != accent ||
      old.outline != outline ||
      old.glyph != glyph;
}

/// A 24 radio button: a thin ring when off; on, an accent disc with a white dot
/// that grows from the centre while the ring fades and the whole bumps to
/// 1.08 and back (300 ms).
class SoftRadio<T> extends StatefulWidget {
  const SoftRadio({
    super.key,
    required this.value,
    required this.groupValue,
    required this.onChanged,
    this.semanticLabel,
  });

  final T value;
  final T? groupValue;
  final ValueChanged<T>? onChanged;
  final String? semanticLabel;

  @override
  State<SoftRadio<T>> createState() => _SoftRadioState<T>();
}

class _SoftRadioState<T> extends State<SoftRadio<T>>
    with SingleTickerProviderStateMixin {
  late final AnimationController _t = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 300),
    value: _on ? 1 : 0,
  );

  bool get _on => widget.value == widget.groupValue;

  @override
  void didUpdateWidget(SoftRadio<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    final bool was = oldWidget.value == oldWidget.groupValue;
    if (was != _on) {
      if (softReduceMotion(context)) {
        _t.value = _on ? 1 : 0;
      } else if (_on) {
        _t.forward(from: 0);
      } else {
        _t.reverse(from: 1);
      }
    }
  }

  @override
  void dispose() {
    _t.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final SoftThemeData theme = SoftTheme.of(context);
    final bool enabled = widget.onChanged != null;
    void select() => widget.onChanged?.call(widget.value);
    return Semantics(
      checked: _on,
      inMutuallyExclusiveGroup: true,
      enabled: enabled,
      label: widget.semanticLabel,
      onTap: enabled ? select : null,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: enabled ? select : null,
        child: SizedBox.square(
          dimension: 24,
          child: AnimatedBuilder(
            animation: _t,
            builder: (BuildContext context, _) => CustomPaint(
              painter: _RadioPainter(
                t: _t.value,
                accent: enabled
                    ? theme.accent
                    : theme.accent.withValues(alpha: 0.3),
                outline: enabled ? theme.labelTertiary : theme.labelQuaternary,
                dot: enabled
                    ? const Color(0xFFFAFAFA)
                    : (theme.isDark
                          ? const Color(0x29FFFFFF)
                          : const Color(0x8AFFFFFF)),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RadioPainter extends CustomPainter {
  const _RadioPainter({
    required this.t,
    required this.accent,
    required this.outline,
    required this.dot,
  });

  final double t;
  final Color accent;
  final Color outline;
  final Color dot;

  @override
  void paint(Canvas canvas, Size size) {
    const Curve ease = SoftCurves.moveEase;
    final double e = ease.transform(t);
    final double bump = t < 0.5
        ? lerpDouble(1, 1.08, ease.transform(t * 2))!
        : lerpDouble(1.08, 1, ease.transform((t - 0.5) * 2))!;
    const Offset c = Offset(12, 12);
    canvas.translate(12, 12);
    canvas.scale(t > 0 && t < 1 ? bump : 1);
    canvas.translate(-12, -12);
    if (e < 1) {
      canvas.drawCircle(
        c,
        9.2,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.3
          ..color = outline.withValues(alpha: outline.a * (1 - e)),
      );
    }
    if (e > 0) {
      canvas.drawCircle(
        c,
        10,
        Paint()..color = accent.withValues(alpha: accent.a * e),
      );
      canvas.drawCircle(
        c,
        6 * e,
        Paint()..color = dot.withValues(alpha: dot.a * e),
      );
    }
  }

  @override
  bool shouldRepaint(_RadioPainter old) =>
      old.t != t ||
      old.accent != accent ||
      old.outline != outline ||
      old.dot != dot;
}

/// A checkable pill chip: neutral fill and primary text when off, accent fill
/// and white text when on (a (0.3, 0) spring between them). 32 high with 14
/// text; [small] is 28 with 12. An optional leading [icon] and a trailing
/// close button ([onDeleted]).
class SoftChip extends StatefulWidget {
  const SoftChip({
    super.key,
    required this.label,
    this.selected = false,
    this.onSelected,
    this.onDeleted,
    this.icon,
    this.small = false,
  });

  final String label;
  final bool selected;

  /// Null makes the chip a plain, non-checkable label (still deletable).
  final ValueChanged<bool>? onSelected;
  final VoidCallback? onDeleted;
  final IconData? icon;
  final bool small;

  @override
  State<SoftChip> createState() => _SoftChipState();
}

class _SoftChipState extends State<SoftChip>
    with SingleTickerProviderStateMixin {
  late final AnimationController _on = AnimationController.unbounded(
    vsync: this,
    value: widget.selected ? 1 : 0,
  );

  @override
  void didUpdateWidget(SoftChip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selected != oldWidget.selected) {
      _on.springTo(
        widget.selected ? 1 : 0,
        softSpring(0.3),
        reduceMotion: softReduceMotion(context),
      );
    }
  }

  @override
  void dispose() {
    _on.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final SoftThemeData theme = SoftTheme.of(context);
    final bool enabled = widget.onSelected != null || widget.onDeleted != null;
    final Color offFill = theme.isDark
        ? const Color(0x1AFFFFFF)
        : const Color(0x14000000);
    return Semantics(
      button: widget.onSelected != null,
      selected: widget.selected,
      label: widget.label,
      child: ExcludeSemantics(
        child: SoftPressable(
          enabled: widget.onSelected != null,
          onTap: widget.onSelected == null
              ? null
              : () => widget.onSelected!(!widget.selected),
          shape: const StadiumBorder(),
          child: AnimatedBuilder(
            animation: _on,
            builder: (BuildContext context, _) {
              final double t = _on.value.clamp(0.0, 1.0);
              final Color fill = Color.lerp(offFill, theme.accent, t)!;
              final Color text = Color.lerp(
                enabled ? theme.labelPrimary : theme.labelTertiary,
                theme.onAccent,
                t,
              )!;
              return Container(
                constraints: BoxConstraints(
                  minHeight: widget.small ? 28 : 32,
                  minWidth: 52,
                  maxWidth: 300,
                ),
                padding: EdgeInsetsDirectional.only(
                  start: 12,
                  end: widget.onDeleted == null ? 12 : 8,
                ),
                decoration: ShapeDecoration(
                  color: fill,
                  shape: const StadiumBorder(),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    if (widget.icon != null) ...<Widget>[
                      Icon(
                        widget.icon,
                        size: widget.small ? 14 : 16,
                        color: text,
                      ),
                      const SizedBox(width: 4),
                    ],
                    Flexible(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 200),
                        child: Text(
                          widget.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.text(
                            widget.small ? 12 : 14,
                            color: text,
                          ),
                        ),
                      ),
                    ),
                    if (widget.onDeleted != null)
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: widget.onDeleted,
                        child: Padding(
                          padding: const EdgeInsetsDirectional.only(start: 8),
                          child: Icon(
                            Icons.close_rounded,
                            size: 12,
                            color: text,
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
