import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

class SmartBackgroundRemovalService {
  SmartBackgroundRemovalService._();

  static final SmartBackgroundRemovalService instance =
      SmartBackgroundRemovalService._();

  Future<File> removeBackground({
    required String sourcePath,
    required double tolerance,
    required double softness,
  }) async {
    final File sourceFile = File(sourcePath);

    if (!await sourceFile.exists()) {
      throw StateError('Selected layer image is unavailable.');
    }

    final Uint8List sourceBytes = await sourceFile.readAsBytes();
    final img.Image? decoded = img.decodeImage(sourceBytes);

    if (decoded == null) {
      throw StateError('Selected layer image could not be decoded.');
    }

    final img.Image output = img.Image.from(decoded);

    final int width = output.width;
    final int height = output.height;

    if (width <= 1 || height <= 1) {
      throw StateError('Selected layer image is too small.');
    }

    final _Rgb backgroundColor = _estimateBackgroundColor(output);

    final double safeTolerance = tolerance.clamp(5.0, 180.0);
    final double safeSoftness = softness.clamp(0.0, 80.0);
    final double outerTolerance = safeTolerance + safeSoftness;

    final int pixelCount = width * height;
    final Uint8List visited = Uint8List(pixelCount);
    final Int32List queue = Int32List(pixelCount);

    int queueStart = 0;
    int queueEnd = 0;

    void addPixel(int x, int y) {
      if (x < 0 || x >= width || y < 0 || y >= height) {
        return;
      }

      final int index = y * width + x;

      if (visited[index] != 0) {
        return;
      }

      final img.Pixel pixel = output.getPixel(x, y);

      final double distance = _colorDistance(
        pixel.r.toDouble(),
        pixel.g.toDouble(),
        pixel.b.toDouble(),
        backgroundColor,
      );

      if (distance > outerTolerance) {
        return;
      }

      visited[index] = 1;
      queue[queueEnd++] = index;
    }

    // Start only from image borders so foreground areas with a similar
    // color in the middle are less likely to be removed.
    for (int x = 0; x < width; x++) {
      addPixel(x, 0);
      addPixel(x, height - 1);
    }

    for (int y = 1; y < height - 1; y++) {
      addPixel(0, y);
      addPixel(width - 1, y);
    }

    while (queueStart < queueEnd) {
      final int index = queue[queueStart++];
      final int x = index % width;
      final int y = index ~/ width;

      final img.Pixel pixel = output.getPixel(x, y);

      final double distance = _colorDistance(
        pixel.r.toDouble(),
        pixel.g.toDouble(),
        pixel.b.toDouble(),
        backgroundColor,
      );

      double remainingAlpha;

      if (distance <= safeTolerance || safeSoftness <= 0) {
        remainingAlpha = 0;
      } else {
        remainingAlpha = ((distance - safeTolerance) / safeSoftness).clamp(
          0.0,
          1.0,
        );
      }

      final int newAlpha = (pixel.a.toDouble() * remainingAlpha).round().clamp(
        0,
        255,
      );

      output.setPixelRgba(
        x,
        y,
        pixel.r.toInt(),
        pixel.g.toInt(),
        pixel.b.toInt(),
        newAlpha,
      );

      addPixel(x - 1, y);
      addPixel(x + 1, y);
      addPixel(x, y - 1);
      addPixel(x, y + 1);
    }

    final Directory documents = await getApplicationDocumentsDirectory();

    final Directory directory = Directory(
      '${documents.path}/PhotoForge Cutout Layers',
    );

    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }

    final File outputFile = File(
      '${directory.path}/cutout_'
      '${DateTime.now().microsecondsSinceEpoch}.png',
    );

    await outputFile.writeAsBytes(img.encodePng(output), flush: true);

    return outputFile;
  }

  _Rgb _estimateBackgroundColor(img.Image image) {
    final int sampleWidth = (image.width * 0.06).round().clamp(2, 40);
    final int sampleHeight = (image.height * 0.06).round().clamp(2, 40);

    double red = 0;
    double green = 0;
    double blue = 0;
    int count = 0;

    void sampleArea(int startX, int startY) {
      final int endX = (startX + sampleWidth).clamp(0, image.width);
      final int endY = (startY + sampleHeight).clamp(0, image.height);

      for (int y = startY; y < endY; y++) {
        for (int x = startX; x < endX; x++) {
          final img.Pixel pixel = image.getPixel(x, y);

          red += pixel.r;
          green += pixel.g;
          blue += pixel.b;
          count++;
        }
      }
    }

    sampleArea(0, 0);
    sampleArea(image.width - sampleWidth, 0);
    sampleArea(0, image.height - sampleHeight);
    sampleArea(image.width - sampleWidth, image.height - sampleHeight);

    if (count == 0) {
      final img.Pixel corner = image.getPixel(0, 0);

      return _Rgb(
        corner.r.toDouble(),
        corner.g.toDouble(),
        corner.b.toDouble(),
      );
    }

    return _Rgb(red / count, green / count, blue / count);
  }

  double _colorDistance(
    double red,
    double green,
    double blue,
    _Rgb background,
  ) {
    final double redDifference = red - background.red;
    final double greenDifference = green - background.green;
    final double blueDifference = blue - background.blue;

    return math.sqrt(
      redDifference * redDifference +
          greenDifference * greenDifference +
          blueDifference * blueDifference,
    );
  }
}

class _Rgb {
  const _Rgb(this.red, this.green, this.blue);

  final double red;
  final double green;
  final double blue;
}
