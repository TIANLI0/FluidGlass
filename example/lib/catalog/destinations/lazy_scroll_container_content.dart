import 'package:fluid_glass/fluid_glass.dart';
import 'package:flutter/material.dart';

import '../backdrop_demo_scaffold.dart';

class LazyScrollContainerContent extends StatelessWidget {
  const LazyScrollContainerContent({super.key});

  @override
  Widget build(BuildContext context) {
    return BackdropDemoScaffold(
      builder: (BuildContext context, LayerBackdrop backdrop) {
        final EdgeInsets insets = MediaQuery.paddingOf(context);
        return <Widget>[
          Positioned.fill(
            child: ListView.separated(
              // Glass has to repaint as it scrolls, since what it refracts
              // depends on where it sits. A per-item repaint boundary would
              // only re-offset the item's layer and freeze the refraction.
              addRepaintBoundaries: false,
          padding: const EdgeInsets.all(16) +
              EdgeInsets.only(top: insets.top, bottom: insets.bottom),
          itemCount: 100,
          separatorBuilder: (BuildContext context, int index) =>
              const SizedBox(height: 16),
          itemBuilder: (BuildContext context, int index) {
            return DrawBackdrop(
              backdrop: backdrop,
              shape: () => const RoundedRectangle(32),
              effects: (BackdropEffectScope scope) => scope
                ..vibrancy()
                ..lens(16, 32),
              child: const SizedBox(height: 160, width: double.infinity),
            );
          },
            ),
          ),
        ];
      },
    );
  }
}
