import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:fluid_glass/fluid_glass.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// One piece of glass that is a button, and then is the panel the button
/// opens, and then is the button again.
///
/// Nothing fades in: the element that was pressed *becomes* the surface. The
/// two axes run on separate springs — width leads on the way out, height
/// leads on the way back — so a panel unfolds from its button like something
/// poured rather than scaled, and folds back up the same way. Both springs
/// can be retargeted at any moment, so a tap on the scrim halfway through the
/// opening simply turns it round, and a panel dragged back towards where it
/// came from follows the finger and then goes wherever the release throws it.
class LabMorphContent extends StatefulWidget {
  const LabMorphContent({super.key});

  @override
  State<LabMorphContent> createState() => _LabMorphContentState();
}

enum _Source { create, search, details }

class _LabMorphContentState extends State<LabMorphContent> {
  final LayerBackdrop _backdrop = LayerBackdrop();

  /// The morph drawn last, so an open one is above the other two.
  _Source _top = _Source.create;

  /// Slow motion, to see the path the glass takes: width first on the way
  /// out, height first on the way back.
  bool _slow = false;

  @override
  void dispose() {
    timeDilation = 1.0;
    _backdrop.dispose();
    super.dispose();
  }

  void _toggleSlow() {
    setState(() => _slow = !_slow);
    timeDilation = _slow ? 6.0 : 1.0;
  }

  @override
  Widget build(BuildContext context) {
    final EdgeInsets safe = MediaQuery.paddingOf(context);
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final Size screen = constraints.biggest;
        final Map<_Source, _MorphSpec> specs = <_Source, _MorphSpec>{
          _Source.create: _MorphSpec(
            anchor: Rect.fromLTWH(
              screen.width - 16 - 60,
              screen.height - safe.bottom - 24 - 60,
              60,
              60,
            ),
            anchorRadius: 30,
            target: Rect.fromLTRB(
              16,
              screen.height - safe.bottom - 24 - 300,
              screen.width - 16,
              screen.height - safe.bottom - 24,
            ),
            targetRadius: 34,
            alignment: Alignment.bottomRight,
          ),
          _Source.search: _MorphSpec(
            anchor: Rect.fromCenter(
              center: Offset(screen.width / 2, safe.top + 8 + 24),
              width: 168,
              height: 48,
            ),
            anchorRadius: 24,
            target: Rect.fromLTWH(
              12,
              safe.top + 8,
              screen.width - 24,
              392,
            ),
            targetRadius: 30,
            alignment: Alignment.topCenter,
          ),
          _Source.details: _MorphSpec(
            anchor: Rect.fromCenter(
              center: Offset(screen.width / 2, screen.height * 0.62),
              width: 132,
              height: 44,
            ),
            anchorRadius: 22,
            target: Rect.fromCenter(
              center: Offset(screen.width / 2, screen.height * 0.47),
              width: 312,
              height: 248,
            ),
            targetRadius: 36,
            alignment: Alignment.center,
          ),
        };

        final List<_Source> order = <_Source>[
          ..._Source.values.where((_Source s) => s != _top),
          _top,
        ];

        return Stack(
          clipBehavior: Clip.none,
          children: <Widget>[
            Positioned.fill(
              child: BackdropLayer(
                backdrop: _backdrop,
                child: SizedBox.expand(
                  child: Image.asset(
                    'assets/wallpaper_light.webp',
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),
            Positioned(
              left: 24,
              right: 24,
              top: screen.height * 0.72,
              child: const _Hint(),
            ),
            Positioned(
              left: 16,
              bottom: safe.bottom + 24 + 6,
              height: 48,
              child: LiquidButton(
                backdrop: _backdrop,
                onPressed: _toggleSlow,
                tint: _slow ? const Color(0xFF0088FF) : null,
                surfaceColor: _slow
                    ? null
                    : const Color(0xFFFFFFFF).withValues(alpha: 0.3),
                children: <Widget>[
                  Text(
                    _slow ? 'Slow ×6 on' : 'Slow ×6',
                    style: TextStyle(
                      color: _slow
                          ? const Color(0xFFFFFFFF)
                          : const Color(0xFF111111),
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
            ),
            // Keyed at the Stack's own level: reordering them is what brings
            // an opening morph to the top, and a key one level down would
            // not be matched — every reorder would rebuild the morph that
            // is opening, closed.
            for (final _Source source in order)
              Positioned.fill(
                key: ValueKey<_Source>(source),
                child: _GlassMorph(
                  backdrop: _backdrop,
                  spec: specs[source]!,
                  onOpening: () => setState(() => _top = source),
                  anchor: _anchorFor(source),
                  panel: (VoidCallback close) => _panelFor(source, close),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _anchorFor(_Source source) {
    const Color ink = Color(0xFF111111);
    switch (source) {
      case _Source.create:
        return const Icon(Icons.add_rounded, color: ink, size: 28);
      case _Source.search:
        return const Row(
          mainAxisSize: MainAxisSize.min,
          spacing: 8,
          children: <Widget>[
            Icon(Icons.search_rounded, color: ink, size: 20),
            Text('Search', style: TextStyle(color: ink, fontSize: 16)),
          ],
        );
      case _Source.details:
        return const Row(
          mainAxisSize: MainAxisSize.min,
          spacing: 6,
          children: <Widget>[
            Icon(Icons.info_outline_rounded, color: ink, size: 18),
            Text('Details', style: TextStyle(color: ink, fontSize: 15)),
          ],
        );
    }
  }

  Widget _panelFor(_Source source, VoidCallback close) {
    switch (source) {
      case _Source.create:
        return _CreatePanel(onPick: close);
      case _Source.search:
        return _SearchPanel(onPick: close);
      case _Source.details:
        return _DetailsPanel(onAnswer: close);
    }
  }
}

class _MorphSpec {
  const _MorphSpec({
    required this.anchor,
    required this.anchorRadius,
    required this.target,
    required this.targetRadius,
    required this.alignment,
  });

  final Rect anchor;
  final double anchorRadius;
  final Rect target;
  final double targetRadius;

  /// Where the panel's content is pinned inside the growing glass — the side
  /// it grows from, so the content seems to have been folded up in the button.
  final Alignment alignment;
}

class _GlassMorph extends StatefulWidget {
  const _GlassMorph({
    required this.backdrop,
    required this.spec,
    required this.anchor,
    required this.panel,
    required this.onOpening,
  });

  final Backdrop backdrop;
  final _MorphSpec spec;
  final Widget anchor;
  final Widget Function(VoidCallback close) panel;
  final VoidCallback onOpening;

  @override
  State<_GlassMorph> createState() => _GlassMorphState();
}

class _GlassMorphState extends State<_GlassMorph>
    with TickerProviderStateMixin {
  // 0 is the button, 1 the panel, one spring per axis.
  late final SpringValue _x = SpringValue(
    vsync: this,
    value: 0,
    visibilityThreshold: 0.001,
  );
  late final SpringValue _y = SpringValue(
    vsync: this,
    value: 0,
    visibilityThreshold: 0.001,
  );
  late final InteractiveHighlight _press = InteractiveHighlight(vsync: this);
  late final Listenable _motion = Listenable.merge(<Listenable>[_x, _y]);

  bool _open = false;

  /// How far a drag has pulled the panel back towards its button, 0..1.
  double _pulled = 0;

  // Width leads on the way out; height leads on the way back. The overshoot
  // is on height, opening — the panel lands a little long and settles.
  static final SpringDescription _openX = springOf(0.82, 420);
  static final SpringDescription _openY = springOf(0.72, 230);
  static final SpringDescription _closeX = springOf(0.88, 300);
  static final SpringDescription _closeY = springOf(0.92, 520);

  @override
  void dispose() {
    _x.dispose();
    _y.dispose();
    _press.dispose();
    super.dispose();
  }

  void _openPanel() {
    widget.onOpening();
    setState(() => _open = true);
    _x.animateTo(1, _openX);
    _y.animateTo(1, _openY);
  }

  void _close({double velocity = 0}) {
    setState(() => _open = false);
    _x.animateTo(0, _closeX, withVelocity: velocity * 0.55);
    _y.animateTo(0, _closeY, withVelocity: velocity);
  }

  /// Unit vector, in y, pointing from the panel back to its button.
  double get _home {
    final double d =
        widget.spec.anchor.center.dy - widget.spec.target.center.dy;
    return d.abs() < 1 ? 1 : d.sign;
  }

  double get _reach => math.max(
    160,
    (widget.spec.anchor.center.dy - widget.spec.target.center.dy).abs() +
        widget.spec.target.height * 0.35,
  );

  void _dragStart(DragStartDetails d) {
    _pulled = 1 - _y.value;
  }

  void _dragUpdate(DragUpdateDetails d) {
    _pulled += d.delta.dy * _home / _reach;
    // Past fully open the panel resists rather than stretching freely.
    final double p = _pulled < 0 ? _pulled * 0.25 : _pulled;
    _y.snapTo((1 - p).clamp(0.0, 1.06));
    _x.snapTo((1 - p * 0.55).clamp(0.0, 1.02));
  }

  void _dragEnd(DragEndDetails d) {
    // Progress per second, in the "closing" direction.
    final double v = d.velocity.pixelsPerSecond.dy * _home / _reach;
    if (v > 1.4 || (_y.value < 0.6 && v > -0.8)) {
      _close(velocity: -v);
    } else {
      _x.animateTo(1, _openX, withVelocity: -v * 0.55);
      _y.animateTo(1, _openY, withVelocity: -v);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _motion,
      builder: (BuildContext context, Widget? _) {
        final _MorphSpec s = widget.spec;
        final double x = _x.value;
        final double y = _y.value;
        final double open = math.min(x, y).clamp(0.0, 1.0);

        final Rect rect = Rect.fromLTRB(
          ui.lerpDouble(s.anchor.left, s.target.left, x)!,
          ui.lerpDouble(s.anchor.top, s.target.top, y)!,
          ui.lerpDouble(s.anchor.right, s.target.right, x)!,
          ui.lerpDouble(s.anchor.bottom, s.target.bottom, y)!,
        );
        final double radius = math.min(
          ui.lerpDouble(s.anchorRadius, s.targetRadius, open)!,
          rect.shortestSide / 2,
        );
        final RoundedRectangularShape shape = RoundedRectangle(radius);

        // The button's face leaves early; the panel's arrives late, once
        // there is room for it — never both at full strength at once.
        final double anchorAlpha = (1 - open / 0.3).clamp(0.0, 1.0);
        final double panelAlpha = ((open - 0.55) / 0.45).clamp(0.0, 1.0);
        final bool resting = x == 0 && y == 0 && !_open;

        Widget face = Stack(
          fit: StackFit.expand,
          clipBehavior: Clip.hardEdge,
          children: <Widget>[
            if (anchorAlpha > 0)
              Center(
                child: Opacity(
                  opacity: anchorAlpha,
                  child: Transform.scale(
                    scale: 1 - 0.25 * (1 - anchorAlpha),
                    child: widget.anchor,
                  ),
                ),
              ),
            if (panelAlpha > 0)
              OverflowBox(
                alignment: s.alignment,
                minWidth: s.target.width,
                maxWidth: s.target.width,
                minHeight: s.target.height,
                maxHeight: s.target.height,
                child: IgnorePointer(
                  // Not `panelAlpha < 1`: (1 - 0.55) / 0.45 is
                  // 0.9999999999999999, and a panel that never quite reaches
                  // 1 never takes a tap.
                  ignoring: !_open || open < 0.9,
                  child: Opacity(
                    opacity: panelAlpha,
                    child: Transform.translate(
                      offset: Offset(0, 12 * (1 - panelAlpha) * -_home),
                      child: Material(
                        type: MaterialType.transparency,
                        child: widget.panel(_close),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
        face = ClipPath(clipper: GlassShapeClipper(shape), child: face);

        // The same wrappers in every state, with their callbacks switched on
        // and off, so the tree under the glass never changes shape mid-morph
        // and the press glow is not torn out the instant the button opens.
        final bool canPress = resting || (!_open && open < 0.05);
        face = _press.wrapOverlay(
          child: GestureDetector(
            // Open, the whole face is the panel's: a tap on empty glass must
            // not fall through to the scrim and close it.
            behavior: _open
                ? HitTestBehavior.opaque
                : HitTestBehavior.deferToChild,
            onVerticalDragStart: _open ? _dragStart : null,
            onVerticalDragUpdate: _open ? _dragUpdate : null,
            onVerticalDragEnd: _open ? _dragEnd : null,
            child: DragInspector(
              behavior: HitTestBehavior.translucent,
              onDragStart: canPress
                  ? (Offset p, Size _) => _press.handleDown(p)
                  : null,
              onDrag: canPress
                  ? (Offset p, Offset _, Size _) => _press.handleMove(p)
                  : null,
              onDragEnd: _press.handleUp,
              onDragCancel: _press.handleUp,
              onTap: canPress ? _openPanel : null,
              child: face,
            ),
          ),
        );

        final Widget glass = DrawBackdrop(
          backdrop: widget.backdrop,
          shape: () => shape,
          effects: (BackdropEffectScope scope) => scope
            ..vibrancy()
            ..blur(ui.lerpDouble(2, 10, open)!)
            ..lens(
              ui.lerpDouble(12, 22, open)!,
              ui.lerpDouble(24, 30, open)!,
            ),
          onDrawSurface: (Canvas canvas, Size size) => canvas.drawRect(
            Offset.zero & size,
            Paint()
              ..color = const Color(
                0xFFFFFFFF,
              ).withValues(alpha: ui.lerpDouble(0.3, 0.62, open)!),
          ),
          isolateSurface: false,
          repaint: _press,
          child: face,
        );

        return Stack(
          clipBehavior: Clip.none,
          children: <Widget>[
            if (open > 0.001 || _open)
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _open ? _close : null,
                  child: ColoredBox(
                    color: const Color(
                      0xFF000000,
                    ).withValues(alpha: 0.22 * open),
                  ),
                ),
              ),
            Positioned.fromRect(rect: rect, child: glass),
          ],
        );
      },
    );
  }
}

class _Hint extends StatelessWidget {
  const _Hint();

  @override
  Widget build(BuildContext context) {
    return Text(
      'Tap +, Search or Details.\n'
      'Tap outside mid-flight to turn it round, or drag a panel back '
      'towards where it came from.',
      textAlign: TextAlign.center,
      style: TextStyle(
        color: const Color(0xFFFFFFFF),
        fontSize: 13,
        height: 1.4,
        shadows: <Shadow>[
          Shadow(
            color: const Color(0xFF000000).withValues(alpha: 0.35),
            blurRadius: 6,
          ),
        ],
      ),
    );
  }
}

const Color _ink = Color(0xFF111111);

class _Row extends StatelessWidget {
  const _Row({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          spacing: 14,
          children: <Widget>[
            Icon(icon, color: _ink, size: 22),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: _ink, fontSize: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CreatePanel extends StatelessWidget {
  const _CreatePanel({required this.onPick});

  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 22, 20, 8),
          child: Text(
            'Create',
            style: TextStyle(
              color: _ink,
              fontSize: 22,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        _Row(icon: Icons.edit_note_rounded, label: 'New note', onTap: onPick),
        _Row(icon: Icons.photo_camera_outlined, label: 'Photo', onTap: onPick),
        _Row(icon: Icons.mic_none_rounded, label: 'Voice memo', onTap: onPick),
        _Row(
          icon: Icons.document_scanner_outlined,
          label: 'Scan document',
          onTap: onPick,
        ),
      ],
    );
  }
}

class _SearchPanel extends StatelessWidget {
  const _SearchPanel({required this.onPick});

  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 6),
          child: Container(
            height: 46,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: ShapeDecoration(
              color: const Color(0xFFFFFFFF).withValues(alpha: 0.85),
              shape: const GlassShapeBorder(Capsule()),
            ),
            child: const Row(
              spacing: 10,
              children: <Widget>[
                Icon(Icons.search_rounded, color: _ink, size: 20),
                Flexible(
                  child: Text(
                    'Search notes, photos, people',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: Color(0x99111111), fontSize: 15),
                  ),
                ),
              ],
            ),
          ),
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 14, 20, 4),
          child: Text(
            'RECENT',
            style: TextStyle(
              color: Color(0x99111111),
              fontSize: 12,
              letterSpacing: 1.2,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        _Row(icon: Icons.history_rounded, label: 'Trip to Kyoto', onTap: onPick),
        _Row(icon: Icons.history_rounded, label: 'Quarterly plan', onTap: onPick),
        _Row(icon: Icons.history_rounded, label: 'Glass shaders', onTap: onPick),
        _Row(icon: Icons.history_rounded, label: 'Recipes', onTap: onPick),
      ],
    );
  }
}

class _DetailsPanel extends StatelessWidget {
  const _DetailsPanel({required this.onAnswer});

  final VoidCallback onAnswer;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 26, 24, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            'Keep your changes?',
            style: TextStyle(
              color: _ink,
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          // Takes what room is left and fades out past it, so a large text
          // scale shortens the message instead of pushing the answers off
          // the glass.
          const Expanded(
            child: Text(
              'This panel is the same piece of glass as the button you '
              'pressed. Answer, tap outside, or drag it down.',
              overflow: TextOverflow.fade,
              style: TextStyle(
                color: Color(0xCC111111),
                fontSize: 15,
                height: 1.35,
              ),
            ),
          ),
          Row(
            children: <Widget>[
              Expanded(
                child: TextButton(
                  onPressed: onAnswer,
                  child: const Text(
                    'Discard',
                    style: TextStyle(color: Color(0xFFE5484D), fontSize: 16),
                  ),
                ),
              ),
              Expanded(
                child: TextButton(
                  onPressed: onAnswer,
                  child: const Text(
                    'Keep',
                    style: TextStyle(
                      color: Color(0xFF0A7CFF),
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
