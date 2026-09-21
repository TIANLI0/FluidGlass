import 'package:fluid_glass/fluid_glass.dart';
import 'package:flutter/material.dart';

import '../backdrop_demo_scaffold.dart';

/// [LiquidSheet], on both of the backdrops a sheet can have.
///
/// The sheet pinned to the bottom of the page is on a [LayerBackdrop], so it
/// refracts — and the dim has to be *inside* what that layer captures, which
/// is what [BackdropDemoScaffold.decorate] is doing. The button opens the same
/// widget as a real modal route on [nativeBackdrop]: no capture, the dim comes
/// free with the barrier, and no refraction to show for it.
///
/// The pairing is the point. A sheet is the one surface where the cheap path
/// is also the right one — it sits *over* what it filters, and it carries
/// enough tint that the refraction would not have been visible anyway.
class SheetContent extends StatefulWidget {
  const SheetContent({super.key});

  @override
  State<SheetContent> createState() => _SheetContentState();
}

class _SheetContentState extends State<SheetContent> {
  String _quality = 'Automatic';

  List<LiquidSheetItem> _items() => <LiquidSheetItem>[
    LiquidSheetItem(
      label: 'Automatic',
      detail: 'Follows the device tier',
      isSelected: _quality == 'Automatic',
      onSelected: () => setState(() => _quality = 'Automatic'),
    ),
    LiquidSheetItem(
      label: 'Liquid',
      detail: 'Refraction, shaded rim, blur',
      isSelected: _quality == 'Liquid',
      onSelected: () => setState(() => _quality = 'Liquid'),
    ),
    LiquidSheetItem(
      label: 'Plain',
      detail: 'A Gaussian blur behind the tint',
      isSelected: _quality == 'Plain',
      onSelected: () => setState(() => _quality = 'Plain'),
    ),
    LiquidSheetItem(
      label: 'Reset',
      isDestructive: true,
      onSelected: () => setState(() => _quality = 'Automatic'),
    ),
  ];

  Future<void> _openModal(BuildContext context) async {
    await showLiquidSheet<void>(
      context: context,
      // The sheet is over the page, so the compositor can filter it in place.
      backdrop: nativeBackdrop,
      title: 'Glass quality',
      items: _items(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isLight = Theme.of(context).brightness == Brightness.light;
    final Color contentColor = isLight
        ? const Color(0xFF000000)
        : const Color(0xFFFFFFFF);
    final Color dimColor = isLight
        ? const Color(0xFF29293A).withValues(alpha: 0.23)
        : const Color(0xFF121212).withValues(alpha: 0.56);

    return BackdropDemoScaffold(
      // The dim sits inside the captured wallpaper, so the sheet refracts it.
      decorate: (Widget wallpaper) => Stack(
        fit: StackFit.expand,
        children: <Widget>[
          wallpaper,
          ColoredBox(color: dimColor),
        ],
      ),
      builder: (BuildContext context, LayerBackdrop backdrop) {
        return <Widget>[
          Align(
            alignment: Alignment.topCenter,
            child: Padding(
              padding: const EdgeInsets.only(top: 96),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                spacing: 20,
                children: <Widget>[
                  Text(
                    'Chosen: $_quality',
                    style: TextStyle(color: contentColor, fontSize: 16),
                  ),
                  Builder(
                    builder: (BuildContext context) => LiquidButton(
                      backdrop: backdrop,
                      onPressed: () => _openModal(context),
                      children: <Widget>[
                        Text(
                          'Open as a modal route',
                          style: TextStyle(color: contentColor),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          // The same widget, not a route: pinned to the bottom, full-bleed,
          // refracting the dimmed wallpaper above it.
          //
          // Full width matters here. A sheet is flush to both bezels and to
          // the bottom of the screen -- that is why its bottom corners are
          // square and why it draws no rim. Inset it and all three choices
          // stop making sense.
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: LiquidSheet(
              backdrop: backdrop,
              title: 'Glass quality',
              items: _items(),
            ),
          ),
        ];
      },
    );
  }
}
