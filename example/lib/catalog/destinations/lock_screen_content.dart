import 'package:fluid_glass/fluid_glass.dart';
import 'package:flutter/material.dart';

import '../backdrop_demo_scaffold.dart';
import '../utils/sdf_shader.dart';

/// A lock-screen clock cut out of glass by a signed-distance-field texture.
class LockScreenContent extends StatefulWidget {
  const LockScreenContent({super.key});

  @override
  State<LockScreenContent> createState() => _LockScreenContentState();
}

class _LockScreenContentState extends State<LockScreenContent> {
  final SdfShaderSource _sdf = SdfShaderSource('assets/clock_sdf.webp');
  Offset _offset = Offset.zero;

  @override
  void dispose() {
    _sdf.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BackdropDemoScaffold(
      builder: (BuildContext context, LayerBackdrop backdrop) {
        return <Widget>[
          Positioned.fill(
            child: ColoredBox(
              color: const Color(0xFF000000).withValues(alpha: 0.3),
              child: Column(
                children: <Widget>[
                  Expanded(
                    child: Center(
                      // The translation wraps the padding, not the other way
                      // round: Flutter bounds-checks every ancestor, so a clock
                      // dragged past the padded box would stop being grabbable.

                      child: Transform.translate(
                        offset: _offset,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 48),
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onPanUpdate: (DragUpdateDetails details) =>
                                setState(() => _offset += details.delta),
                            child: ListenableBuilder(
                              listenable: _sdf,
                              builder: (BuildContext context, Widget? _) {
                                return ConstrainedBox(
                                  constraints: const BoxConstraints(
                                    maxWidth: 400,
                                  ),
                                  child: AspectRatio(
                                    aspectRatio: _sdf.width / _sdf.height,
                                    child: DrawBackdrop.plain(
                                      backdrop: backdrop,
                                      shape: () => const Rectangle(),
                                      effects: (BackdropEffectScope scope) {
                                        scope
                                          ..colorControls(
                                            brightness: -0.1,
                                            contrast: 0.75,
                                            saturation: 1.5,
                                          )
                                          ..blur(2);
                                        _sdf.apply(scope);
                                      },
                                      onDrawBackdrop:
                                          (
                                            BackdropDrawContext context,
                                            void Function() drawBackdrop,
                                          ) {
                                            drawBackdrop();
                                            context.canvas.drawRect(
                                              Offset.zero & context.size,
                                              Paint()
                                                ..color = const Color(
                                                  0xFFFFFFFF,
                                                ).withValues(alpha: 0.25),
                                            );
                                          },
                                      repaint: _sdf,
                                      child: const SizedBox.expand(),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const Expanded(child: SizedBox.expand()),
                ],
              ),
            ),
          ),
        ];
      },
    );
  }
}
