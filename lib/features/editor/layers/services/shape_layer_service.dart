import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

enum ShapeLayerKind { rectangle, circle, line, arrow }

class ShapeLayerService {
  ShapeLayerService._();

  static final ShapeLayerService instance = ShapeLayerService._();

  Future<File> createShapeLayer({
    required ShapeLayerKind kind,
    required int canvasWidth,
    required int canvasHeight,
    required Color fillColor,
    required Color strokeColor,
    required double strokeWidth,
    required double cornerRadius,
  }) async {
    final int safeWidth = canvasWidth.clamp(300, 4096);
    final int safeHeight = canvasHeight.clamp(300, 4096);

    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(recorder);

    final double shortestSide = safeWidth < safeHeight
        ? safeWidth.toDouble()
        : safeHeight.toDouble();

    final double shapeWidth = safeWidth * 0.56;
    final double shapeHeight = safeHeight * 0.34;

    final Rect shapeRect = Rect.fromCenter(
      center: Offset(safeWidth / 2, safeHeight / 2),
      width: shapeWidth,
      height: shapeHeight,
    );

    final Paint fillPaint = Paint()
      ..color = fillColor
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    final Paint strokePaint = Paint()
      ..color = strokeColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth.clamp(1, 80)
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..isAntiAlias = true;

    switch (kind) {
      case ShapeLayerKind.rectangle:
        final RRect roundedRect = RRect.fromRectAndRadius(
          shapeRect,
          Radius.circular(cornerRadius.clamp(0, shortestSide * 0.25)),
        );

        canvas.drawRRect(roundedRect, fillPaint);

        if (strokeWidth > 0) {
          canvas.drawRRect(roundedRect, strokePaint);
        }

      case ShapeLayerKind.circle:
        final double radius =
            (shapeWidth < shapeHeight ? shapeWidth : shapeHeight) / 2;

        canvas.drawCircle(
          Offset(safeWidth / 2, safeHeight / 2),
          radius,
          fillPaint,
        );

        if (strokeWidth > 0) {
          canvas.drawCircle(
            Offset(safeWidth / 2, safeHeight / 2),
            radius,
            strokePaint,
          );
        }

      case ShapeLayerKind.line:
        final Offset start = Offset(safeWidth * 0.22, safeHeight * 0.5);

        final Offset end = Offset(safeWidth * 0.78, safeHeight * 0.5);

        canvas.drawLine(start, end, strokePaint);

      case ShapeLayerKind.arrow:
        final Offset start = Offset(safeWidth * 0.22, safeHeight * 0.5);

        final Offset end = Offset(safeWidth * 0.78, safeHeight * 0.5);

        canvas.drawLine(start, end, strokePaint);

        final double arrowSize = (strokeWidth * 5).clamp(
          24,
          shortestSide * 0.16,
        );

        final Path arrowHead = Path()
          ..moveTo(end.dx, end.dy)
          ..lineTo(end.dx - arrowSize, end.dy - arrowSize * 0.65)
          ..moveTo(end.dx, end.dy)
          ..lineTo(end.dx - arrowSize, end.dy + arrowSize * 0.65);

        canvas.drawPath(arrowHead, strokePaint);
    }

    final ui.Picture picture = recorder.endRecording();

    final ui.Image image = await picture.toImage(safeWidth, safeHeight);

    final ByteData? byteData = await image.toByteData(
      format: ui.ImageByteFormat.png,
    );

    image.dispose();
    picture.dispose();

    if (byteData == null) {
      throw StateError('Shape layer could not be rendered.');
    }

    final Directory documents = await getApplicationDocumentsDirectory();

    final Directory directory = Directory(
      '${documents.path}/PhotoForge Shape Layers',
    );

    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }

    final File output = File(
      '${directory.path}/shape_${DateTime.now().microsecondsSinceEpoch}.png',
    );

    await output.writeAsBytes(byteData.buffer.asUint8List(), flush: true);

    return output;
  }
}
