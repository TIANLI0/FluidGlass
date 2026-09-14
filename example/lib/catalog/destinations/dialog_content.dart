import 'package:fluid_glass/fluid_glass.dart';
import 'package:flutter/material.dart';

import '../backdrop_demo_scaffold.dart';
import '../utils/lorem_ipsum.dart';

/// [LiquidDialog], on both of the backdrops a dialog can have.
///
/// The panel in the middle of the page is on a [LayerBackdrop], so it refracts
/// — and the dim has to be inside what that layer captures, which is what
/// [BackdropDemoScaffold.decorate] is doing here. The button opens the same
/// widget as a real modal route on [nativeBackdrop]: no capture, the dim comes
/// free with the barrier, and no refraction to show for it.
class DialogContent extends StatefulWidget {
  const DialogContent({super.key});

  @override
  State<DialogContent> createState() => _DialogContentState();
}

class _DialogContentState extends State<DialogContent> {
  String _answer = 'Nothing yet';

  Future<void> _openModal(BuildContext context) async {
    final String? picked = await showLiquidDialog<String>(
      context: context,
      title: 'Delete this file?',
      message: 'It will not be recoverable once the bin is emptied.',
      actions: <LiquidDialogAction>[
        LiquidDialogAction(
          label: 'Cancel',
          onPressed: () => Navigator.of(context).pop('Cancelled'),
        ),
        LiquidDialogAction(
          label: 'Delete',
          isPrimary: true,
          isDestructive: true,
          onPressed: () => Navigator.of(context).pop('Deleted'),
        ),
      ],
    );
    if (picked != null && mounted) setState(() => _answer = picked);
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
      // The dim sits inside the captured wallpaper, so the dialog refracts it.
      decorate: (Widget wallpaper) => Stack(
        fit: StackFit.expand,
        children: <Widget>[
          wallpaper,
          ColoredBox(color: dimColor),
        ],
      ),
      builder: (BuildContext context, LayerBackdrop backdrop) {
        return <Widget>[
          Column(
            mainAxisSize: MainAxisSize.min,
            spacing: 32,
            children: <Widget>[
              LiquidDialog(
                backdrop: backdrop,
                title: 'Dialog Title',
                message: kLoremIpsum,
                scrollable: true,
                actions: <LiquidDialogAction>[
                  const LiquidDialogAction(label: 'Cancel'),
                  const LiquidDialogAction(label: 'Okay', isPrimary: true),
                ],
              ),
              Builder(
                builder: (BuildContext context) => LiquidButton(
                  backdrop: backdrop,
                  onPressed: () => _openModal(context),
                  children: <Widget>[
                    Text(
                      'Open as a modal route',
                      style: TextStyle(color: contentColor, fontSize: 16),
                    ),
                  ],
                ),
              ),
              Text(
                _answer,
                style: TextStyle(
                  color: contentColor.withValues(alpha: 0.68),
                  fontSize: 15,
                ),
              ),
            ],
          ),
        ];
      },
    );
  }
}
