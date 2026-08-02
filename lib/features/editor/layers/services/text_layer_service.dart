import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
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

    final double safeWidth = canvasWidth.clamp(300, 4096).toDouble();
    final double safeHeight = canvasHeight.clamp(300, 4096).toDouble();

    final GlobalKey repaintKey = GlobalKey();

    final RenderRepaintBoundary boundary = RenderRepaintBoundary();

    final RenderView renderView = RenderView(
      view: WidgetsBinding.instance.platformDispatcher.views.first,
      configuration: ViewConfiguration(
        logicalConstraints: BoxConstraints.tight(Size(safeWidth, safeHeight)),
        devicePixelRatio: 1,
      ),
      child: RenderPositionedBox(alignment: Alignment.center, child: boundary),
    );

    final PipelineOwner pipelineOwner = PipelineOwner();
    final BuildOwner buildOwner = BuildOwner(focusManager: FocusManager());

    renderView.attach(pipelineOwner);
    renderView.prepareInitialFrame();

    final RenderObjectToWidgetElement<RenderBox> rootElement =
        RenderObjectToWidgetAdapter<RenderBox>(
          container: boundary,
          child: RepaintBoundary(
            key: repaintKey,
            child: SizedBox(
              width: safeWidth,
              height: safeHeight,
              child: Center(
                child: Padding(
                  padding: EdgeInsets.all(safeWidth * 0.06),
                  child: Text(
                    cleanText,
                    textAlign: textAlign,
                    style: TextStyle(
                      color: color,
                      fontSize: fontSize,
                      fontWeight: bold ? FontWeight.w800 : FontWeight.w400,
                      fontStyle: italic ? FontStyle.italic : FontStyle.normal,
                      height: 1.15,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ).attachToRenderTree(buildOwner);

    buildOwner.buildScope(rootElement);
    buildOwner.finalizeTree();

    pipelineOwner.flushLayout();
    pipelineOwner.flushCompositingBits();
    pipelineOwner.flushPaint();

    final image = await boundary.toImage(pixelRatio: 1);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);

    image.dispose();

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
