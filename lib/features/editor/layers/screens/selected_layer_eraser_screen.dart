import 'dart:io';
import 'dart:math' as math;
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

  final TransformationController _transformationController =
      TransformationController();

  bool _restoreMode = false;
  bool _navigationMode = false;
  bool _showBefore = false;
  bool _isSaving = false;
  bool _isLoading = true;

  double _brushSize = 44;
  double _softness = 0.25;

  int _imageWidth = 1;
  int _imageHeight = 1;

  _MaskStroke? _activeStroke;
  Offset? _cursorPoint;
  double _cursorBrushFraction = 0;

  @override
  void initState() {
    super.initState();
    _loadImageSize();
  }

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }

  Future<void> _loadImageSize() async {
    try {
      final Uint8List bytes = await File(widget.sourcePath).readAsBytes();

      final img.Image? decoded = img.decodeImage(bytes);

      if (decoded == null) {
        throw StateError('Selected layer could not be decoded.');
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _imageWidth = decoded.width;
        _imageHeight = decoded.height;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() => _isLoading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Image could not be opened: $error')),
      );
    }
  }

  void _startStroke(DragStartDetails details, Size canvasSize) {
    if (_navigationMode ||
        _showBefore ||
        canvasSize.width <= 0 ||
        canvasSize.height <= 0) {
      return;
    }

    final Offset point = _normalisePoint(details.localPosition, canvasSize);

    final double shortestSide = math.min(canvasSize.width, canvasSize.height);

    final _MaskStroke stroke = _MaskStroke(
      points: <Offset>[point],
      restore: _restoreMode,
      brushFraction: _brushSize / shortestSide,
      softness: _softness,
    );

    setState(() {
      _activeStroke = stroke;
      _strokes.add(stroke);
      _redoStrokes.clear();
      _cursorPoint = point;
      _cursorBrushFraction = stroke.brushFraction;
    });
  }

  void _continueStroke(DragUpdateDetails details, Size canvasSize) {
    final _MaskStroke? stroke = _activeStroke;

    if (stroke == null ||
        _navigationMode ||
        _showBefore ||
        canvasSize.width <= 0 ||
        canvasSize.height <= 0) {
      return;
    }

    final Offset point = _normalisePoint(details.localPosition, canvasSize);

    setState(() {
      stroke.points.add(point);
      _cursorPoint = point;
      _cursorBrushFraction = stroke.brushFraction;
    });
  }

  void _endStroke(DragEndDetails details) {
    setState(() {
      _activeStroke = null;
      _cursorPoint = null;
    });
  }

  void _cancelStroke() {
    setState(() {
      _activeStroke = null;
      _cursorPoint = null;
    });
  }

  Offset _normalisePoint(Offset point, Size size) {
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
      _cursorPoint = null;
    });
  }

  void _redo() {
    if (_redoStrokes.isEmpty) {
      return;
    }

    setState(() {
      _strokes.add(_redoStrokes.removeLast());
      _cursorPoint = null;
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
      _cursorPoint = null;
    });
  }

  void _resetZoom() {
    _transformationController.value = Matrix4.identity();
  }

  void _zoomBy(double factor) {
    final Matrix4 matrix = _transformationController.value.clone();

    final double currentScale = matrix.getMaxScaleOnAxis();

    final double targetScale = (currentScale * factor).clamp(1.0, 8.0);

    final double scaleChange = targetScale / currentScale;

    matrix.scaleByDouble(scaleChange, scaleChange, 1, 1);

    _transformationController.value = matrix;
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
        SnackBar(content: Text('Cutout refinement could not be saved: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<File> _renderOutput() async {
    final File currentFile = File(widget.sourcePath);
    final File originalFile = File(widget.originalSourcePath);

    if (!await currentFile.exists()) {
      throw StateError('Current cutout image is unavailable.');
    }

    if (!await originalFile.exists()) {
      throw StateError('Original foreground image is unavailable.');
    }

    final Uint8List currentBytes = await currentFile.readAsBytes();

    final Uint8List originalBytes = await originalFile.readAsBytes();

    final img.Image? current = img.decodeImage(currentBytes);

    img.Image? original = img.decodeImage(originalBytes);

    if (current == null || original == null) {
      throw StateError('Cutout images could not be decoded.');
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
      '${documents.path}/PhotoForge Refined Cutouts',
    );

    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }

    final File outputFile = File(
      '${directory.path}/refined_'
      '${DateTime.now().microsecondsSinceEpoch}.png',
    );

    await outputFile.writeAsBytes(img.encodePng(output), flush: true);

    return outputFile;
  }

  void _applyStroke({
    required img.Image output,
    required img.Image original,
    required _MaskStroke stroke,
  }) {
    if (stroke.points.isEmpty) {
      return;
    }

    final double shortestSide = math
        .min(output.width, output.height)
        .toDouble();

    final double radius = (stroke.brushFraction * shortestSide / 2).clamp(
      1.0,
      shortestSide / 2,
    );

    final List<Offset> pixelPoints = stroke.points
        .map(
          (Offset point) =>
              Offset(point.dx * output.width, point.dy * output.height),
        )
        .toList();

    if (pixelPoints.length == 1) {
      _stampCircle(
        output: output,
        original: original,
        center: pixelPoints.first,
        radius: radius,
        restore: stroke.restore,
        softness: stroke.softness,
      );

      return;
    }

    for (int index = 1; index < pixelPoints.length; index++) {
      final Offset start = pixelPoints[index - 1];
      final Offset end = pixelPoints[index];

      final double distance = (end - start).distance;

      final double spacing = (radius * 0.25).clamp(1.0, 20.0);

      final int steps = (distance / spacing).ceil().clamp(1, 1000);

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

        final double distance = math.sqrt(dx * dx + dy * dy);

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
          output.setPixelRgba(
            x,
            y,
            _mix(current.r.toInt(), source.r.toInt(), strength),
            _mix(current.g.toInt(), source.g.toInt(), strength),
            _mix(current.b.toInt(), source.b.toInt(), strength),
            _mix(current.a.toInt(), source.a.toInt(), strength),
          );
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
            tooltip: 'Undo brush stroke',
            onPressed: _strokes.isEmpty ? null : _undo,
            icon: const Icon(Icons.undo_rounded),
          ),
          IconButton(
            tooltip: 'Redo brush stroke',
            onPressed: _redoStrokes.isEmpty ? null : _redo,
            icon: const Icon(Icons.redo_rounded),
          ),
          IconButton(
            tooltip: 'Clear all brush strokes',
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
          _buildViewToolbar(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _buildRefineCanvas(),
          ),
          _buildBottomControls(),
        ],
      ),
    );
  }

  Widget _buildViewToolbar() {
    return Material(
      color: const Color(0xFF1B1E23),
      child: SizedBox(
        height: 52,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          children: [
            FilterChip(
              selected: !_showBefore,
              avatar: const Icon(Icons.visibility_rounded, size: 18),
              label: const Text('After'),
              onSelected: (_) {
                setState(() {
                  _showBefore = false;
                });
              },
            ),
            const SizedBox(width: 8),
            FilterChip(
              selected: _showBefore,
              avatar: const Icon(Icons.photo_outlined, size: 18),
              label: const Text('Before'),
              onSelected: (_) {
                setState(() {
                  _showBefore = true;
                  _cursorPoint = null;
                });
              },
            ),
            const SizedBox(width: 12),
            FilterChip(
              selected: _navigationMode,
              avatar: const Icon(Icons.pan_tool_alt_rounded, size: 18),
              label: const Text('Zoom / Pan'),
              onSelected: (bool selected) {
                setState(() {
                  _navigationMode = selected;
                  _cursorPoint = null;
                });
              },
            ),
            IconButton(
              tooltip: 'Zoom out',
              onPressed: () => _zoomBy(0.8),
              icon: const Icon(Icons.zoom_out_rounded),
            ),
            IconButton(
              tooltip: 'Zoom in',
              onPressed: () => _zoomBy(1.25),
              icon: const Icon(Icons.zoom_in_rounded),
            ),
            IconButton(
              tooltip: 'Reset zoom',
              onPressed: _resetZoom,
              icon: const Icon(Icons.center_focus_strong_rounded),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRefineCanvas() {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double widthScale = constraints.maxWidth / _imageWidth;

        final double heightScale = constraints.maxHeight / _imageHeight;

        final double fitScale = math.min(widthScale, heightScale);

        final Size imageSize = Size(
          _imageWidth * fitScale,
          _imageHeight * fitScale,
        );

        return ClipRect(
          child: InteractiveViewer(
            transformationController: _transformationController,
            constrained: false,
            minScale: 1,
            maxScale: 8,
            panEnabled: _navigationMode,
            scaleEnabled: _navigationMode,
            boundaryMargin: const EdgeInsets.all(500),
            child: SizedBox(
              width: constraints.maxWidth,
              height: constraints.maxHeight,
              child: Center(
                child: SizedBox(
                  width: imageSize.width,
                  height: imageSize.height,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onPanStart: _navigationMode || _showBefore
                        ? null
                        : (DragStartDetails details) {
                            _startStroke(details, imageSize);
                          },
                    onPanUpdate: _navigationMode || _showBefore
                        ? null
                        : (DragUpdateDetails details) {
                            _continueStroke(details, imageSize);
                          },
                    onPanEnd: _navigationMode || _showBefore
                        ? null
                        : _endStroke,
                    onPanCancel: _navigationMode || _showBefore
                        ? null
                        : _cancelStroke,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        const CustomPaint(painter: _CheckerboardPainter()),
                        Image.file(
                          File(
                            _showBefore
                                ? widget.originalSourcePath
                                : widget.sourcePath,
                          ),
                          fit: BoxFit.fill,
                          filterQuality: FilterQuality.high,
                        ),
                        if (!_showBefore)
                          IgnorePointer(
                            child: CustomPaint(
                              painter: _StrokePreviewPainter(
                                strokes: _strokes,
                                cursorPoint: _cursorPoint,
                                cursorBrushFraction: _cursorBrushFraction,
                                restoreMode: _restoreMode,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildBottomControls() {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 9, 12, 10),
        decoration: const BoxDecoration(
          color: Color(0xFF171A1F),
          border: Border(top: BorderSide(color: Colors.white12)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: FilterChip(
                    selected: !_restoreMode,
                    avatar: const Icon(Icons.auto_fix_normal_rounded, size: 18),
                    label: const Text('Erase Background'),
                    onSelected: _showBefore
                        ? null
                        : (_) {
                            setState(() {
                              _restoreMode = false;
                              _navigationMode = false;
                            });
                          },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilterChip(
                    selected: _restoreMode,
                    avatar: const Icon(Icons.restore_rounded, size: 18),
                    label: const Text('Restore Foreground'),
                    onSelected: _showBefore
                        ? null
                        : (_) {
                            setState(() {
                              _restoreMode = true;
                              _navigationMode = false;
                            });
                          },
                  ),
                ),
              ],
            ),
            Row(
              children: [
                const SizedBox(
                  width: 72,
                  child: Text('Brush Size', style: TextStyle(fontSize: 11)),
                ),
                Expanded(
                  child: Slider(
                    value: _brushSize,
                    min: 8,
                    max: 180,
                    divisions: 43,
                    label: _brushSize.round().toString(),
                    onChanged: _showBefore
                        ? null
                        : (double value) {
                            setState(() {
                              _brushSize = value;
                            });
                          },
                  ),
                ),
                SizedBox(
                  width: 34,
                  child: Text(
                    _brushSize.round().toString(),
                    textAlign: TextAlign.end,
                    style: const TextStyle(fontSize: 11),
                  ),
                ),
              ],
            ),
            Row(
              children: [
                const SizedBox(
                  width: 72,
                  child: Text('Softness', style: TextStyle(fontSize: 11)),
                ),
                Expanded(
                  child: Slider(
                    value: _softness,
                    min: 0,
                    max: 0.95,
                    divisions: 19,
                    label: '${(_softness * 100).round()}%',
                    onChanged: _showBefore
                        ? null
                        : (double value) {
                            setState(() {
                              _softness = value;
                            });
                          },
                  ),
                ),
                SizedBox(
                  width: 38,
                  child: Text(
                    '${(_softness * 100).round()}%',
                    textAlign: TextAlign.end,
                    style: const TextStyle(fontSize: 11),
                  ),
                ),
              ],
            ),
            Text(
              _showBefore
                  ? 'Before preview is read-only.'
                  : _navigationMode
                  ? 'Drag to pan and pinch to zoom.'
                  : _restoreMode
                  ? 'Green brush restores pixels from the original photo.'
                  : 'Red brush removes pixels to transparency.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white60, fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }
}

class _MaskStroke {
  _MaskStroke({
    required this.points,
    required this.restore,
    required this.brushFraction,
    required this.softness,
  });

  final List<Offset> points;
  final bool restore;
  final double brushFraction;
  final double softness;
}

class _StrokePreviewPainter extends CustomPainter {
  const _StrokePreviewPainter({
    required this.strokes,
    required this.cursorPoint,
    required this.cursorBrushFraction,
    required this.restoreMode,
  });

  final List<_MaskStroke> strokes;
  final Offset? cursorPoint;
  final double cursorBrushFraction;
  final bool restoreMode;

  @override
  void paint(Canvas canvas, Size size) {
    final double shortestSide = math.min(size.width, size.height);

    for (final _MaskStroke stroke in strokes) {
      if (stroke.points.isEmpty) {
        continue;
      }

      final double strokeWidth = stroke.brushFraction * shortestSide;

      final Paint paint = Paint()
        ..color = stroke.restore
            ? Colors.lightGreenAccent.withValues(alpha: 0.48)
            : Colors.redAccent.withValues(alpha: 0.40)
        ..strokeWidth = strokeWidth
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
          strokeWidth / 2,
          Paint()
            ..color = paint.color
            ..isAntiAlias = true,
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

    final Offset? cursor = cursorPoint;

    if (cursor != null && cursorBrushFraction > 0) {
      final Offset center = Offset(
        cursor.dx * size.width,
        cursor.dy * size.height,
      );

      final double radius = cursorBrushFraction * shortestSide / 2;

      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..color = restoreMode ? Colors.lightGreenAccent : Colors.redAccent
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..isAntiAlias = true,
      );

      canvas.drawCircle(
        center,
        2.5,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.fill
          ..isAntiAlias = true,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _StrokePreviewPainter oldDelegate) {
    return true;
  }
}

class _CheckerboardPainter extends CustomPainter {
  const _CheckerboardPainter();

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
  bool shouldRepaint(covariant _CheckerboardPainter oldDelegate) {
    return false;
  }
}
