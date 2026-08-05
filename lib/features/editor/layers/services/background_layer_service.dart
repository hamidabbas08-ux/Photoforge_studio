import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

class BackgroundLayerService {
  BackgroundLayerService._();

  static final BackgroundLayerService instance = BackgroundLayerService._();

  Future<File> createSolidBackground({
    required int canvasWidth,
    required int canvasHeight,
    required Color color,
  }) {
    return _renderBackground(
      canvasWidth: canvasWidth,
      canvasHeight: canvasHeight,
      painter: (Canvas canvas, Rect rect) {
        canvas.drawRect(
          rect,
          Paint()
            ..color = color
            ..style = PaintingStyle.fill,
        );
      },
    );
  }

  Future<File> createGradientBackground({
    required int canvasWidth,
    required int canvasHeight,
    required Color startColor,
    required Color endColor,
    required Alignment begin,
    required Alignment end,
  }) {
    return _renderBackground(
      canvasWidth: canvasWidth,
      canvasHeight: canvasHeight,
      painter: (Canvas canvas, Rect rect) {
        final Gradient gradient = LinearGradient(
          begin: begin,
          end: end,
          colors: <Color>[startColor, endColor],
        );

        canvas.drawRect(
          rect,
          Paint()
            ..shader = gradient.createShader(rect)
            ..style = PaintingStyle.fill,
        );
      },
    );
  }

  Future<File> _renderBackground({
    required int canvasWidth,
    required int canvasHeight,
    required void Function(Canvas canvas, Rect rect) painter,
  }) async {
    final int safeWidth = canvasWidth.clamp(300, 4096);
    final int safeHeight = canvasHeight.clamp(300, 4096);

    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(recorder);

    final Rect canvasRect = Rect.fromLTWH(
      0,
      0,
      safeWidth.toDouble(),
      safeHeight.toDouble(),
    );

    painter(canvas, canvasRect);

    final ui.Picture picture = recorder.endRecording();

    final ui.Image image = await picture.toImage(safeWidth, safeHeight);

    final ByteData? byteData = await image.toByteData(
      format: ui.ImageByteFormat.png,
    );

    image.dispose();
    picture.dispose();

    if (byteData == null) {
      throw StateError('Background image could not be rendered.');
    }

    final Directory documents = await getApplicationDocumentsDirectory();

    final Directory directory = Directory(
      '${documents.path}/PhotoForge Background Layers',
    );

    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }

    final File output = File(
      '${directory.path}/background_'
      '${DateTime.now().microsecondsSinceEpoch}.png',
    );

    await output.writeAsBytes(byteData.buffer.asUint8List(), flush: true);

    return output;
  }
}
