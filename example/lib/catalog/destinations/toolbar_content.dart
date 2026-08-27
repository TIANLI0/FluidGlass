import 'package:fluid_glass/fluid_glass.dart';
import 'package:flutter/material.dart';

import '../backdrop_demo_scaffold.dart';

/// Button groups, a segmented control, and the standalone [LiquidPanel] they
/// are all built from.
class ToolbarContent extends StatefulWidget {
  const ToolbarContent({super.key});

  @override
  State<ToolbarContent> createState() => _ToolbarContentState();
}

class _ToolbarContentState extends State<ToolbarContent>
    with TickerProviderStateMixin {
  int _range = 0;
  String _lastAction = 'Nothing yet';

  late final SpringValue _reveal = SpringValue(
    vsync: this,
    value: 1,
    visibilityThreshold: 0.001,
  );

  @override
  void dispose() {
    _reveal.dispose();
    super.dispose();
  }

  void _replayReveal() {
    _reveal.snapTo(0);
    _reveal.animateTo(1.0, springOf(0.75, 420.0));
  }

  void _did(String what) => setState(() => _lastAction = what);

  @override
  Widget build(BuildContext context) {
    final bool isLight = Theme.of(context).brightness == Brightness.light;
    final Color contentColor =
        isLight ? const Color(0xFF000000) : const Color(0xFFFFFFFF);

    return BackdropDemoScaffold(
      builder: (BuildContext context, LayerBackdrop backdrop) {
        return <Widget>[
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              spacing: 28,
              children: <Widget>[
                // A browser-style toolbar: a back/forward cluster on the
                // left, a share/more cluster on the right.
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    LiquidButtonGroup(
                      backdrop: backdrop,
                      actions: <LiquidGroupAction>[
                        LiquidGroupAction(
                          icon: Icons.arrow_back_ios_new,
                          onPressed: () => _did('Back'),
                        ),
                        LiquidGroupAction(
                          icon: Icons.arrow_forward_ios,
                          onPressed: () => _did('Forward'),
                        ),
                      ],
                    ),
                    LiquidButtonGroup(
                      backdrop: backdrop,
                      actions: <LiquidGroupAction>[
                        LiquidGroupAction(
                          icon: Icons.ios_share,
                          onPressed: () => _did('Share'),
                        ),
                        LiquidGroupAction(
                          icon: Icons.more_horiz,
                          onPressed: () => _did('More'),
                        ),
                      ],
                    ),
                  ],
                ),

                // A back cluster with a label, the navigation-bar idiom.
                Align(
                  alignment: Alignment.centerLeft,
                  child: LiquidButtonGroup(
                    backdrop: backdrop,
                    actions: <LiquidGroupAction>[
                      LiquidGroupAction(
                        icon: Icons.arrow_back_ios_new,
                        label: 'Library',
                        onPressed: () => _did('Library'),
                      ),
                    ],
                  ),
                ),

                Text(
                  'Last action: $_lastAction',
                  style: TextStyle(
                    color: contentColor.withValues(alpha: 0.68),
                    fontSize: 15,
                  ),
                ),

                LiquidSegmentedControl(
                  selectedIndex: _range,
                  onSelected: (int index) => setState(() => _range = index),
                  backdrop: backdrop,
                  segments: const <Widget>[
                    Text('Day'),
                    Text('Week'),
                    Text('Month'),
                  ],
                ),

                // The panel on its own: everything above is built from this.
                LiquidPanel(
                  backdrop: backdrop,
                  reveal: () => _reveal.value.clamp(0.0, 1.0),
                  repaint: _reveal,
                  child: SizedBox(
                    width: double.infinity,
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        spacing: 8,
                        children: <Widget>[
                          Text(
                            'LiquidPanel',
                            style: TextStyle(
                              color: contentColor,
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            'The bare glass surface the menu opens into — '
                            'refraction, rim and shadow ride the reveal '
                            'spring. Host anything in it.',
                            style: TextStyle(
                              color: contentColor.withValues(alpha: 0.68),
                              fontSize: 14,
                            ),
                          ),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: _replayReveal,
                              style: TextButton.styleFrom(
                                foregroundColor: const Color(0xFF0088FF),
                              ),
                              child: const Text('Replay reveal'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
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
