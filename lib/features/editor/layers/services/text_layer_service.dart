import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

class TextLayerService {
  TextLayerService._();

  static final TextLayerService instance = TextLayerService._();

  Future<File> createTextLayer({
    required String text,
    required int canvasWidth,
    required int canvasHeight,
    required double fontSize,
    required Color color,
    required bool bold,
    required bool italic,
    required TextAlign textAlign,
  }) async {
    final String cleanText = text.trim();

    if (cleanText.isEmpty) {
      throw ArgumentError('Text cannot be empty.');
    }

    final int safeWidth = canvasWidth.clamp(300, 4096);
    final int safeHeight = canvasHeight.clamp(300, 4096);

    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(recorder);

    final TextPainter painter = TextPainter(
      text: TextSpan(
        text: cleanText,
        style: TextStyle(
          color: color,
          fontSize: fontSize.clamp(24, 300),
          fontWeight: bold ? FontWeight.w800 : FontWeight.w400,
          fontStyle: italic ? FontStyle.italic : FontStyle.normal,
          height: 1.15,
        ),
      ),
      textAlign: textAlign,
      textDirection: TextDirection.ltr,
      maxLines: null,
    );

    final double horizontalPadding = safeWidth * 0.08;
    final double maximumTextWidth = (safeWidth - horizontalPadding * 2).clamp(
      100,
      safeWidth.toDouble(),
    );

    painter.layout(minWidth: 0, maxWidth: maximumTextWidth);

    double x;

    switch (textAlign) {
      case TextAlign.left:
      case TextAlign.start:
        x = horizontalPadding;

      case TextAlign.right:
      case TextAlign.end:
        x = safeWidth - horizontalPadding - painter.width;

      case TextAlign.center:
      case TextAlign.justify:
        x = (safeWidth - painter.width) / 2;
    }

    final double y = (safeHeight - painter.height) / 2;

    painter.paint(
      canvas,
      Offset(
        x.clamp(0, safeWidth.toDouble()),
        y.clamp(0, safeHeight.toDouble()),
      ),
    );

    final ui.Picture picture = recorder.endRecording();

    final ui.Image image = await picture.toImage(safeWidth, safeHeight);

    final ByteData? byteData = await image.toByteData(
      format: ui.ImageByteFormat.png,
    );

    image.dispose();
    picture.dispose();
    painter.dispose();

    if (byteData == null) {
      throw StateError('Text layer could not be rendered.');
    }

    final Uint8List pngBytes = byteData.buffer.asUint8List();

    final Directory documents = await getApplicationDocumentsDirectory();

    final Directory directory = Directory(
      '${documents.path}/PhotoForge Text Layers',
    );

    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }

    final File output = File(
      '${directory.path}/text_${DateTime.now().microsecondsSinceEpoch}.png',
    );

    await output.writeAsBytes(pngBytes, flush: true);

    return output;
  }
}
