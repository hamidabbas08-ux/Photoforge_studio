import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

class DrawingLayerEditor extends StatefulWidget {
  const DrawingLayerEditor({
    super.key,
    required this.canvasWidth,
    required this.canvasHeight,
  });

  final int canvasWidth;
  final int canvasHeight;

  @override
  State<DrawingLayerEditor> createState() => _DrawingLayerEditorState();
}

class _DrawingLayerEditorState extends State<DrawingLayerEditor> {
  final List<_DrawingStroke> _strokes = <_DrawingStroke>[];
  final List<_DrawingStroke> _redoStrokes = <_DrawingStroke>[];

  Color _brushColor = Colors.red;
  double _brushSize = 18;
  double _brushOpacity = 1;
  bool _eraserEnabled = false;
  bool _isSaving = false;

  _DrawingStroke? _activeStroke;

  static const List<Color> _colors = <Color>[
    Colors.white,
    Colors.black,
    Colors.red,
    Colors.orange,
    Colors.yellow,
    Colors.green,
    Colors.cyan,
    Colors.blue,
    Colors.purple,
    Colors.pink,
  ];

  void _startStroke(DragStartDetails details, Size size) {
    final Offset point = _normalisePoint(details.localPosition, size);

    final _DrawingStroke stroke = _DrawingStroke(
      points: <Offset>[point],
      colorValue: _brushColor.toARGB32(),
      width: _brushSize,
      opacity: _brushOpacity,
      isEraser: _eraserEnabled,
    );

    setState(() {
      _activeStroke = stroke;
      _strokes.add(stroke);
      _redoStrokes.clear();
    });
  }

  void _continueStroke(DragUpdateDetails details, Size size) {
    final _DrawingStroke? stroke = _activeStroke;

    if (stroke == null) {
      return;
    }

    final Offset point = _normalisePoint(details.localPosition, size);

    setState(() {
      stroke.points.add(point);
    });
  }

  void _endStroke(DragEndDetails details) {
    _activeStroke = null;
  }

  Offset _normalisePoint(Offset point, Size size) {
    if (size.width <= 0 || size.height <= 0) {
      return Offset.zero;
    }

    return Offset(
      (point.dx / size.width).clamp(0.0, 1.0),
      (point.dy / size.height).clamp(0.0, 1.0),
    );
  }

  void _undo() {
    if (_strokes.isEmpty) {
      return;
    }

    setState(() {
      _redoStrokes.add(_strokes.removeLast());
    });
  }

  void _redo() {
    if (_redoStrokes.isEmpty) {
      return;
    }

    setState(() {
      _strokes.add(_redoStrokes.removeLast());
    });
  }

  void _clear() {
    if (_strokes.isEmpty) {
      return;
    }

    setState(() {
      _redoStrokes.addAll(_strokes.reversed);
      _strokes.clear();
    });
  }

  Future<void> _saveDrawing() async {
    if (_strokes.isEmpty || _isSaving) {
      return;
    }

    setState(() => _isSaving = true);

    try {
      final File file = await _renderDrawingFile();

      if (!mounted) {
        return;
      }

      Navigator.of(context).pop(file);
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Drawing could not be saved: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<File> _renderDrawingFile() async {
    final int width = widget.canvasWidth.clamp(300, 4096);
    final int height = widget.canvasHeight.clamp(300, 4096);

    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(recorder);

    canvas.saveLayer(
      Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
      Paint(),
    );

    _paintStrokes(
      canvas: canvas,
      size: Size(width.toDouble(), height.toDouble()),
      strokes: _strokes,
    );

    canvas.restore();

    final ui.Picture picture = recorder.endRecording();
    final ui.Image image = await picture.toImage(width, height);

    final ByteData? byteData = await image.toByteData(
      format: ui.ImageByteFormat.png,
    );

    image.dispose();
    picture.dispose();

    if (byteData == null) {
      throw StateError('Drawing image could not be generated.');
    }

    final Directory documents = await getApplicationDocumentsDirectory();

    final Directory directory = Directory(
      '${documents.path}/PhotoForge Drawing Layers',
    );

    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }

    final File output = File(
      '${directory.path}/drawing_${DateTime.now().microsecondsSinceEpoch}.png',
    );

    await output.writeAsBytes(byteData.buffer.asUint8List(), flush: true);

    return output;
  }

  static void _paintStrokes({
    required Canvas canvas,
    required Size size,
    required List<_DrawingStroke> strokes,
  }) {
    for (final _DrawingStroke stroke in strokes) {
      if (stroke.points.isEmpty) {
        continue;
      }

      final Paint paint = Paint()
        ..color = Color(
          stroke.colorValue,
        ).withValues(alpha: stroke.opacity.clamp(0.0, 1.0))
        ..strokeWidth = stroke.width
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke
        ..isAntiAlias = true
        ..blendMode = stroke.isEraser ? BlendMode.clear : BlendMode.srcOver;

      Offset convert(Offset point) {
        return Offset(point.dx * size.width, point.dy * size.height);
      }

      if (stroke.points.length == 1) {
        final Offset point = convert(stroke.points.first);

        canvas.drawCircle(
          point,
          stroke.width / 2,
          Paint()
            ..color = paint.color
            ..blendMode = paint.blendMode
            ..isAntiAlias = true,
        );

        continue;
      }

      final Path path = Path();
      final Offset first = convert(stroke.points.first);

      path.moveTo(first.dx, first.dy);

      for (int index = 1; index < stroke.points.length; index++) {
        final Offset current = convert(stroke.points[index]);
        path.lineTo(current.dx, current.dy);
      }

      canvas.drawPath(path, paint);
    }
  }

  @override
  Widget build(BuildContext context) {
    final double aspectRatio = widget.canvasWidth / widget.canvasHeight;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Draw Layer'),
        actions: [
          IconButton(
            tooltip: 'Undo stroke',
            onPressed: _strokes.isEmpty ? null : _undo,
            icon: const Icon(Icons.undo_rounded),
          ),
          IconButton(
            tooltip: 'Redo stroke',
            onPressed: _redoStrokes.isEmpty ? null : _redo,
            icon: const Icon(Icons.redo_rounded),
          ),
          IconButton(
            tooltip: 'Clear drawing',
            onPressed: _strokes.isEmpty ? null : _clear,
            icon: const Icon(Icons.delete_sweep_outlined),
          ),
          const SizedBox(width: 4),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilledButton.icon(
              onPressed: _strokes.isEmpty || _isSaving ? null : _saveDrawing,
              icon: _isSaving
                  ? const SizedBox(
                      width: 17,
                      height: 17,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.check_rounded),
              label: const Text('Save'),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: AspectRatio(
                  aspectRatio: aspectRatio,
                  child: LayoutBuilder(
                    builder:
                        (BuildContext context, BoxConstraints constraints) {
                          final Size size = Size(
                            constraints.maxWidth,
                            constraints.maxHeight,
                          );

                          return GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onPanStart: (DragStartDetails details) {
                              _startStroke(details, size);
                            },
                            onPanUpdate: (DragUpdateDetails details) {
                              _continueStroke(details, size);
                            },
                            onPanEnd: _endStroke,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: const Color(0xFF20242A),
                                border: Border.all(color: Colors.white24),
                              ),
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  const CustomPaint(
                                    painter: _DrawingCheckerPainter(),
                                  ),
                                  CustomPaint(
                                    painter: _DrawingPainter(strokes: _strokes),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              decoration: const BoxDecoration(
                color: Color(0xFF171A1F),
                border: Border(top: BorderSide(color: Colors.white12)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      FilterChip(
                        selected: !_eraserEnabled,
                        avatar: const Icon(Icons.brush_rounded, size: 18),
                        label: const Text('Brush'),
                        onSelected: (_) {
                          setState(() {
                            _eraserEnabled = false;
                          });
                        },
                      ),
                      const SizedBox(width: 8),
                      FilterChip(
                        selected: _eraserEnabled,
                        avatar: const Icon(
                          Icons.auto_fix_normal_rounded,
                          size: 18,
                        ),
                        label: const Text('Eraser'),
                        onSelected: (_) {
                          setState(() {
                            _eraserEnabled = true;
                          });
                        },
                      ),
                      const SizedBox(width: 14),
                      const Text('Size'),
                      Expanded(
                        child: Slider(
                          value: _brushSize,
                          min: 2,
                          max: 100,
                          divisions: 49,
                          label: _brushSize.round().toString(),
                          onChanged: (double value) {
                            setState(() {
                              _brushSize = value;
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      const Text('Opacity'),
                      Expanded(
                        child: Slider(
                          value: _brushOpacity,
                          min: 0.1,
                          max: 1,
                          divisions: 9,
                          label: '${(_brushOpacity * 100).round()}%',
                          onChanged: _eraserEnabled
                              ? null
                              : (double value) {
                                  setState(() {
                                    _brushOpacity = value;
                                  });
                                },
                        ),
                      ),
                    ],
                  ),
                  SizedBox(
                    height: 40,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _colors.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 8),
                      itemBuilder: (BuildContext context, int index) {
                        final Color color = _colors[index];
                        final bool selected =
                            color.toARGB32() == _brushColor.toARGB32();

                        return InkWell(
                          onTap: () {
                            setState(() {
                              _brushColor = color;
                              _eraserEnabled = false;
                            });
                          },
                          borderRadius: BorderRadius.circular(22),
                          child: Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: selected
                                    ? Colors.lightBlueAccent
                                    : Colors.white24,
                                width: selected ? 3 : 1,
                              ),
                            ),
                            child: selected
                                ? Icon(
                                    Icons.check_rounded,
                                    size: 20,
                                    color: color.computeLuminance() > 0.5
                                        ? Colors.black
                                        : Colors.white,
                                  )
                                : null,
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DrawingStroke {
  _DrawingStroke({
    required this.points,
    required this.colorValue,
    required this.width,
    required this.opacity,
    required this.isEraser,
  });

  final List<Offset> points;
  final int colorValue;
  final double width;
  final double opacity;
  final bool isEraser;
}

class _DrawingPainter extends CustomPainter {
  const _DrawingPainter({required this.strokes});

  final List<_DrawingStroke> strokes;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.saveLayer(Offset.zero & size, Paint());

    _DrawingLayerEditorState._paintStrokes(
      canvas: canvas,
      size: size,
      strokes: strokes,
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _DrawingPainter oldDelegate) {
    return true;
  }
}

class _DrawingCheckerPainter extends CustomPainter {
  const _DrawingCheckerPainter();

  @override
  void paint(Canvas canvas, Size size) {
    const double square = 18;
    final Paint light = Paint()..color = const Color(0xFF30343B);
    final Paint dark = Paint()..color = const Color(0xFF25292F);

    for (double y = 0; y < size.height; y += square) {
      for (double x = 0; x < size.width; x += square) {
        final bool alternate =
            ((x / square).floor() + (y / square).floor()).isEven;

        canvas.drawRect(
          Rect.fromLTWH(x, y, square, square),
          alternate ? light : dark,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DrawingCheckerPainter oldDelegate) {
    return false;
  }
}
