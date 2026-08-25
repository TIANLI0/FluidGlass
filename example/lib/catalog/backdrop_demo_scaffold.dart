import 'dart:typed_data';

import 'package:fluid_glass/fluid_glass.dart';
import 'package:flutter/material.dart';

import 'components/liquid_button.dart';
import 'wallpaper_picker.dart';

/// The wallpaper every demo sits on, exported as a [LayerBackdrop], plus the
/// button that swaps it for one of your own pictures.
///
/// [builder] returns the demo's children, which are centred unless they align
/// themselves.
class BackdropDemoScaffold extends StatefulWidget {
  const BackdropDemoScaffold({
    super.key,
    this.decorate,
    required this.builder,
  });

  /// Wraps the wallpaper before it is captured, so a demo can dim or blur what
  /// its glass refracts.
  final Widget Function(Widget wallpaper)? decorate;

  final List<Widget> Function(BuildContext context, LayerBackdrop backdrop) builder;

  @override
  State<BackdropDemoScaffold> createState() => _BackdropDemoScaffoldState();
}

class _BackdropDemoScaffoldState extends State<BackdropDemoScaffold> {
  final LayerBackdrop _backdrop = LayerBackdrop();
  Uint8List? _pickedImage;

  @override
  void dispose() {
    _backdrop.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final Uint8List? bytes = await pickWallpaperBytes();
    if (bytes != null && mounted) {
      setState(() => _pickedImage = bytes);
    }
  }

  @override
  Widget build(BuildContext context) {
    final Uint8List? picked = _pickedImage;
    Widget wallpaper = picked != null
        ? Image.memory(picked, fit: BoxFit.cover, gaplessPlayback: true)
        : Image.asset('assets/wallpaper_light.webp', fit: BoxFit.cover);
    wallpaper = SizedBox.expand(child: wallpaper);
    if (widget.decorate != null) {
      wallpaper = widget.decorate!(wallpaper);
    }

    return Stack(
      alignment: Alignment.center,
      // Compose's Box does not clip its children; Flutter's Stack does by
      // default, and the glass elements inside paint outside their boxes.
      clipBehavior: Clip.none,
      children: <Widget>[
        Positioned.fill(child: BackdropLayer(backdrop: _backdrop, child: wallpaper)),
        ...widget.builder(context, _backdrop),
        Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 16,
              bottom: 16 + MediaQuery.paddingOf(context).bottom,
            ),
            child: SizedBox(
              height: 56,
              child: LiquidButton(
                onPressed: _pickImage,
                backdrop: _backdrop,
                tint: const Color(0xFF0088FF),
                children: const <Widget>[
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: Text(
                      'Pick an image',
                      style: TextStyle(color: Color(0xFFFFFFFF), fontSize: 16),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
