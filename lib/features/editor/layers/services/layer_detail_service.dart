import 'dart:io';
import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

class LayerDetailService {
  LayerDetailService._();

  static final LayerDetailService instance = LayerDetailService._();

  Future<File> apply({
    required String sourcePath,
    required int blurRadius,
    required double sharpenAmount,
  }) async {
    final File sourceFile = File(sourcePath);

    if (!await sourceFile.exists()) {
      throw StateError('Selected layer image is unavailable.');
    }

    final Uint8List sourceBytes = await sourceFile.readAsBytes();
    img.Image? image = img.decodeImage(sourceBytes);

    if (image == null) {
      throw StateError('Selected layer image could not be decoded.');
    }

    final int safeBlurRadius = blurRadius.clamp(0, 25);
    final double safeSharpenAmount = sharpenAmount.clamp(0.0, 1.0);

    if (safeBlurRadius > 0) {
      image = img.gaussianBlur(image, radius: safeBlurRadius);
    }

    if (safeSharpenAmount > 0) {
      image = img.convolution(
        image,
        filter: const <num>[0, -1, 0, -1, 5, -1, 0, -1, 0],
        amount: safeSharpenAmount,
      );
    }

    final Directory documents = await getApplicationDocumentsDirectory();

    final Directory directory = Directory(
      '${documents.path}/PhotoForge Processed Layers',
    );

    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }

    final File output = File(
      '${directory.path}/detail_${DateTime.now().microsecondsSinceEpoch}.png',
    );

    await output.writeAsBytes(img.encodePng(image), flush: true);

    return output;
  }
}
