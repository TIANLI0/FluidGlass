import 'package:fluid_glass/fluid_glass.dart';
import 'package:flutter/material.dart';

import '../backdrop_demo_scaffold.dart';

/// Drag the shapes across each other: they fuse like droplets.
///
/// What makes this a droplet rather than two shapes overlapping is that the
/// silhouette is a *field*, not an outline. Each shape contributes a signed
/// distance, the shader takes their smooth minimum, and the result bulges
/// towards its neighbour before the two touch — so they reach for each other,
/// grow a concave neck, and only then become one body. A union of two paths
/// would do none of that; it would just be two shapes with the seam hidden.
///
/// [LiquidFusion.smoothing] is how far apart that reaching starts. At zero it
/// is a plain union: nothing happens until the outlines actually cross.
///
/// The light follows the same rule. Hold a shape and the glow stays in the
/// body your finger is in: drag two together and it travels through the neck
/// into the other one; leave them apart and it stops at the gap, because a
/// shape you have not reached is not the one being held.
///
/// The whole group is one glass element — one capture of the backdrop, one
/// shader pass — so three fused shapes cost what one costs, not three.
class FusionContent extends StatefulWidget {
  const FusionContent({super.key});

  @override
  State<FusionContent> createState() => _FusionContentState();
}

class _FusionContentState extends State<FusionContent> {
  static const List<Size> _sizes = <Size>[
    Size(96, 96),
    Size(96, 96),
    Size(148, 76),
  ];
  static const List<(IconData, String)> _faces = <(IconData, String)>[
    (Icons.play_arrow_rounded, 'Play'),
    (Icons.favorite_rounded, 'Like'),
    (Icons.graphic_eq_rounded, 'Levels'),
  ];

  List<Offset>? _centers;
  double _smoothing = 10;

  /// Which shape is under the finger, and where the finger is.
  int? _held;
  Offset _finger = Offset.zero;

  /// Laid out the first time the box is measured, then owned by the finger.
  void _seed(Size box) {
    if (_centers != null) return;
    final double x = box.width / 2;
    final double y = box.height / 2;
    _centers = <Offset>[
      Offset(x - 58, y - 70),
      Offset(x + 58, y - 70),
      Offset(x, y + 90),
    ];
  }

  Rect _rectOf(int index) => Rect.fromCenter(
    center: _centers![index],
    width: _sizes[index].width,
    height: _sizes[index].height,
  );

  @override
  Widget build(BuildContext context) {
    return BackdropDemoScaffold(
      builder: (BuildContext context, LayerBackdrop backdrop) {
        return <Widget>[
          Positioned.fill(
            child: LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                final Size box = constraints.biggest;
                _seed(box);
                return LiquidFusion(
                  backdrop: backdrop,
                  smoothing: _smoothing,
                  blobs: <LiquidBlob>[
                    for (int i = 0; i < _sizes.length; i++)
                      LiquidBlob(_rectOf(i)),
                  ],
                  press: _held == null
                      ? null
                      : LiquidFusionPress(
                          position: _finger,
                          progress: 1,
                          radius: _sizes[_held!].shortestSide * 1.5,
                        ),
                  children: <Widget>[
                    for (int i = 0; i < _sizes.length; i++)
                      Positioned.fromRect(
                        rect: _rectOf(i),
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onPanStart: (DragStartDetails details) =>
                              setState(() {
                                _held = i;
                                _finger =
                                    details.localPosition + _rectOf(i).topLeft;
                              }),
                          onPanUpdate: (DragUpdateDetails details) =>
                              setState(() {
                                _centers![i] += details.delta;
                                _finger += details.delta;
                              }),
                          onPanEnd: (_) => setState(() => _held = null),
                          onPanCancel: () => setState(() => _held = null),
                          child: _Face(
                            icon: _faces[i].$1,
                            label: _faces[i].$2,
                            held: _held == i,
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
          Align(
            alignment: Alignment.topCenter,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 56, 16, 0),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: _Smoothing(
                    backdrop: backdrop,
                    value: _smoothing,
                    onChanged: (double value) =>
                        setState(() => _smoothing = value),
                  ),
                ),
              ),
            ),
          ),
        ];
      },
    );
  }
}

/// What sits on a shape. Not glass itself — the glass is one element behind all
/// three, so a face is just an icon that happens to be over it.
class _Face extends StatelessWidget {
  const _Face({required this.icon, required this.label, required this.held});

  final IconData icon;
  final String label;
  final bool held;

  @override
  Widget build(BuildContext context) {
    final Color content = LiquidGlassTheme.of(context).content;
    return AnimatedScale(
      scale: held ? 0.94 : 1,
      duration: const Duration(milliseconds: 140),
      curve: Curves.easeOut,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        spacing: 2,
        children: <Widget>[
          Icon(icon, size: 26, color: content),
          Text(
            label,
            style: TextStyle(
              color: content.withValues(alpha: 0.75),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _Smoothing extends StatelessWidget {
  const _Smoothing({
    required this.backdrop,
    required this.value,
    required this.onChanged,
  });

  final Backdrop backdrop;
  final double value;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final Color content = LiquidGlassTheme.of(context).content;
    return LiquidPanel(
      backdrop: backdrop,
      shape: const RoundedRectangle(22),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 6,
          children: <Widget>[
            Text(
              'Drag two together: they merge, and the glow travels through the '
              'neck.',
              style: TextStyle(color: content, fontSize: 13),
            ),
            Text(
              'smoothing ${value.round()} — how far apart they reach for each '
              'other.',
              style: TextStyle(
                color: content.withValues(alpha: 0.6),
                fontSize: 12,
              ),
            ),
            SizedBox(
              height: 28,
              child: LiquidSlider(
                value: value,
                onValueChanged: onChanged,
                valueRange: (start: 0, end: 40),
                visibilityThreshold: 0.5,
                backdrop: backdrop,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
