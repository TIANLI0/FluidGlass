import 'package:fluid_glass/fluid_glass.dart';
import 'package:flutter/material.dart';

import '../backdrop_demo_scaffold.dart';
import '../components/liquid_button.dart';

class ButtonsContent extends StatelessWidget {
  const ButtonsContent({super.key});

  @override
  Widget build(BuildContext context) {
    return BackdropDemoScaffold(
      builder: (BuildContext context, LayerBackdrop backdrop) {
        return <Widget>[
          Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          spacing: 16,
          children: <Widget>[
            LiquidButton(
              onPressed: () {},
              backdrop: backdrop,
              children: const <Widget>[
                Text(
                  'Transparent Liquid Button',
                  style: TextStyle(color: Color(0xFF000000), fontSize: 15),
                ),
              ],
            ),
            LiquidButton(
              onPressed: () {},
              backdrop: backdrop,
              surfaceColor: const Color(0xFFFFFFFF).withValues(alpha: 0.3),
              children: const <Widget>[
                Text(
                  'Surface Liquid Button',
                  style: TextStyle(color: Color(0xFF000000), fontSize: 15),
                ),
              ],
            ),
            LiquidButton(
              onPressed: () {},
              backdrop: backdrop,
              tint: const Color(0xFF0088FF),
              children: const <Widget>[
                Text(
                  'Tinted Liquid Button',
                  style: TextStyle(color: Color(0xFFFFFFFF), fontSize: 15),
                ),
              ],
            ),
            LiquidButton(
              onPressed: () {},
              backdrop: backdrop,
              tint: const Color(0xFFFF8D28),
              children: const <Widget>[
                Text(
                  'Tinted Liquid Button',
                  style: TextStyle(color: Color(0xFFFFFFFF), fontSize: 15),
                ),
              ],
            ),
          ],
          ),
        ];
      },
    );
  }
}
