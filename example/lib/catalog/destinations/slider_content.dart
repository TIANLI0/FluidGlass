import 'package:fluid_glass/fluid_glass.dart';
import 'package:flutter/material.dart';

import '../backdrop_demo_scaffold.dart';
import '../components/liquid_slider.dart';

class SliderContent extends StatefulWidget {
  const SliderContent({super.key});

  @override
  State<SliderContent> createState() => _SliderContentState();
}

class _SliderContentState extends State<SliderContent> {
  double _value = 50;

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
              child: LiquidSlider(
                value: _value,
                onValueChanged: (double value) => setState(() => _value = value),
                valueRange: (start: 0, end: 100),
                visibilityThreshold: 0.01,
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
                    child: LiquidSlider(
                      value: _value,
                      onValueChanged: (double value) =>
                          setState(() => _value = value),
                      valueRange: (start: 0, end: 100),
                      visibilityThreshold: 0.01,
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
