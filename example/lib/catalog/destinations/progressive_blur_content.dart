import 'dart:ui' as ui;

import 'package:fluid_glass/fluid_glass.dart';
import 'package:flutter/material.dart';

import '../backdrop_demo_scaffold.dart';
import '../utils/demo_shaders.dart';

class ProgressiveBlurContent extends StatelessWidget {
  const ProgressiveBlurContent({super.key});

  @override
  Widget build(BuildContext context) {
    final bool isLight = Theme.of(context).brightness == Brightness.light;
    final Color contentColor =
        isLight ? const Color(0xFF000000) : const Color(0xFFFFFFFF);
    final Color tintColor =
        isLight ? const Color(0xFFFFFFFF) : const Color(0xFF808080);

    return BackdropDemoScaffold(
      builder: (BuildContext context, LayerBackdrop backdrop) {
        return <Widget>[
          Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          spacing: 16,
          children: <Widget>[
            DrawBackdrop.plain(
              backdrop: backdrop,
              shape: () => const Rectangle(),
              effects: (BackdropEffectScope scope) {
                scope.blur(4);
                scope.fragmentShaderEffect(
                  'AlphaMask',
                  DemoShaders.instance.progressiveBlur,
                  (ui.FragmentShader shader, BackdropEffectGeometry geometry) {
                    shader
                      ..setFloat(0, 0)
                      ..setFloat(1, 0)
                      ..setFloat(2, geometry.layerSize.width)
                      ..setFloat(3, geometry.layerSize.height)
                      ..setFloat(4, geometry.size.width)
                      ..setFloat(5, geometry.size.height)
                      ..setFloat(6, tintColor.r)
                      ..setFloat(7, tintColor.g)
                      ..setFloat(8, tintColor.b)
                      ..setFloat(9, tintColor.a)
                      ..setFloat(10, 0.8);
                  },
                );
              },
              repaint: DemoShaders.instance,
              child: SizedBox(
                height: 128,
                width: double.infinity,
                child: Center(
                  child: Text(
                    'alpha-masked progressive blur',
                    style: TextStyle(color: contentColor, fontSize: 16),
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
