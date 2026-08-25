import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';

/// Opens the platform's picture picker and returns the chosen image's bytes.
///
/// The Flutter counterpart of the `PickVisualMedia` launcher in
/// `catalog/BackdropDemoScaffold.kt`.
Future<Uint8List?> pickWallpaperBytes() async {
  const XTypeGroup images = XTypeGroup(
    label: 'images',
    extensions: <String>['png', 'jpg', 'jpeg', 'webp', 'bmp', 'gif'],
    mimeTypes: <String>['image/*'],
  );
  try {
    final XFile? file = await openFile(acceptedTypeGroups: <XTypeGroup>[images]);
    if (file == null) return null;
    return await file.readAsBytes();
  } catch (_) {
    return null;
  }
}
