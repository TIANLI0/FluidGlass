import 'package:fluid_glass/fluid_glass.dart';
import 'package:flutter/material.dart';

import '../backdrop_demo_scaffold.dart';
import '../components/liquid_toggle.dart';

class ToggleContent extends StatefulWidget {
  const ToggleContent({super.key});

  @override
  State<ToggleContent> createState() => _ToggleContentState();
}

class _ToggleContentState extends State<ToggleContent> {
  bool _selected = false;

  @override
  Widget build(BuildContext context) {
    final bool isLight = Theme.of(context).brightness == Brightness.light;
    final Color backgroundColor =
        isLight ? const Color(0xFFFFFFFF) : const Color(0xFF121212);

    return BackdropDemoScaffold(
      builder: (BuildContext context, LayerBackdrop backdrop) {
        return <Widget>[
          Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          spacing: 16,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: LiquidToggle(
                selected: _selected,
                onSelect: (bool value) => setState(() => _selected = value),
                backdrop: backdrop,
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: ClipPath(
                clipper: const GlassShapeClipper(RoundedRectangle(32)),
                child: ColoredBox(
                  color: backgroundColor,
                  child: Padding(
                    padding: const EdgeInsets.all(24) +
                        const EdgeInsets.symmetric(horizontal: 32),
                    child: LiquidToggle(
                      selected: _selected,
                      onSelect: (bool value) =>
                          setState(() => _selected = value),
                      backdrop: CanvasBackdrop(
                        (Canvas canvas, Size size) => canvas.drawRect(
                          Offset.zero & size,
                          Paint()..color = backgroundColor,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
          ),
        ];
      },
    );
  }
}
