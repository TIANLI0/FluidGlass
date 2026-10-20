import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:fluid_glass/fluid_glass.dart';
import 'package:flutter/material.dart';

import '../backdrop_demo_scaffold.dart';

/// Corner radii, as the shaders read them: today's, against a one-line fix.
///
/// The refraction and the rim's shading look up each fragment's corner radius
/// with `radiusAt`, which picks a corner by the quadrant a coordinate is in —
/// and is handed the layer coordinate, which is never negative. Every fragment
/// but the top row reads as the bottom-right quadrant, so every corner gets the
/// bottom-right radius. With four equal corners that is invisible; with uneven
/// ones — a sheet rounded only at the top, a bar rounded only at the bottom —
/// the lens and the rim follow the wrong outline.
///
/// Left is the library as it ships. Right is the same shaders with `radiusAt`
/// handed the centred coordinate, loaded from this example's own copies; the
/// library itself is untouched. The last row has four equal corners, and must
/// look the same on both sides.
class LabCornerRadiiContent extends StatefulWidget {
  const LabCornerRadiiContent({super.key});

  @override
  State<LabCornerRadiiContent> createState() => _LabCornerRadiiContentState();
}

class _LabCornerRadiiContentState extends State<LabCornerRadiiContent> {
  ui.FragmentProgram? _refraction;
  ui.FragmentProgram? _highlight;
  bool _showRim = true;
  bool _showLens = true;

  static final List<(String, RoundedRectangularShape)> _cases =
      <(String, RoundedRectangularShape)>[
        (
          'Sheet — rounded top only',
          UnevenRoundedRectangle.only(topStart: 40, topEnd: 40),
        ),
        (
          'Bar — rounded bottom only',
          UnevenRoundedRectangle.only(bottomStart: 32, bottomEnd: 32),
        ),
        ('One round corner', UnevenRoundedRectangle.only(topStart: 52)),
        ('Control — four equal corners', const RoundedRectangle(32)),
      ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final List<ui.FragmentProgram> programs =
        await Future.wait(<Future<ui.FragmentProgram>>[
          ui.FragmentProgram.fromAsset('shaders/lab_refraction_centered.frag'),
          ui.FragmentProgram.fromAsset('shaders/lab_highlight_centered.frag'),
        ]);
    if (!mounted) return;
    setState(() {
      _refraction = programs[0];
      _highlight = programs[1];
    });
  }

  @override
  Widget build(BuildContext context) {
    // Pinned: the emulator has too few cores for the liquid tier, and the
    // plain tier draws neither the lens nor the shaded rim being compared.
    return GlassQualityScope(
      quality: GlassQuality.liquid,
      child: BackdropDemoScaffold(
        decorate: (Widget wallpaper) => Stack(
          fit: StackFit.expand,
          children: <Widget>[
            wallpaper,
            // A grid, so a bend in what the glass shows is a bend in a line.
            const CustomPaint(painter: _GridPainter()),
          ],
        ),
        builder: (BuildContext context, LayerBackdrop backdrop) => <Widget>[
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 64, 16, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  const _Caption(
                    'Left: the library today. Right: radiusAt given the '
                    'centred coordinate. The last row must match.',
                  ),
                  Row(
                    children: <Widget>[
                      _Switch(
                        label: 'Lens',
                        value: _showLens,
                        onChanged: (bool v) => setState(() => _showLens = v),
                      ),
                      _Switch(
                        label: 'Rim',
                        value: _showRim,
                        onChanged: (bool v) => setState(() => _showRim = v),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  for (final (String label, RoundedRectangularShape shape)
                      in _cases) ...<Widget>[
                    _Caption(label),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: _Tile(
                            backdrop: backdrop,
                            shape: shape,
                            refraction: null,
                            highlight: null,
                            showLens: _showLens,
                            showRim: _showRim,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _Tile(
                            backdrop: backdrop,
                            shape: shape,
                            refraction: _refraction,
                            highlight: _highlight,
                            showLens: _showLens,
                            showRim: _showRim,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// One piece of glass. With [refraction] and [highlight] null it draws the
/// library's own lens and rim; given the lab's programs, the fixed ones, with
/// exactly the uniforms the library writes.
class _Tile extends StatelessWidget {
  const _Tile({
    required this.backdrop,
    required this.shape,
    required this.refraction,
    required this.highlight,
    required this.showLens,
    required this.showRim,
  });

  final Backdrop backdrop;
  final RoundedRectangularShape shape;
  final ui.FragmentProgram? refraction;
  final ui.FragmentProgram? highlight;
  final bool showLens;
  final bool showRim;

  static const double _height = 28;
  static const double _amount = 44;

  bool get _fixed => refraction != null;

  @override
  Widget build(BuildContext context) {
    // Wider and brighter than a real rim, so its shading is easy to read.
    const DefaultHighlightStyle rimStyle = DefaultHighlightStyle(
      color: Color(0xE6FFFFFF),
    );
    final HighlightStyle style = _fixed && highlight != null
        ? _CenteredHighlightStyle(highlight!, rimStyle)
        : rimStyle;
    return SizedBox(
      height: 120,
      child: DrawBackdrop(
        backdrop: backdrop,
        shape: () => shape,
        effects: (BackdropEffectScope scope) {
          scope.blur(1);
          if (!showLens) return;
          if (!_fixed) {
            scope.lens(_height, _amount);
            return;
          }
          final RectangleCorners corners = scope.shape.corners(
            scope.size,
            scope.textDirection,
          );
          if (scope.padding > 0) {
            scope.padding = math.max(0.0, scope.padding - _height);
          }
          scope.fragmentShaderEffect('LabRefraction', refraction, (
            ui.FragmentShader shader,
            BackdropEffectGeometry geometry,
          ) {
            final Size layer = geometry.layerSize;
            final Offset offset = geometry.offset;
            shader
              ..setFloat(0, 0)
              ..setFloat(1, 0)
              ..setFloat(2, layer.width)
              ..setFloat(3, layer.height)
              ..setFloat(4, geometry.size.width)
              ..setFloat(5, geometry.size.height)
              ..setFloat(6, offset.dx)
              ..setFloat(7, offset.dy)
              ..setFloat(8, corners.topLeft)
              ..setFloat(9, corners.topRight)
              ..setFloat(10, corners.bottomRight)
              ..setFloat(11, corners.bottomLeft)
              ..setFloat(12, _height)
              ..setFloat(13, -_amount)
              ..setFloat(14, 0);
          });
        },
        highlight: showRim
            ? () => Highlight(width: 2, blurRadius: 0.5, style: style)
            : null,
        shadow: null,
        onDrawSurface: (Canvas canvas, Size size) => canvas.drawRect(
          Offset.zero & size,
          Paint()..color = const Color(0x1AFFFFFF),
        ),
        child: const SizedBox.expand(),
      ),
    );
  }
}

/// [DefaultHighlightStyle], through the lab's fixed copy of its shader.
class _CenteredHighlightStyle extends HighlightStyle {
  const _CenteredHighlightStyle(this.program, this.base);

  final ui.FragmentProgram program;
  final DefaultHighlightStyle base;

  @override
  Color get color => base.color;

  @override
  BlendMode get blendMode => base.blendMode;

  @override
  ui.FragmentShader? createShader({
    required Size size,
    required RectangleCorners corners,
    required Offset origin,
    required FragmentShaderCache cache,
  }) {
    final ui.FragmentShader shader = cache.obtain('LabHighlight', program);
    final Color c = base.color;
    return shader
      ..setFloat(0, size.width)
      ..setFloat(1, size.height)
      ..setFloat(2, origin.dx)
      ..setFloat(3, origin.dy)
      ..setFloat(4, corners.topLeft)
      ..setFloat(5, corners.topRight)
      ..setFloat(6, corners.bottomRight)
      ..setFloat(7, corners.bottomLeft)
      ..setFloat(8, c.r)
      ..setFloat(9, c.g)
      ..setFloat(10, c.b)
      ..setFloat(11, c.a)
      ..setFloat(12, base.angle * math.pi / 180.0)
      ..setFloat(13, base.falloff);
  }

  @override
  bool operator ==(Object other) =>
      other is _CenteredHighlightStyle &&
      identical(other.program, program) &&
      other.base == base;

  @override
  int get hashCode => Object.hash(program, base);
}

class _GridPainter extends CustomPainter {
  const _GridPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final Paint line = Paint()
      ..color = const Color(0x66000000)
      ..strokeWidth = 1;
    for (double x = 0; x < size.width; x += 16) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), line);
    }
    for (double y = 0; y < size.height; y += 16) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), line);
    }
  }

  @override
  bool shouldRepaint(covariant _GridPainter oldDelegate) => false;
}

class _Caption extends StatelessWidget {
  const _Caption(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xCC000000),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Text(
            text,
            style: const TextStyle(color: Colors.white, fontSize: 13),
          ),
        ),
      ),
    );
  }
}

class _Switch extends StatelessWidget {
  const _Switch({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 16),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xCC000000),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const SizedBox(width: 12),
            Text(label, style: const TextStyle(color: Colors.white)),
            Switch(value: value, onChanged: onChanged),
          ],
        ),
      ),
    );
  }
}
