import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;
import '../../features/editor/models/photo_filter_preset.dart';
import 'package:path_provider/path_provider.dart';

enum PhotoExportFormat { png, jpg }

class ImageExportService {
  ImageExportService._();

  static final ImageExportService instance = ImageExportService._();

  Future<File> export({
    required String sourcePath,
    required String projectName,
    required double brightness,
    required double contrast,
    required double saturation,
    required String filterId,
    required int quarterTurns,
    required bool flipHorizontal,
    required bool flipVertical,
    required double? cropAspectRatio,
    required PhotoExportFormat format,
    int jpgQuality = 95,
  }) async {
    final Directory documentsDirectory =
        await getApplicationDocumentsDirectory();

    final Directory exportDirectory = Directory(
      '${documentsDirectory.path}/PhotoForge Exports',
    );

    if (!await exportDirectory.exists()) {
      await exportDirectory.create(recursive: true);
    }

    final String safeProjectName = projectName
        .trim()
        .replaceAll(RegExp(r'[^a-zA-Z0-9_-]+'), '_')
        .replaceAll(RegExp(r'_+'), '_');

    final String extension = format == PhotoExportFormat.png ? 'png' : 'jpg';

    final String timestamp = DateTime.now().millisecondsSinceEpoch.toString();

    final String outputPath =
        '${exportDirectory.path}/${safeProjectName}_$timestamp.$extension';

    final Map<String, Object?> request = {
      'sourcePath': sourcePath,
      'outputPath': outputPath,
      'brightness': brightness,
      'contrast': contrast,
      'saturation': saturation,
      'filterId': filterId,
      'quarterTurns': quarterTurns,
      'flipHorizontal': flipHorizontal,
      'flipVertical': flipVertical,
      'cropAspectRatio': cropAspectRatio,
      'format': format.name,
      'jpgQuality': jpgQuality,
    };

    final String resultPath = await Isolate.run(
      () => _processAndExportImage(request),
    );

    return File(resultPath);
  }
}

String _processAndExportImage(Map<String, Object?> request) {
  final String sourcePath = request['sourcePath']! as String;
  final String outputPath = request['outputPath']! as String;

  final double brightness = request['brightness']! as double;
  final double contrast = request['contrast']! as double;
  final double saturation = request['saturation']! as double;
  final String filterId = request['filterId']! as String;

  final int quarterTurns = request['quarterTurns']! as int;
  final bool flipHorizontal = request['flipHorizontal']! as bool;
  final bool flipVertical = request['flipVertical']! as bool;
  final double? cropAspectRatio = request['cropAspectRatio'] as double?;

  final String format = request['format']! as String;
  final int jpgQuality = request['jpgQuality']! as int;

  final Uint8List sourceBytes = File(sourcePath).readAsBytesSync();

  img.Image? workingImage = img.decodeImage(sourceBytes);

  if (workingImage == null) {
    throw StateError('This image format could not be decoded.');
  }

  // Correct camera/EXIF orientation first.
  workingImage = img.bakeOrientation(workingImage);

  final int normalizedTurns = ((quarterTurns % 4) + 4) % 4;

  if (normalizedTurns != 0) {
    workingImage = img.copyRotate(
      workingImage,
      angle: normalizedTurns * 90,
      interpolation: img.Interpolation.cubic,
    );
  }

  if (flipHorizontal && flipVertical) {
    workingImage = img.copyFlip(
      workingImage,
      direction: img.FlipDirection.both,
    );
  } else if (flipHorizontal) {
    workingImage = img.copyFlip(
      workingImage,
      direction: img.FlipDirection.horizontal,
    );
  } else if (flipVertical) {
    workingImage = img.copyFlip(
      workingImage,
      direction: img.FlipDirection.vertical,
    );
  }

  if (cropAspectRatio != null && cropAspectRatio > 0) {
    workingImage = _centerCropToAspectRatio(workingImage, cropAspectRatio);
  }

  final double brightnessValue = (1 + brightness / 100).clamp(0.0, 2.0);

  final double contrastValue = (1 + contrast / 100).clamp(0.0, 2.0);

  final double saturationValue = (1 + saturation / 100).clamp(0.0, 2.0);

  final PhotoFilterPreset preset = PhotoFilterPreset.byId(filterId);

  workingImage = img.adjustColor(
    workingImage,
    brightness: preset.brightness,
    contrast: preset.contrast,
    saturation: preset.saturation,
    gamma: preset.gamma,
    exposure: preset.exposure,
    hue: preset.hue,
  );

  workingImage = img.adjustColor(
    workingImage,
    brightness: brightnessValue,
    contrast: contrastValue,
    saturation: saturationValue,
  );

  final List<int> outputBytes;

  if (format == PhotoExportFormat.png.name) {
    outputBytes = img.encodePng(workingImage, level: 6);
  } else {
    outputBytes = img.encodeJpg(
      workingImage,
      quality: jpgQuality.clamp(1, 100),
    );
  }

  File(outputPath).writeAsBytesSync(outputBytes, flush: true);

  return outputPath;
}

img.Image _centerCropToAspectRatio(img.Image source, double targetAspectRatio) {
  final double sourceAspectRatio = source.width / source.height;

  if ((sourceAspectRatio - targetAspectRatio).abs() < 0.0001) {
    return source;
  }

  int cropWidth = source.width;
  int cropHeight = source.height;

  if (sourceAspectRatio > targetAspectRatio) {
    cropWidth = math.max(1, (source.height * targetAspectRatio).round());
  } else {
    cropHeight = math.max(1, (source.width / targetAspectRatio).round());
  }

  final int cropX = math.max(0, ((source.width - cropWidth) / 2).round());

  final int cropY = math.max(0, ((source.height - cropHeight) / 2).round());

  return img.copyCrop(
    source,
    x: cropX,
    y: cropY,
    width: math.min(cropWidth, source.width),
    height: math.min(cropHeight, source.height),
  );
}
