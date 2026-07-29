import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../features/editor/models/editor_image.dart';

class ImageImportService {
  ImageImportService._();

  static final ImageImportService instance = ImageImportService._();

  final ImagePicker _picker = ImagePicker();

  Future<EditorImage?> pickFromGallery() async {
    final XFile? selectedFile = await _picker.pickImage(
      source: ImageSource.gallery,
      requestFullMetadata: false,
    );

    if (selectedFile == null) {
      return null;
    }

    final Uint8List bytes = await selectedFile.readAsBytes();
    final ui.Codec codec = await ui.instantiateImageCodec(bytes);
    final ui.FrameInfo frame = await codec.getNextFrame();
    final ui.Image image = frame.image;

    final EditorImage result = EditorImage(
      path: selectedFile.path,
      width: image.width,
      height: image.height,
    );

    image.dispose();
    codec.dispose();

    return result;
  }
}
