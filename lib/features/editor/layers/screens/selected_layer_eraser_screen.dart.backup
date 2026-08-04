import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

class SelectedLayerEraserScreen extends StatefulWidget {
  const SelectedLayerEraserScreen({
    super.key,
    required this.sourcePath,
    required this.originalSourcePath,
  });

  final String sourcePath;
  final String originalSourcePath;

  @override
  State<SelectedLayerEraserScreen> createState() =>
      _SelectedLayerEraserScreenState();
}

class _SelectedLayerEraserScreenState extends State<SelectedLayerEraserScreen> {
  final List<_MaskStroke> _strokes = <_MaskStroke>[];
  final List<_MaskStroke> _redoStrokes = <_MaskStroke>[];

  bool _restoreMode = false;
  bool _isSaving = false;
  double _brushSize = 42;
  double _softness = 0.25;

  _MaskStroke? _activeStroke;

  void _startStroke(DragStartDetails details, Size size) {
    if (size.width <= 0 || size.height <= 0) {
      return;
    }

    final _MaskStroke stroke = _MaskStroke(
      points: <Offset>[_normalise(details.localPosition, size)],
      restore: _restoreMode,
      brushSize: _brushSize,
      softness: _softness,
    );

    setState(() {
      _strokes.add(stroke);
      _activeStroke = stroke;
      _redoStrokes.clear();
    });
  }

  void _continueStroke(DragUpdateDetails details, Size size) {
    final _MaskStroke? stroke = _activeStroke;

    if (stroke == null || size.width <= 0 || size.height <= 0) {
      return;
    }

    setState(() {
      stroke.points.add(_normalise(details.localPosition, size));
    });
  }

  void _endStroke(DragEndDetails details) {
    _activeStroke = null;
  }

  Offset _normalise(Offset point, Size size) {
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

  void _clearAll() {
    if (_strokes.isEmpty) {
      return;
    }

    setState(() {
      _redoStrokes
        ..clear()
        ..addAll(_strokes.reversed);

      _strokes.clear();
    });
  }

  Future<void> _save() async {
    if (_strokes.isEmpty || _isSaving) {
      return;
    }

    setState(() => _isSaving = true);

    try {
      final File output = await _renderOutput();

      if (!mounted) {
        return;
      }

      Navigator.of(context).pop(output);
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Layer erasing could not be saved: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<File> _renderOutput() async {
    final File sourceFile = File(widget.sourcePath);
    final File originalSourceFile = File(widget.originalSourcePath);

    if (!await sourceFile.exists()) {
      throw StateError('Selected layer image is unavailable.');
    }

    if (!await originalSourceFile.exists()) {
      throw StateError('Original foreground image is unavailable.');
    }

    final Uint8List sourceBytes = await sourceFile.readAsBytes();

    final Uint8List originalBytes = await originalSourceFile.readAsBytes();

    final img.Image? current = img.decodeImage(sourceBytes);

    img.Image? original = img.decodeImage(originalBytes);

    if (current == null || original == null) {
      throw StateError('Selected layer images could not be decoded.');
    }

    if (original.width != current.width || original.height != current.height) {
      original = img.copyResize(
        original,
        width: current.width,
        height: current.height,
        interpolation: img.Interpolation.linear,
      );
    }

    final img.Image output = img.Image.from(current);

    for (final _MaskStroke stroke in _strokes) {
      _applyStroke(output: output, original: original, stroke: stroke);
    }

    final Directory documents = await getApplicationDocumentsDirectory();

    final Directory directory = Directory(
      '${documents.path}/PhotoForge Erased Layers',
    );

    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }

    final File file = File(
      '${directory.path}/erased_${DateTime.now().microsecondsSinceEpoch}.png',
    );

    await file.writeAsBytes(img.encodePng(output), flush: true);

    return file;
  }

  void _applyStroke({
    required img.Image output,
    required img.Image original,
    required _MaskStroke stroke,
  }) {
    if (stroke.points.isEmpty) {
      return;
    }

    final double scaleReference = output.width < output.height
        ? output.width.toDouble()
        : output.height.toDouble();

    final double radius =
        (stroke.brushSize / 2) * (scaleReference / 700).clamp(0.5, 6.0);

    final List<Offset> pixels = stroke.points
        .map(
          (Offset point) =>
              Offset(point.dx * output.width, point.dy * output.height),
        )
        .toList();

    if (pixels.length == 1) {
      _stampCircle(
        output: output,
        original: original,
        center: pixels.first,
        radius: radius,
        restore: stroke.restore,
        softness: stroke.softness,
      );
      return;
    }

    for (int index = 1; index < pixels.length; index++) {
      final Offset start = pixels[index - 1];
      final Offset end = pixels[index];

      final double distance = (end - start).distance;
      final double spacing = (radius * 0.30).clamp(1.0, 20.0);
      final int steps = (distance / spacing).ceil().clamp(1, 500);

      for (int step = 0; step <= steps; step++) {
        final double amount = step / steps;

        _stampCircle(
          output: output,
          original: original,
          center: Offset.lerp(start, end, amount)!,
          radius: radius,
          restore: stroke.restore,
          softness: stroke.softness,
        );
      }
    }
  }

  void _stampCircle({
    required img.Image output,
    required img.Image original,
    required Offset center,
    required double radius,
    required bool restore,
    required double softness,
  }) {
    final int left = (center.dx - radius).floor().clamp(0, output.width - 1);
    final int right = (center.dx + radius).ceil().clamp(0, output.width - 1);
    final int top = (center.dy - radius).floor().clamp(0, output.height - 1);
    final int bottom = (center.dy + radius).ceil().clamp(0, output.height - 1);

    final double hardEdge = radius * (1 - softness.clamp(0.0, 0.95));

    for (int y = top; y <= bottom; y++) {
      for (int x = left; x <= right; x++) {
        final double dx = x - center.dx;
        final double dy = y - center.dy;
        final double distance = (dx * dx + dy * dy).sqrt();

        if (distance > radius) {
          continue;
        }

        double strength = 1;

        if (distance > hardEdge && radius > hardEdge) {
          strength = 1 - ((distance - hardEdge) / (radius - hardEdge));
        }

        strength = strength.clamp(0.0, 1.0);

        final img.Pixel current = output.getPixel(x, y);
        final img.Pixel source = original.getPixel(x, y);

        if (restore) {
          final int red = _mix(current.r.toInt(), source.r.toInt(), strength);
          final int green = _mix(current.g.toInt(), source.g.toInt(), strength);
          final int blue = _mix(current.b.toInt(), source.b.toInt(), strength);
          final int alpha = _mix(current.a.toInt(), source.a.toInt(), strength);

          output.setPixelRgba(x, y, red, green, blue, alpha);
        } else {
          final int alpha = (current.a.toInt() * (1 - strength)).round().clamp(
            0,
            255,
          );

          output.setPixelRgba(
            x,
            y,
            current.r.toInt(),
            current.g.toInt(),
            current.b.toInt(),
            alpha,
          );
        }
      }
    }
  }

  int _mix(int from, int to, double amount) {
    return (from + ((to - from) * amount)).round().clamp(0, 255);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cutout Refine Studio'),
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
            tooltip: 'Clear all strokes',
            onPressed: _strokes.isEmpty ? null : _clearAll,
            icon: const Icon(Icons.delete_sweep_outlined),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilledButton.icon(
              onPressed: _strokes.isEmpty || _isSaving ? null : _save,
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
                child: LayoutBuilder(
                  builder: (BuildContext context, BoxConstraints constraints) {
                    final Size canvasSize = Size(
                      constraints.maxWidth,
                      constraints.maxHeight,
                    );

                    return GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onPanStart: (DragStartDetails details) {
                        _startStroke(details, canvasSize);
                      },
                      onPanUpdate: (DragUpdateDetails details) {
                        _continueStroke(details, canvasSize);
                      },
                      onPanEnd: _endStroke,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          const CustomPaint(painter: _MaskCheckerPainter()),
                          Image.file(
                            File(widget.sourcePath),
                            fit: BoxFit.contain,
                            filterQuality: FilterQuality.high,
                          ),
                          IgnorePointer(
                            child: CustomPaint(
                              painter: _MaskStrokePreviewPainter(
                                strokes: _strokes,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
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
                        selected: !_restoreMode,
                        avatar: const Icon(
                          Icons.auto_fix_normal_rounded,
                          size: 18,
                        ),
                        label: const Text('Erase Background'),
                        onSelected: (_) {
                          setState(() => _restoreMode = false);
                        },
                      ),
                      const SizedBox(width: 8),
                      FilterChip(
                        selected: _restoreMode,
                        avatar: const Icon(Icons.restore_rounded, size: 18),
                        label: const Text('Restore Foreground'),
                        onSelected: (_) {
                          setState(() => _restoreMode = true);
                        },
                      ),
                      const SizedBox(width: 12),
                      const Text('Size'),
                      Expanded(
                        child: Slider(
                          value: _brushSize,
                          min: 8,
                          max: 160,
                          divisions: 38,
                          label: _brushSize.round().toString(),
                          onChanged: (double value) {
                            setState(() => _brushSize = value);
                          },
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      const SizedBox(width: 74, child: Text('Softness')),
                      Expanded(
                        child: Slider(
                          value: _softness,
                          min: 0,
                          max: 0.95,
                          divisions: 19,
                          label: '${(_softness * 100).round()}%',
                          onChanged: (double value) {
                            setState(() => _softness = value);
                          },
                        ),
                      ),
                    ],
                  ),
                  Text(
                    _restoreMode
                        ? 'Restore mode: marked areas return from the original photo.'
                        : 'Erase mode: marked areas will become transparent.',
                    style: const TextStyle(color: Colors.white60, fontSize: 11),
                    textAlign: TextAlign.center,
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

class _MaskStroke {
  _MaskStroke({
    required this.points,
    required this.restore,
    required this.brushSize,
    required this.softness,
  });

  final List<Offset> points;
  final bool restore;
  final double brushSize;
  final double softness;
}

class _MaskStrokePreviewPainter extends CustomPainter {
  const _MaskStrokePreviewPainter({required this.strokes});

  final List<_MaskStroke> strokes;

  @override
  void paint(Canvas canvas, Size size) {
    for (final _MaskStroke stroke in strokes) {
      if (stroke.points.isEmpty) {
        continue;
      }

      final Paint paint = Paint()
        ..color = stroke.restore
            ? Colors.lightGreenAccent.withValues(alpha: 0.55)
            : Colors.redAccent.withValues(alpha: 0.42)
        ..strokeWidth = stroke.brushSize
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke
        ..isAntiAlias = true;

      Offset convert(Offset point) {
        return Offset(point.dx * size.width, point.dy * size.height);
      }

      if (stroke.points.length == 1) {
        canvas.drawCircle(
          convert(stroke.points.first),
          stroke.brushSize / 2,
          Paint()..color = paint.color,
        );
        continue;
      }

      final Path path = Path();
      final Offset first = convert(stroke.points.first);
      path.moveTo(first.dx, first.dy);

      for (int index = 1; index < stroke.points.length; index++) {
        final Offset point = convert(stroke.points[index]);
        path.lineTo(point.dx, point.dy);
      }

      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _MaskStrokePreviewPainter oldDelegate) {
    return true;
  }
}

class _MaskCheckerPainter extends CustomPainter {
  const _MaskCheckerPainter();

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
  bool shouldRepaint(covariant _MaskCheckerPainter oldDelegate) {
    return false;
  }
}

extension on double {
  double sqrt() {
    if (this <= 0) {
      return 0;
    }

    double guess = this / 2;

    for (int index = 0; index < 12; index++) {
      guess = (guess + this / guess) / 2;
    }

    return guess;
  }
}
