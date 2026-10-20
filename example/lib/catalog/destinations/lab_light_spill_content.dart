import 'dart:ui' as ui;

import 'package:fluid_glass/fluid_glass.dart';
import 'package:flutter/material.dart';

import '../lab/rim_light.dart';

/// Experiment: light that one element gives off landing on the elements
/// around it.
///
/// Press a tile and hold — the glow under the finger lights the rims of its
/// neighbours on the side facing it, falling off with distance, and follows
/// the finger if you slide. Drag the warm orb and it lights whatever it
/// passes. The switch turns the spill off, which is how every control lights
/// today: only the one being touched.
///
/// Each tile's spill is its own repaint boundary over the glass, so a moving
/// light repaints a few strokes per tile and never the glass itself — and
/// with nothing moving, nothing is drawn at all.
class LabLightSpillContent extends StatefulWidget {
  const LabLightSpillContent({super.key});

  @override
  State<LabLightSpillContent> createState() => _LabLightSpillContentState();
}

class _LabLightSpillContentState extends State<LabLightSpillContent>
    with TickerProviderStateMixin {
  final LayerBackdrop _backdrop = LayerBackdrop();
  late final _LightField _field = _LightField(this);
  bool _spill = true;

  static const List<IconData> _icons = <IconData>[
    Icons.wifi_rounded,
    Icons.bluetooth_rounded,
    Icons.flashlight_on_rounded,
    Icons.dark_mode_rounded,
    Icons.photo_camera_rounded,
    Icons.calculate_rounded,
  ];

  static const RoundedRectangularShape _tileShape = RoundedRectangle(30);
  static const double _orbSize = 60;

  @override
  void dispose() {
    _field.dispose();
    _backdrop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final EdgeInsets safe = MediaQuery.paddingOf(context);
    return LiquidGlassTheme(
      colors: LiquidGlassColors.forBrightness(Brightness.dark),
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final Size screen = constraints.biggest;
          const double gap = 14;
          final double side = ((screen.width - 32 - gap) / 2).clamp(0.0, 168.0);
          final double gridWidth = side * 2 + gap;
          final double left = (screen.width - gridWidth) / 2;
          final double top = safe.top + 136;
          final List<Rect> tiles = <Rect>[
            for (int i = 0; i < _icons.length; i++)
              Rect.fromLTWH(
                left + (i % 2) * (side + gap),
                top + (i ~/ 2) * (side + gap),
                side,
                side,
              ),
          ];
          _field.orbHome ??= Offset(screen.width / 2, tiles.last.bottom + 70);

          return Stack(
            clipBehavior: Clip.none,
            children: <Widget>[
              Positioned.fill(
                child: BackdropLayer(
                  backdrop: _backdrop,
                  child: const LabWallpaper(dim: 0.58),
                ),
              ),
              Positioned(
                left: 16,
                right: 16,
                top: safe.top + 64,
                height: 56,
                child: LiquidPanel(
                  backdrop: _backdrop,
                  shape: const Capsule(),
                  surfaceColor: const Color(0xFF0E1620).withValues(alpha: 0.4),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: <Widget>[
                        const Expanded(
                          child: Text(
                            'Light spills onto neighbours',
                            style: TextStyle(
                              color: Color(0xFFFFFFFF),
                              fontSize: 15,
                            ),
                          ),
                        ),
                        LiquidToggle(
                          backdrop: _backdrop,
                          selected: _spill,
                          onSelect: (bool v) => setState(() => _spill = v),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              for (int i = 0; i < tiles.length; i++)
                Positioned.fromRect(
                  rect: tiles[i],
                  child: _Tile(
                    backdrop: _backdrop,
                    field: _field,
                    rect: tiles[i],
                    shape: _tileShape,
                    spill: _spill,
                    icon: _icons[i],
                  ),
                ),
              ListenableBuilder(
                listenable: _field.orb,
                builder: (BuildContext context, Widget? child) {
                  final Offset c = _field.orbCentre;
                  return Positioned(
                    left: c.dx - _orbSize / 2,
                    top: c.dy - _orbSize / 2,
                    width: _orbSize,
                    height: _orbSize,
                    child: child!,
                  );
                },
                child: GestureDetector(
                  // The orb's glass has nothing inside it to hit.
                  behavior: HitTestBehavior.opaque,
                  onPanUpdate: (DragUpdateDetails d) => _field.moveOrb(d.delta),
                  child: _Orb(backdrop: _backdrop),
                ),
              ),
              Positioned(
                left: 24,
                right: 24,
                bottom: safe.bottom + 20,
                child: Text(
                  'Hold a tile and slide, or drag the orb across the grid.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: const Color(0xFFFFFFFF).withValues(alpha: 0.7),
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// One source of light, in page coordinates.
class _Light {
  const _Light(this.position, this.strength, this.radius, this.color);

  final Offset position;
  final double strength;
  final double radius;
  final Color color;
}

/// Every light on the page, and the one thing every tile listens to.
class _LightField extends ChangeNotifier {
  _LightField(TickerProvider vsync)
    : press = SpringValue(vsync: vsync, value: 0, visibilityThreshold: 0.002),
      orb = ValueNotifier<Offset>(Offset.zero) {
    press.addListener(notifyListeners);
    orb.addListener(notifyListeners);
  }

  final SpringValue press;
  final ValueNotifier<Offset> orb;
  Offset _pressAt = Offset.zero;
  Offset? orbHome;

  Offset get orbCentre => (orbHome ?? Offset.zero) + orb.value;

  static final SpringDescription _on = springOf(0.9, 380);
  static final SpringDescription _off = springOf(1.0, 160);

  static const Color _pressColor = Color(0xFFEFF7FF);
  static const Color _orbColor = Color(0xFFFFDDA8);

  List<_Light> get lights => <_Light>[
    if (press.value > 0.001) _Light(_pressAt, press.value, 210, _pressColor),
    _Light(orbCentre, 1, 230, _orbColor),
  ];

  void pressDown(Offset at) {
    _pressAt = at;
    press.animateTo(1, _on);
  }

  void pressMove(Offset at) {
    _pressAt = at;
    notifyListeners();
  }

  // Released slowly, so the light is seen to go out rather than switch off.
  void pressUp() => press.animateTo(0, _off);

  void moveOrb(Offset delta) => orb.value += delta;

  @override
  void dispose() {
    press.dispose();
    orb.dispose();
    super.dispose();
  }
}

class _Tile extends StatefulWidget {
  const _Tile({
    required this.backdrop,
    required this.field,
    required this.rect,
    required this.shape,
    required this.spill,
    required this.icon,
  });

  final Backdrop backdrop;
  final _LightField field;
  final Rect rect;
  final RoundedRectangularShape shape;
  final bool spill;
  final IconData icon;

  @override
  State<_Tile> createState() => _TileState();
}

class _TileState extends State<_Tile> with TickerProviderStateMixin {
  late final InteractiveHighlight _glow = InteractiveHighlight(vsync: this);
  bool _on = false;

  @override
  void dispose() {
    _glow.dispose();
    super.dispose();
  }

  Offset _page(Offset local) => widget.rect.topLeft + local;

  @override
  Widget build(BuildContext context) {
    final Widget glass = DrawBackdrop(
      backdrop: widget.backdrop,
      shape: () => widget.shape,
      effects: (BackdropEffectScope scope) => scope
        ..vibrancy()
        ..blur(8)
        ..lens(18, 26),
      onDrawSurface: (Canvas canvas, Size size) => canvas.drawRect(
        Offset.zero & size,
        Paint()
          ..color = _on
              ? const Color(0xFF3D8BFF).withValues(alpha: 0.72)
              : const Color(0xFF0E1620).withValues(alpha: 0.38),
      ),
      isolateSurface: false,
      repaint: _glow,
      child: _glow.wrapOverlay(
        child: DragInspector(
          behavior: HitTestBehavior.opaque,
          onDragStart: (Offset p, Size _) {
            _glow.handleDown(p);
            widget.field.pressDown(_page(p));
          },
          onDrag: (Offset p, Offset _, Size _) {
            _glow.handleMove(p);
            widget.field.pressMove(_page(p));
          },
          onDragEnd: () {
            _glow.handleUp();
            widget.field.pressUp();
          },
          onDragCancel: () {
            _glow.handleUp();
            widget.field.pressUp();
          },
          onTap: () => setState(() => _on = !_on),
          child: Center(
            child: Icon(widget.icon, color: const Color(0xFFFFFFFF), size: 34),
          ),
        ),
      ),
    );

    return Stack(
      clipBehavior: Clip.none,
      children: <Widget>[
        Positioned.fill(child: glass),
        if (widget.spill)
          Positioned.fill(
            child: IgnorePointer(
              child: RepaintBoundary(
                child: CustomPaint(
                  painter: _SpillPainter(
                    widget.field,
                    widget.rect,
                    widget.shape,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _SpillPainter extends CustomPainter {
  _SpillPainter(this.field, this.rect, this.shape) : super(repaint: field);

  final _LightField field;
  final Rect rect;
  final RoundedRectangularShape shape;
  final RimPathCache _cache = RimPathCache();

  // Roughly inverse-square: bright close in, a long faint tail.
  static const List<double> _stops = <double>[0, 0.22, 0.55, 1];
  static const List<double> _falloff = <double>[1, 0.5, 0.16, 0];

  @override
  void paint(Canvas canvas, Size size) {
    final RimPath rim = _cache.of(shape, size);
    for (final _Light light in field.lights) {
      final Offset local = light.position - rect.topLeft;
      // Nothing to do if the light cannot reach any part of this tile.
      final double dx = (local.dx.clamp(0.0, size.width) - local.dx).abs();
      final double dy = (local.dy.clamp(0.0, size.height) - local.dy).abs();
      if (dx * dx + dy * dy > light.radius * light.radius) continue;

      ui.Gradient gradient(double alpha) =>
          ui.Gradient.radial(local, light.radius, <Color>[
            for (final double f in _falloff)
              light.color.withValues(alpha: alpha * f * light.strength),
          ], _stops);

      canvas.drawPath(
        rim.path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 7
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4)
          ..shader = gradient(0.55)
          ..blendMode = BlendMode.plus,
      );
      canvas.drawPath(
        rim.path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6
          ..shader = gradient(0.95)
          ..blendMode = BlendMode.plus,
      );
      canvas.save();
      canvas.clipPath(rim.path);
      canvas.drawRect(
        Offset.zero & size,
        Paint()
          ..shader = gradient(0.16)
          ..blendMode = BlendMode.plus,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _SpillPainter oldDelegate) =>
      oldDelegate.field != field ||
      oldDelegate.rect != rect ||
      oldDelegate.shape != shape;
}

/// A small glass sphere with a warm light inside it.
class _Orb extends StatelessWidget {
  const _Orb({required this.backdrop});

  final Backdrop backdrop;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: <Widget>[
        // The light it throws on the page around it.
        Positioned.fill(
          child: IgnorePointer(child: CustomPaint(painter: _OrbHaloPainter())),
        ),
        Positioned.fill(
          child: DrawBackdrop(
            backdrop: backdrop,
            shape: () => const Capsule(),
            effects: (BackdropEffectScope scope) => scope
              ..vibrancy()
              ..blur(3)
              ..lens(14, 22),
            onDrawSurface: (Canvas canvas, Size size) {
              final Offset c = size.center(Offset.zero);
              canvas.drawCircle(
                c,
                size.shortestSide / 2,
                Paint()
                  ..shader = ui.Gradient.radial(
                    c,
                    size.shortestSide / 2,
                    const <Color>[
                      Color(0xF2FFF4DE),
                      Color(0x99FFD08A),
                      Color(0x33FFB060),
                    ],
                    const <double>[0, 0.45, 1],
                  ),
              );
            },
            child: const SizedBox.expand(),
          ),
        ),
      ],
    );
  }
}

class _OrbHaloPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final Offset c = size.center(Offset.zero);
    canvas.drawCircle(
      c,
      size.shortestSide * 0.9,
      Paint()
        ..color = const Color(0xFFFFC878).withValues(alpha: 0.35)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 22)
        ..blendMode = BlendMode.plus,
    );
  }

  @override
  bool shouldRepaint(covariant _OrbHaloPainter oldDelegate) => false;
}
