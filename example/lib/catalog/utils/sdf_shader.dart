import 'dart:ui' as ui;

import 'package:fluid_glass/fluid_glass.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'demo_shaders.dart';

/// Refracts a backdrop through a signed-distance-field texture, letting glass
/// take the shape of arbitrary artwork.
///
/// The texture is bound to the shader's second sampler; the engine binds the
/// effect chain's output to the first.
class SdfShaderSource extends ChangeNotifier {
  SdfShaderSource(this.assetName) {
    // ignore: discarded_futures
    _load();
  }

  final String assetName;

  ui.Image? _image;
  ui.Image? get image => _image;

  int get width => _image?.width ?? 1;
  int get height => _image?.height ?? 1;
  bool get isReady => _image != null;

  Future<void> _load() async {
    final ByteData data = await rootBundle.load(assetName);
    final ui.Codec codec =
        await ui.instantiateImageCodec(data.buffer.asUint8List());
    final ui.FrameInfo frame = await codec.getNextFrame();
    _image = frame.image;
    notifyListeners();
  }

  /// Appends the SDF refraction to [scope].
  void apply(
    BackdropEffectScope scope, {
    double refractionHeight = 48,
    double lightAngle = 45,
  }) {
    final ui.Image? image = _image;
    if (image == null) return;
    scope.fragmentShaderEffect(
      'SdfShader',
      DemoShaders.instance.sdf,
      (ui.FragmentShader shader, BackdropEffectGeometry geometry) {
        // Linear sampling: an SDF interpolates linearly, and the texture is
        // minified here.
        shader.setImageSampler(1, image, filterQuality: ui.FilterQuality.low);
        shader
          ..setFloat(0, 0)
          ..setFloat(1, 0)
          ..setFloat(2, geometry.layerSize.width)
          ..setFloat(3, geometry.layerSize.height)
          ..setFloat(4, geometry.size.width)
          ..setFloat(5, geometry.size.height)
          ..setFloat(6, image.width.toDouble())
          ..setFloat(7, image.height.toDouble())
          ..setFloat(8, refractionHeight)
          ..setFloat(9, lightAngle);
      },
    );
  }

  @override
  void dispose() {
    _image?.dispose();
    _image = null;
    super.dispose();
  }
}
