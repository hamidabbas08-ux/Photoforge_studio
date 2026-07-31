import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

import '../../features/editor/models/photo_filter_preset.dart';

enum PhotoExportFormat { png, jpg }

class ImageExportService {
  ImageExportService._();

  static final ImageExportService instance = ImageExportService._();

  Future<File> export({
    required String sourcePath,
    required String projectName,
    required List<Map<String, Object?>> layers,
    required double previewCanvasWidth,
    required double previewCanvasHeight,
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

    final String cleanName = safeProjectName.isEmpty
        ? 'PhotoForge_Project'
        : safeProjectName;

    final String extension = format == PhotoExportFormat.png ? 'png' : 'jpg';

    final String timestamp = DateTime.now().millisecondsSinceEpoch.toString();

    final String outputPath =
        '${exportDirectory.path}/${cleanName}_$timestamp.$extension';

    final Map<String, Object?> request = {
      'sourcePath': sourcePath,
      'outputPath': outputPath,
      'layers': layers,
      'previewCanvasWidth': previewCanvasWidth,
      'previewCanvasHeight': previewCanvasHeight,
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

  final List<Object?> rawLayers = request['layers']! as List<Object?>;

  final double previewCanvasWidth = request['previewCanvasWidth']! as double;

  final double previewCanvasHeight = request['previewCanvasHeight']! as double;

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

  final Uint8List baseBytes = File(sourcePath).readAsBytesSync();

  img.Image? baseReference = img.decodeImage(baseBytes);

  if (baseReference == null) {
    throw StateError('The base image could not be decoded.');
  }

  baseReference = img.bakeOrientation(baseReference);

  final int canvasWidth = baseReference.width;
  final int canvasHeight = baseReference.height;

  img.Image composition = img.Image(
    width: canvasWidth,
    height: canvasHeight,
    numChannels: 4,
  );

  final double safePreviewWidth = previewCanvasWidth <= 0
      ? canvasWidth.toDouble()
      : previewCanvasWidth;

  final double safePreviewHeight = previewCanvasHeight <= 0
      ? canvasHeight.toDouble()
      : previewCanvasHeight;

  final double positionScaleX = canvasWidth / safePreviewWidth;

  final double positionScaleY = canvasHeight / safePreviewHeight;

  for (final Object? rawLayer in rawLayers) {
    final Map<String, Object?> layer = Map<String, Object?>.from(
      rawLayer! as Map,
    );

    final bool isVisible = layer['isVisible']! as bool;

    final String? imagePath = layer['imagePath'] as String?;

    if (!isVisible || imagePath == null || imagePath.isEmpty) {
      continue;
    }

    final File layerFile = File(imagePath);

    if (!layerFile.existsSync()) {
      continue;
    }

    final Uint8List layerBytes = layerFile.readAsBytesSync();

    img.Image? layerImage = img.decodeImage(layerBytes);

    if (layerImage == null) {
      continue;
    }

    layerImage = img.bakeOrientation(layerImage);

    layerImage = _coverImageToCanvas(layerImage, canvasWidth, canvasHeight);

    final double scaleX = (layer['scaleX']! as num).toDouble().clamp(
      0.08,
      12.0,
    );

    final double scaleY = (layer['scaleY']! as num).toDouble().clamp(
      0.08,
      12.0,
    );

    final int scaledWidth = math.max(1, (layerImage.width * scaleX).round());

    final int scaledHeight = math.max(1, (layerImage.height * scaleY).round());

    if (scaledWidth != layerImage.width || scaledHeight != layerImage.height) {
      layerImage = img.copyResize(
        layerImage,
        width: scaledWidth,
        height: scaledHeight,
        interpolation: img.Interpolation.cubic,
      );
    }

    final double rotationRadians = (layer['rotation']! as num).toDouble();

    final double rotationDegrees = rotationRadians * 180 / math.pi;

    if (rotationDegrees.abs() > 0.001) {
      layerImage = img.copyRotate(
        layerImage,
        angle: rotationDegrees,
        interpolation: img.Interpolation.cubic,
      );
    }

    final double opacity = (layer['opacity']! as num).toDouble().clamp(
      0.0,
      1.0,
    );

    if (opacity < 0.999) {
      _applyOpacity(layerImage, opacity);
    }

    final double offsetX = (layer['offsetX']! as num).toDouble();

    final double offsetY = (layer['offsetY']! as num).toDouble();

    final int destinationX =
        (((canvasWidth - layerImage.width) / 2) + (offsetX * positionScaleX))
            .round();

    final int destinationY =
        (((canvasHeight - layerImage.height) / 2) + (offsetY * positionScaleY))
            .round();

    composition = img.compositeImage(
      composition,
      layerImage,
      dstX: destinationX,
      dstY: destinationY,
      blend: _exportBlendMode(layer['blendMode']! as String),
    );
  }

  int normalizedTurns = ((quarterTurns % 4) + 4) % 4;

  if (normalizedTurns != 0) {
    composition = img.copyRotate(
      composition,
      angle: normalizedTurns * 90,
      interpolation: img.Interpolation.cubic,
    );
  }

  if (flipHorizontal && flipVertical) {
    composition = img.copyFlip(composition, direction: img.FlipDirection.both);
  } else if (flipHorizontal) {
    composition = img.copyFlip(
      composition,
      direction: img.FlipDirection.horizontal,
    );
  } else if (flipVertical) {
    composition = img.copyFlip(
      composition,
      direction: img.FlipDirection.vertical,
    );
  }

  if (cropAspectRatio != null && cropAspectRatio > 0) {
    composition = _centerCropToAspectRatio(composition, cropAspectRatio);
  }

  final PhotoFilterPreset preset = PhotoFilterPreset.byId(filterId);

  composition = img.adjustColor(
    composition,
    brightness: preset.brightness,
    contrast: preset.contrast,
    saturation: preset.saturation,
    gamma: preset.gamma,
    exposure: preset.exposure,
    hue: preset.hue,
  );

  final double brightnessValue = (1 + brightness / 100).clamp(0.0, 2.0);

  final double contrastValue = (1 + contrast / 100).clamp(0.0, 2.0);

  final double saturationValue = (1 + saturation / 100).clamp(0.0, 2.0);

  composition = img.adjustColor(
    composition,
    brightness: brightnessValue,
    contrast: contrastValue,
    saturation: saturationValue,
  );

  final List<int> outputBytes;

  if (format == PhotoExportFormat.png.name) {
    outputBytes = img.encodePng(composition, level: 6);
  } else {
    outputBytes = img.encodeJpg(composition, quality: jpgQuality.clamp(1, 100));
  }

  File(outputPath).writeAsBytesSync(outputBytes, flush: true);

  return outputPath;
}

img.Image _coverImageToCanvas(
  img.Image source,
  int canvasWidth,
  int canvasHeight,
) {
  final double widthScale = canvasWidth / source.width;

  final double heightScale = canvasHeight / source.height;

  final double coverScale = math.max(widthScale, heightScale);

  final int resizedWidth = math.max(1, (source.width * coverScale).round());

  final int resizedHeight = math.max(1, (source.height * coverScale).round());

  img.Image resized = img.copyResize(
    source,
    width: resizedWidth,
    height: resizedHeight,
    interpolation: img.Interpolation.cubic,
  );

  final int cropX = math.max(0, ((resized.width - canvasWidth) / 2).round());

  final int cropY = math.max(0, ((resized.height - canvasHeight) / 2).round());

  return img.copyCrop(
    resized,
    x: cropX,
    y: cropY,
    width: math.min(canvasWidth, resized.width),
    height: math.min(canvasHeight, resized.height),
  );
}

void _applyOpacity(img.Image image, double opacity) {
  for (final img.Pixel pixel in image) {
    pixel.aNormalized = pixel.aNormalized * opacity;
  }
}

img.BlendMode _exportBlendMode(String blendMode) {
  switch (blendMode) {
    case 'multiply':
      return img.BlendMode.multiply;

    case 'screen':
      return img.BlendMode.screen;

    case 'overlay':
      return img.BlendMode.overlay;

    case 'softLight':
      return img.BlendMode.softLight;

    case 'hardLight':
      return img.BlendMode.hardLight;

    case 'darken':
      return img.BlendMode.darken;

    case 'lighten':
      return img.BlendMode.lighten;

    case 'difference':
      return img.BlendMode.difference;

    case 'normal':
    default:
      return img.BlendMode.alpha;
  }
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
