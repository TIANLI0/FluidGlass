import 'dart:math' as math;
import 'dart:ui' as ui;
// Derived from coui17 basic/NotificationSwipeBox.kt, Apache-2.0.
import 'package:flutter/semantics.dart';
import 'package:flutter/widgets.dart';

import '../../../backdrop.dart';
import '../../foundation/soft_meta_ball.dart';
import '../../foundation/soft_motion.dart';
import '../../foundation/soft_pressable.dart';
import '../../foundation/soft_theme.dart';

abstract final class SoftNotificationSwipeDefaults {
  static const double actionWidth = 60, gap = 10, endPadding = 4;
  static const double minHeight = 84, actionHeight = 68, cornerRadius = 16;
  static const double revealWidth = 144;
  static final SpringDescription settleSpring = softSpring(
    damping: 0.6,
    response: 0.55,
  );
}

/// A physical left swipe reveals settings and delete. Deletion only happens
/// through the explicit button or accessibility action, never on a fling.
/// Supply foreground-only [child] so the shared material remains visible.
class SoftNotificationSwipeBox extends StatefulWidget {
  const SoftNotificationSwipeBox({
    super.key,
    required this.child,
    required this.revealed,
    required this.onRevealedChanged,
    required this.onSettings,
    required this.onDismiss,
    required this.settingsIcon,
    required this.dismissIcon,
    required this.settingsLabel,
    required this.dismissLabel,
    this.enabled = true,
    this.backdrop,
    this.color,
    this.actionColor,
    this.minHeight = SoftNotificationSwipeDefaults.minHeight,
  });
  final Widget child, settingsIcon, dismissIcon;
  final bool revealed, enabled;
  final ValueChanged<bool> onRevealedChanged;
  final VoidCallback? onSettings, onDismiss;
  final String settingsLabel, dismissLabel;
  final Backdrop? backdrop;
  final Color? color, actionColor;
  final double minHeight;
  @override
  State<SoftNotificationSwipeBox> createState() =>
      _SoftNotificationSwipeBoxState();
}

class _SoftNotificationSwipeBoxState extends State<SoftNotificationSwipeBox>
    with TickerProviderStateMixin {
  late final SoftSpring _reveal = SoftSpring(
    vsync: this,
    value: widget.revealed ? 1 : 0,
  )..addListener(_syncRecoil);
  late final List<SoftSpring> _recoil = List<SoftSpring>.generate(
    2,
    (_) => SoftSpring(vsync: this, value: widget.revealed ? 1 : 0),
  );
  final List<bool> _cleared = <bool>[false, false];

  @override
  void initState() {
    super.initState();
    // The late fields above read the first widget; read them now, before a
    // later widget can be the one they see.
    _reveal;
    _recoil;
  }

  bool _reduce = false;
  double _width = 320;
  static const double _distance = 144;
  double _progress(int i) =>
      ((_reveal.value.clamp(0, 1) * _distance - 4 - 70 * i) / 68).clamp(0, 1);

  void _syncRecoil() {
    for (int i = 0; i < 2; i++) {
      final bool cleared = _progress(i) >= 1;
      if (cleared == _cleared[i]) continue;
      _cleared[i] = cleared;
      if (_reduce) {
        _recoil[i].snapTo(cleared ? 1 : 0);
      } else {
        _recoil[i].animateTo(
          cleared ? 1 : 0,
          SoftNotificationSwipeDefaults.settleSpring,
        );
      }
    }
  }

  void _settle(bool open) {
    if (_reduce) {
      _reveal.snapTo(open ? 1 : 0);
      for (final SoftSpring spring in _recoil) {
        spring.snapTo(open ? 1 : 0);
      }
    } else {
      _reveal.animateTo(
        open ? 1 : 0,
        SoftNotificationSwipeDefaults.settleSpring,
      );
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduce = softReduceMotion(context);
    if (_reduce) _settle(widget.revealed);
  }

  @override
  void didUpdateWidget(SoftNotificationSwipeBox oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.enabled || widget.revealed != oldWidget.revealed) {
      _settle(widget.revealed);
    }
  }

  void _commit(bool open) {
    _settle(open);
    if (open != widget.revealed) widget.onRevealedChanged(open);
  }

  void _action(VoidCallback? action) {
    if (!widget.enabled || action == null) return;
    _commit(false);
    action();
  }

  @override
  void dispose() {
    _reveal.dispose();
    for (final SoftSpring spring in _recoil) {
      spring.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final SoftThemeData theme = SoftTheme.of(context);
    return Semantics(
      customSemanticsActions: <CustomSemanticsAction, VoidCallback>{
        if (widget.enabled && widget.onSettings != null)
          CustomSemanticsAction(label: widget.settingsLabel): () =>
              _action(widget.onSettings),
        if (widget.enabled && widget.onDismiss != null)
          CustomSemanticsAction(label: widget.dismissLabel): () =>
              _action(widget.onDismiss),
      },
      child: LayoutBuilder(
        builder: (context, constraints) {
          _width = constraints.hasBoundedWidth ? constraints.maxWidth : 320;
          final bool draggable = widget.enabled && _width > _distance;
          return RepaintBoundary(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onHorizontalDragStart: draggable ? (_) => _reveal.stop() : null,
              onHorizontalDragUpdate: draggable
                  ? (details) => _reveal.snapTo(
                      (_reveal.value - details.delta.dx / _distance).clamp(
                        0,
                        1,
                      ),
                    )
                  : null,
              onHorizontalDragEnd: draggable
                  ? (details) {
                      final double velocity = details.primaryVelocity ?? 0;
                      _commit(
                        velocity.abs() >
                                125 * MediaQuery.devicePixelRatioOf(context)
                            ? velocity < 0
                            : _reveal.value > 0.5,
                      );
                    }
                  : null,
              onHorizontalDragCancel: draggable
                  ? () => _settle(widget.revealed)
                  : null,
              child: AnimatedBuilder(
                animation: Listenable.merge(<Listenable>[_reveal, ..._recoil]),
                child: widget.child,
                builder: (context, child) {
                  final double distance = _reveal.value.clamp(0, 1) * _distance;
                  final double cardWidth = math.max(0, _width - distance);
                  return SizedBox(
                    width: _width,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(minHeight: widget.minHeight),
                      child: Stack(
                        clipBehavior: Clip.hardEdge,
                        children: <Widget>[
                          Positioned.fill(
                            child: LayoutBuilder(
                              builder: (context, box) {
                                final double height = math.min(
                                  68,
                                  math.max(0, box.maxHeight - 16),
                                );
                                final List<SoftMetaBallParticle> particles =
                                    <SoftMetaBallParticle>[
                                      SoftMetaBallParticle(
                                        center: Offset(
                                          cardWidth / 2,
                                          box.maxHeight / 2,
                                        ),
                                        size: Size(cardWidth, box.maxHeight),
                                        cornerRadius: 16,
                                      ),
                                      for (int i = 0; i < 2; i++)
                                        SoftMetaBallParticle(
                                          center: Offset(
                                            _width -
                                                34 -
                                                70 * i -
                                                8 *
                                                    _progress(i) *
                                                    (1 - _recoil[i].value),
                                            8 + height / 2,
                                          ),
                                          size: Size(60, height),
                                          cornerRadius: 16,
                                        ),
                                    ];
                                return Stack(
                                  children: <Widget>[
                                    Positioned.fill(
                                      child: SoftMetaBallSurface(
                                        backdrop: widget.backdrop,
                                        color: widget.color ?? theme.colors.bar,
                                        rimAlpha: 0.55,
                                        rimBottomScale: 0,
                                        causticColor: null,
                                        shadow: null,
                                        extension: 3.5,
                                        extensionFactorX: 1.2,
                                        extensionFactorY: 2,
                                        particles: particles,
                                      ),
                                    ),
                                    Positioned.fill(
                                      child: ClipRect(
                                        clipper: _MenuStripClip(cardWidth),
                                        child: Stack(
                                          children: <Widget>[
                                            for (int i = 0; i < 2; i++)
                                              if (_progress(i) > 0.6)
                                                Positioned.fromRect(
                                                  rect: particles[i + 1].rect,
                                                  child: IgnorePointer(
                                                    ignoring:
                                                        !widget.enabled ||
                                                        _progress(i) < 1,
                                                    child: ExcludeSemantics(
                                                      excluding:
                                                          _progress(i) < 1,
                                                      child: Semantics(
                                                        label: i == 0
                                                            ? widget
                                                                  .dismissLabel
                                                            : widget
                                                                  .settingsLabel,
                                                        child: SoftPressable(
                                                          enabled:
                                                              widget.enabled &&
                                                              (i == 0
                                                                      ? widget
                                                                            .onDismiss
                                                                      : widget
                                                                            .onSettings) !=
                                                                  null,
                                                          onTap: () => _action(
                                                            i == 0
                                                                ? widget
                                                                      .onDismiss
                                                                : widget
                                                                      .onSettings,
                                                          ),
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                16,
                                                              ),
                                                          child: Center(
                                                            child: Opacity(
                                                              opacity:
                                                                  ((_progress(
                                                                                i,
                                                                              ) -
                                                                              0.6) /
                                                                          0.4)
                                                                      .clamp(
                                                                        0,
                                                                        1,
                                                                      ),
                                                              child: ImageFiltered(
                                                                imageFilter: ui.ImageFilter.blur(
                                                                  sigmaX:
                                                                      15 *
                                                                      (1 -
                                                                          ((_progress(i) -
                                                                                      0.6) /
                                                                                  0.4)
                                                                              .clamp(0, 1)) /
                                                                      MediaQuery.devicePixelRatioOf(
                                                                        context,
                                                                      ),
                                                                  sigmaY:
                                                                      15 *
                                                                      (1 -
                                                                          ((_progress(i) -
                                                                                      0.6) /
                                                                                  0.4)
                                                                              .clamp(0, 1)) /
                                                                      MediaQuery.devicePixelRatioOf(
                                                                        context,
                                                                      ),
                                                                ),
                                                                child: IconTheme(
                                                                  data: IconThemeData(
                                                                    size: 24,
                                                                    color:
                                                                        widget
                                                                            .actionColor ??
                                                                        theme
                                                                            .colors
                                                                            .onSurface,
                                                                  ),
                                                                  child: i == 0
                                                                      ? widget
                                                                            .dismissIcon
                                                                      : widget
                                                                            .settingsIcon,
                                                                ),
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
                                    ),
                                  ],
                                );
                              },
                            ),
                          ),
                          ClipPath(
                            clipper: _NotificationClip(cardWidth),
                            child: Transform.translate(
                              offset: Offset(-distance, 0),
                              child: SizedBox(width: _width, child: child),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }
}

class _MenuStripClip extends CustomClipper<Rect> {
  const _MenuStripClip(this.start);
  final double start;
  @override
  Rect getClip(Size size) => Rect.fromLTRB(start, 0, size.width, size.height);
  @override
  bool shouldReclip(_MenuStripClip old) => old.start != start;
}

class _NotificationClip extends CustomClipper<Path> {
  const _NotificationClip(this.width);
  final double width;
  @override
  Path getClip(Size size) => Path()
    ..addRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, width, size.height),
        const Radius.circular(16),
      ),
    );
  @override
  bool shouldReclip(_NotificationClip old) => old.width != width;
}
