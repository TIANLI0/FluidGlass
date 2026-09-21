import 'package:fluid_glass/fluid_glass.dart';
import 'package:flutter/material.dart';

import '../backdrop_demo_scaffold.dart';

/// The three ways to get the press glow, from lowest level to highest.
///
/// All three draw the same thing — a soft radial glow that springs to the
/// finger plus a flat brighten — and they differ only in how much you have to
/// wire up:
///
///  * [InteractiveHighlight] is the controller. You own the surface and call
///    `wrapGestures` / `wrapOverlay` around it. This is what a custom control
///    uses, and what `LiquidBottomTabs` drives by hand.
///  * [LiquidInteraction] is that controller already wired to a pointer, with
///    a rounded clip and a selected tint. This is the one for menu rows and
///    list tiles.
///  * [LiquidInkHighlight] is a `splashFactory`. Install it once in
///    [ThemeData] and every ordinary Material control gets the same feedback
///    without being wrapped at all — which is how a glass app keeps its
///    Material widgets from feeling like a different toolkit.
class HighlightContent extends StatefulWidget {
  const HighlightContent({super.key});

  @override
  State<HighlightContent> createState() => _HighlightContentState();
}

class _HighlightContentState extends State<HighlightContent>
    with TickerProviderStateMixin {
  late final InteractiveHighlight _highlight = InteractiveHighlight(
    vsync: this,
  );
  int _taps = 0;
  int _selectedRow = 0;

  @override
  void dispose() {
    _highlight.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isLight = Theme.of(context).brightness == Brightness.light;
    final Color contentColor = isLight
        ? const Color(0xFF000000)
        : const Color(0xFFFFFFFF);
    final TextStyle label = TextStyle(color: contentColor, fontSize: 15);
    final TextStyle caption = TextStyle(
      color: contentColor.withValues(alpha: 0.6),
      fontSize: 12,
    );

    return BackdropDemoScaffold(
      builder: (BuildContext context, LayerBackdrop backdrop) {
        return <Widget>[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 28,
              children: <Widget>[
                // 1. The controller, driving a surface you own. Drag across
                //    it: the glow follows the finger rather than sitting where
                //    it landed.
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 6,
                  children: <Widget>[
                    Text('InteractiveHighlight — $_taps taps', style: caption),
                    _highlight.wrapGestures(
                      onTap: () => setState(() => _taps++),
                      child: LiquidPanel(
                        backdrop: backdrop,
                        shape: const RoundedRectangle(28),
                        child: ClipPath(
                          clipper: const GlassShapeClipper(
                            RoundedRectangle(28),
                          ),
                          child: _highlight.wrapOverlay(
                            child: SizedBox(
                              height: 88,
                              child: Center(
                                child: Text('press and drag', style: label),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                // 2. The same thing already wired, as rows.
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 6,
                  children: <Widget>[
                    Text('LiquidInteraction — rows', style: caption),
                    LiquidPanel(
                      backdrop: backdrop,
                      shape: const RoundedRectangle(28),
                      child: ClipPath(
                        clipper: const GlassShapeClipper(RoundedRectangle(28)),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            for (int i = 0; i < 3; i++)
                              LiquidInteraction(
                                selected: _selectedRow == i,
                                borderRadius: BorderRadius.zero,
                                child: GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onTap: () => setState(() => _selectedRow = i),
                                  child: SizedBox(
                                    height: 52,
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 20,
                                      ),
                                      child: Row(
                                        children: <Widget>[
                                          Text('Row ${i + 1}', style: label),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),

                // 3. The splash factory: plain Material widgets, no wrapping,
                //    same feedback.
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 6,
                  children: <Widget>[
                    Text(
                      'LiquidInkHighlight — unwrapped Material widgets',
                      style: caption,
                    ),
                    Theme(
                      data: Theme.of(context).copyWith(
                        splashFactory: LiquidInkHighlight.splashFactory,
                      ),
                      child: LiquidPanel(
                        backdrop: backdrop,
                        shape: const RoundedRectangle(28),
                        child: ClipPath(
                          clipper: const GlassShapeClipper(
                            RoundedRectangle(28),
                          ),
                          child: Material(
                            type: MaterialType.transparency,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: <Widget>[
                                TextButton(
                                  onPressed: () {},
                                  child: Text('Text', style: label),
                                ),
                                IconButton(
                                  onPressed: () {},
                                  icon: Icon(
                                    Icons.favorite,
                                    color: contentColor,
                                  ),
                                ),
                                InkWell(
                                  onTap: () {},
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 12,
                                    ),
                                    child: Text('InkWell', style: label),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ];
      },
    );
  }
}
