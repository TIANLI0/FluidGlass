import 'package:fluid_glass/fluid_glass.dart';
import 'package:flutter/material.dart';

import '../backdrop_demo_scaffold.dart';

class ScrollContainerContent extends StatelessWidget {
  const ScrollContainerContent({super.key});

  @override
  Widget build(BuildContext context) {
    return BackdropDemoScaffold(
      builder: (BuildContext context, LayerBackdrop backdrop) {
        return <Widget>[
          Positioned.fill(
            child: SingleChildScrollView(
          padding: const EdgeInsets.all(16) +
              EdgeInsets.only(
                top: MediaQuery.paddingOf(context).top,
                bottom: MediaQuery.paddingOf(context).bottom,
              ),
          child: Column(
            spacing: 16,
            children: <Widget>[
              for (int i = 0; i < 20; i++)
                DrawBackdrop(
                  backdrop: backdrop,
                  shape: () => const RoundedRectangle(32),
                  effects: (BackdropEffectScope scope) => scope
                    ..vibrancy()
                    ..lens(16, 32),
                  child: const SizedBox(height: 160, width: double.infinity),
                ),
            ],
          ),
            ),
          ),
        ];
      },
    );
  }
}
