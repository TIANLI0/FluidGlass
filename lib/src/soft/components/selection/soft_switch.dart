// Derived from Costben/coui17 basic/Switch.kt, Apache-2.0.
// Copyright 2025, compose-coui-ui contributors.
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../../foundation/soft_colors.dart';
import '../../foundation/soft_motion.dart';
import '../../foundation/soft_theme.dart';
import 'soft_selection_frame.dart';

/// Metrics and toggle timing of the reference switch.
abstract final class SoftSwitchDefaults {
  static const double width = 38;
  static const double height = 24;
  static const double thumbSize = 18;
  static const double margin = 3;
  static const Duration toggleDuration = Duration(milliseconds: 383);
  static const Duration trackDuration = Duration(milliseconds: 450);
  static const Duration loadingDuration = Duration(milliseconds: 550);
  static const Duration rotationDuration = Duration(milliseconds: 800);
  static const Curve toggleCurve = Cubic(0.3, 0, 0.1, 1);
}

@immutable
class SoftSwitchColors {
  const SoftSwitchColors({
    required this.checkedThumb,
    required this.uncheckedThumb,
    required this.disabledCheckedThumb,
    required this.disabledUncheckedThumb,
    required this.checkedTrack,
    required this.uncheckedTrack,
    required this.disabledCheckedTrack,
    required this.disabledUncheckedTrack,
  });

  SoftSwitchColors.of(SoftColors colors)
    : this(
        checkedThumb: colors.onPrimary,
        uncheckedThumb: colors.onSecondary,
        disabledCheckedThumb: colors.disabledOnPrimary,
        disabledUncheckedThumb: colors.disabledOnSecondary,
        checkedTrack: colors.primary,
        uncheckedTrack: colors.secondary,
        disabledCheckedTrack: colors.disabledPrimary,
        disabledUncheckedTrack: colors.disabledSecondary,
      );

  final Color checkedThumb;
  final Color uncheckedThumb;
  final Color disabledCheckedThumb;
  final Color disabledUncheckedThumb;
  final Color checkedTrack;
  final Color uncheckedTrack;
  final Color disabledCheckedTrack;
  final Color disabledUncheckedTrack;

  Color thumb(bool checked, bool enabled) => enabled
      ? (checked ? checkedThumb : uncheckedThumb)
      : (checked ? disabledCheckedThumb : disabledUncheckedThumb);

  Color track(bool checked, bool enabled) => enabled
      ? (checked ? checkedTrack : uncheckedTrack)
      : (checked ? disabledCheckedTrack : disabledUncheckedTrack);
}

/// A controlled, tap-driven switch. Toggling stretches the thumb's tail
/// against its travel; dragging does not move the thumb. While [isLoading],
/// a rotating gradient arc replaces the thumb and input is disabled.
///
/// The visible track is 38 × 24 inside a 48 × 48 touch target. Reduced motion
/// settles transitions immediately and shows a stationary loading arc.
class SoftSwitch extends StatefulWidget {
  const SoftSwitch({
    super.key,
    required this.checked,
    required this.onChanged,
    this.enabled = true,
    this.isLoading = false,
    this.colors,
    this.semanticLabel,
    this.loadingSemanticLabel = 'Loading',
    this.haptics = true,
  });

  final bool checked;
  final ValueChanged<bool>? onChanged;
  final bool enabled;
  final bool isLoading;
  final SoftSwitchColors? colors;
  final String? semanticLabel;
  final String loadingSemanticLabel;
  final bool haptics;

  @override
  State<SoftSwitch> createState() => _SoftSwitchState();
}

class _SoftSwitchState extends State<SoftSwitch> with TickerProviderStateMixin {
  late final AnimationController _toggle = AnimationController(
    vsync: this,
    duration: SoftSwitchDefaults.toggleDuration,
    value: 1,
  );
  late final AnimationController _track = AnimationController(
    vsync: this,
    duration: SoftSwitchDefaults.trackDuration,
    value: 1,
  );
  late final AnimationController _loading = AnimationController(
    vsync: this,
    duration: SoftSwitchDefaults.loadingDuration,
    value: widget.isLoading ? 1 : 0,
  );
  late final AnimationController _rotation = AnimationController(
    vsync: this,
    duration: SoftSwitchDefaults.rotationDuration,
  );
  late final SoftSpring _overlay = SoftSpring(vsync: this);
  late final Listenable _repaint = Listenable.merge(<Listenable>[
    _toggle,
    _track,
    _loading,
    _rotation,
    _overlay,
  ]);
  Color? _fromTrack;
  Color? _toTrack;
  Color? _fromThumb;
  Color? _toThumb;
  bool _reduce = false;
  bool _hovered = false;
  bool _pressed = false;
  bool _focused = false;

  bool get _active =>
      widget.enabled && !widget.isLoading && widget.onChanged != null;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduce = softReduceMotion(context);
    _syncColors();
    _syncLoading();
    if (_reduce) _toggle.value = 1;
    _syncOverlay();
  }

  @override
  void didUpdateWidget(SoftSwitch oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.checked != widget.checked) {
      if (_reduce) {
        _toggle.value = 1;
      } else {
        _toggle.forward(from: 0);
      }
    }
    _syncColors();
    if (oldWidget.isLoading != widget.isLoading) _syncLoading();
    if (!_active) _pressed = false;
    _syncOverlay();
  }

  void _syncColors() {
    final SoftSwitchColors colors =
        widget.colors ?? SoftSwitchColors.of(SoftTheme.of(context).colors);
    final Color next = colors.track(widget.checked, widget.enabled);
    final Color nextThumb = colors.thumb(widget.checked, widget.enabled);
    if (_toTrack == null) {
      _fromTrack = _toTrack = next;
      _fromThumb = _toThumb = nextThumb;
      return;
    }
    if (next == _toTrack && nextThumb == _toThumb) {
      if (_reduce) _track.value = 1;
      return;
    }
    final double progress = SoftSwitchDefaults.toggleCurve.transform(
      _track.value,
    );
    _fromTrack = Color.lerp(_fromTrack, _toTrack, progress);
    _fromThumb = Color.lerp(_fromThumb, _toThumb, progress);
    _toTrack = next;
    _toThumb = nextThumb;
    if (_reduce) {
      _track.value = 1;
    } else {
      _track.forward(from: 0);
    }
  }

  void _syncLoading() {
    final double target = widget.isLoading ? 1 : 0;
    if (_reduce) {
      _loading.value = target;
      _rotation.stop();
      _rotation.value = 0;
    } else {
      _loading.animateTo(
        target,
        duration: widget.isLoading
            ? SoftSwitchDefaults.loadingDuration
            : const Duration(milliseconds: 100),
        curve: Curves.linear,
      );
      if (widget.isLoading) {
        if (!_rotation.isAnimating) _rotation.repeat();
      } else {
        _rotation.stop();
      }
    }
  }

  void _syncOverlay() {
    final double target = !_active
        ? 0
        : (_pressed ? 0.12 : ((_hovered || _focused) ? 0.078 : 0));
    if (_reduce) {
      _overlay.snapTo(target);
    } else {
      _overlay.animateTo(target, SoftMotion.stateLayer);
    }
  }

  void _setPressed(bool pressed) {
    _pressed = pressed;
    _syncOverlay();
  }

  void _activate() {
    if (!_active) return;
    widget.onChanged!(!widget.checked);
    if (widget.haptics) {
      playSoftSelectionHaptic(
        widget.checked
            ? SoftSelectionHaptic.toggleOff
            : SoftSelectionHaptic.toggleOn,
      );
    }
  }

  @override
  void dispose() {
    _toggle.dispose();
    _track.dispose();
    _loading.dispose();
    _rotation.dispose();
    _overlay.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final SoftThemeData theme = SoftTheme.of(context);
    return Semantics(
      label: widget.semanticLabel,
      toggled: widget.checked,
      enabled: _active,
      onTap: _active ? _activate : null,
      value: widget.isLoading ? widget.loadingSemanticLabel : null,
      child: FocusableActionDetector(
        enabled: _active,
        onShowFocusHighlight: (bool value) {
          _focused = value;
          _syncOverlay();
        },
        shortcuts: const <ShortcutActivator, Intent>{
          SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
          SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
        },
        actions: <Type, Action<Intent>>{
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              _activate();
              return null;
            },
          ),
        },
        child: MouseRegion(
          cursor: _active ? SystemMouseCursors.click : SystemMouseCursors.basic,
          onEnter: (_) {
            _hovered = true;
            _syncOverlay();
          },
          onExit: (_) {
            _hovered = false;
            _syncOverlay();
          },
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            excludeFromSemantics: true,
            onTap: _active ? _activate : null,
            onTapDown: _active ? (_) => _setPressed(true) : null,
            onTapUp: _active ? (_) => _setPressed(false) : null,
            onTapCancel: () => _setPressed(false),
            child: SizedBox.square(
              dimension: 48,
              child: Center(
                child: RepaintBoundary(
                  child: CustomPaint(
                    size: const Size(
                      SoftSwitchDefaults.width,
                      SoftSwitchDefaults.height,
                    ),
                    painter: _SwitchPainter(
                      repaint: _repaint,
                      toggle: _toggle,
                      track: _track,
                      loading: _loading,
                      rotation: _rotation,
                      overlay: _overlay,
                      fromTrack: _fromTrack!,
                      toTrack: _toTrack!,
                      fromThumb: _fromThumb!,
                      toThumb: _toThumb!,
                      overlayColor: theme.colors.onSurface,
                      checked: widget.checked,
                      enabled: widget.enabled,
                      loadingIn: widget.isLoading,
                      rtl: Directionality.of(context) == TextDirection.rtl,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SwitchPainter extends CustomPainter {
  _SwitchPainter({
    required Listenable repaint,
    required this.toggle,
    required this.track,
    required this.loading,
    required this.rotation,
    required this.overlay,
    required this.fromTrack,
    required this.toTrack,
    required this.fromThumb,
    required this.toThumb,
    required this.overlayColor,
    required this.checked,
    required this.enabled,
    required this.rtl,
    required this.loadingIn,
  }) : super(repaint: repaint);

  final Animation<double> toggle, track, loading, rotation;
  final SoftSpring overlay;
  final Color fromTrack, toTrack, fromThumb, toThumb, overlayColor;
  final bool checked, enabled, rtl, loadingIn;

  @override
  void paint(Canvas canvas, Size size) {
    final Color thumb = Color.lerp(
      fromThumb,
      toThumb,
      SoftSwitchDefaults.toggleCurve.transform(track.value),
    )!;
    final RRect bar = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(12),
    );
    canvas.save();
    canvas.clipRRect(bar);
    canvas.drawRRect(
      bar,
      Paint()
        ..color = Color.lerp(
          fromTrack,
          toTrack,
          SoftSwitchDefaults.toggleCurve.transform(track.value),
        )!,
    );
    canvas.drawRRect(
      bar,
      Paint()
        ..color = overlayColor.withValues(alpha: overlay.value.clamp(0.0, 1.0)),
    );
    final double time = toggle.value * 383;
    final double travel = SoftSwitchDefaults.toggleCurve.transform(
      toggle.value,
    );
    final double position = checked ? travel : 1 - travel;
    final double stretch = time < 133
        ? 1 + 0.3 * SoftSwitchDefaults.toggleCurve.transform(time / 133)
        : 1.3 -
              0.3 *
                  SoftSwitchDefaults.toggleCurve.transform(
                    ((time - 133) / 250).clamp(0.0, 1.0),
                  );
    final double width = 18 * stretch;
    double left = 3 + 14 * position + (checked ? 18 - width : 0);
    if (rtl) left = size.width - left - width;
    final Rect thumbRect = Rect.fromLTWH(left, 3, width, 18);
    final Offset centre = thumbRect.center;
    final double load = SoftSwitchDefaults.toggleCurve.transform(loading.value);
    // The native thumb shrinks over 433 ms of the 550 ms loading entrance.
    final double thumbScale = loadingIn
        ? 1 -
              SoftSwitchDefaults.toggleCurve.transform(
                (loading.value * 550 / 433).clamp(0.0, 1.0),
              )
        : 1;
    if (thumbScale > 0) {
      final RRect shape = RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: centre,
          width: width * thumbScale,
          height: 18 * thumbScale,
        ),
        Radius.circular(9 * thumbScale),
      );
      if (enabled) {
        canvas.drawRRect(
          shape.shift(const Offset(0, 1.14)),
          Paint()
            ..color = const Color(0x19000000)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.29),
        );
      }
      canvas.drawRRect(shape, Paint()..color = thumb);
    }
    if (load > 0) {
      canvas.save();
      canvas.translate(centre.dx, centre.dy);
      canvas.rotate((rotation.value * 360 + 150) * math.pi / 180);
      final double scale = loadingIn ? 0.5 + 0.5 * load : 1;
      canvas.scale(scale);
      canvas.drawArc(
        Rect.fromCircle(center: Offset.zero, radius: 7.2),
        0,
        312 * math.pi / 180,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3.6
          ..shader = ui.Gradient.sweep(
            Offset.zero,
            <Color>[
              thumb.withValues(alpha: 0),
              thumb.withValues(alpha: thumb.a * load),
            ],
            <double>[0, 312 / 360],
          ),
      );
      canvas.restore();
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_SwitchPainter old) =>
      old.checked != checked ||
      old.enabled != enabled ||
      old.rtl != rtl ||
      old.fromThumb != fromThumb ||
      old.toThumb != toThumb ||
      old.fromTrack != fromTrack ||
      old.toTrack != toTrack ||
      old.overlayColor != overlayColor ||
      old.loadingIn != loadingIn;
}
