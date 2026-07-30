import 'dart:io';

import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../services/image/image_import_service.dart';
import '../models/editor_image.dart';

class EditorScreen extends StatefulWidget {
  const EditorScreen({super.key, required this.projectName, this.initialImage});

  final String projectName;
  final EditorImage? initialImage;

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen> {
  int _selectedTool = 0;
  EditorImage? _editorImage;
  bool _isImporting = false;
  double _brightness = 0;
  double _contrast = 0;
  double _saturation = 0;

  @override
  void initState() {
    super.initState();
    _editorImage = widget.initialImage;
  }

  Future<void> _pickImage() async {
    if (_isImporting) {
      return;
    }

    setState(() => _isImporting = true);

    try {
      final EditorImage? image = await ImageImportService.instance
          .pickFromGallery();

      if (!mounted || image == null) {
        return;
      }

      setState(() {
        _editorImage = image;
        _brightness = 0;
        _contrast = 0;
        _saturation = 0;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not open photo: $error')));
    } finally {
      if (mounted) {
        setState(() => _isImporting = false);
      }
    }
  }

  static const List<_EditorTool> _tools = [
    _EditorTool('Move', Icons.open_with_rounded),
    _EditorTool('Crop', Icons.crop_rounded),
    _EditorTool('Adjust', Icons.tune_rounded),
    _EditorTool('Filters', Icons.filter_vintage_outlined),
    _EditorTool('Retouch', Icons.auto_fix_high_rounded),
    _EditorTool('Text', Icons.text_fields_rounded),
    _EditorTool('Layers', Icons.layers_outlined),
    _EditorTool('More', Icons.more_horiz_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF06070A),
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(),
            Expanded(child: _buildWorkspace()),
            _buildToolPanel(),
            _buildBottomToolbar(),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Container(
      height: 58,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: const BoxDecoration(
        color: AppTheme.background,
        border: Border(bottom: BorderSide(color: Colors.white10)),
      ),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Back',
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.arrow_back_rounded),
          ),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.projectName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
                const Text(
                  '1080 × 1080 px',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 10),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Undo',
            onPressed: null,
            icon: const Icon(Icons.undo_rounded),
          ),
          IconButton(
            tooltip: 'Redo',
            onPressed: null,
            icon: const Icon(Icons.redo_rounded),
          ),
          const SizedBox(width: 4),
          FilledButton(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Export tools will be activated next.'),
                ),
              );
            },
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              minimumSize: const Size(0, 38),
            ),
            child: const Text(
              'Export',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
    );
  }

  Widget _buildWorkspace() {
    final EditorImage? image = _editorImage;

    return Container(
      color: const Color(0xFF0B0D12),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final double maximumWidth = constraints.maxWidth - 40;
          final double maximumHeight = constraints.maxHeight - 40;

          double canvasWidth = 310;
          double canvasHeight = 310;

          if (image != null && image.width > 0 && image.height > 0) {
            final double aspectRatio = image.width / image.height;

            if (aspectRatio >= 1) {
              canvasWidth = maximumWidth.clamp(220, 620);
              canvasHeight = canvasWidth / aspectRatio;

              if (canvasHeight > maximumHeight) {
                canvasHeight = maximumHeight;
                canvasWidth = canvasHeight * aspectRatio;
              }
            } else {
              canvasHeight = maximumHeight.clamp(220, 620);
              canvasWidth = canvasHeight * aspectRatio;

              if (canvasWidth > maximumWidth) {
                canvasWidth = maximumWidth;
                canvasHeight = canvasWidth / aspectRatio;
              }
            }
          }

          return InteractiveViewer(
            minScale: 0.35,
            maxScale: 8,
            boundaryMargin: const EdgeInsets.all(300),
            child: Center(
              child: Container(
                width: canvasWidth,
                height: canvasHeight,
                decoration: BoxDecoration(
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black87,
                      blurRadius: 30,
                      offset: Offset(0, 18),
                    ),
                  ],
                  border: Border.all(color: Colors.white24),
                ),
                child: image == null
                    ? _buildEmptyCanvas()
                    : _buildImageCanvas(image),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyCanvas() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _pickImage,
        child: CustomPaint(
          painter: const _CheckerboardPainter(),
          child: Center(
            child: _isImporting
                ? const CircularProgressIndicator()
                : const Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.add_photo_alternate_outlined,
                        size: 52,
                        color: Colors.black54,
                      ),
                      SizedBox(height: 12),
                      Text(
                        'Add a photo',
                        style: TextStyle(
                          color: Colors.black87,
                          fontWeight: FontWeight.w900,
                          fontSize: 17,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Tap here to open gallery',
                        style: TextStyle(color: Colors.black54, fontSize: 12),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildImageCanvas(EditorImage image) {
    return Stack(
      fit: StackFit.expand,
      children: [
        CustomPaint(painter: const _CheckerboardPainter()),
        ColorFiltered(
          colorFilter: ColorFilter.matrix(
            _createColorMatrix(
              brightness: _brightness,
              contrast: _contrast,
              saturation: _saturation,
            ),
          ),
          child: Image.file(
            File(image.path),
            fit: BoxFit.contain,
            filterQuality: FilterQuality.high,
            gaplessPlayback: true,
            errorBuilder: (context, error, stackTrace) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text(
                    'Unable to display this image.\n$error',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.black87),
                  ),
                ),
              );
            },
          ),
        ),
        Positioned(
          top: 8,
          right: 8,
          child: Material(
            color: Colors.black54,
            borderRadius: BorderRadius.circular(10),
            child: IconButton(
              tooltip: 'Replace photo',
              onPressed: _pickImage,
              icon: _isImporting
                  ? const SizedBox(
                      width: 19,
                      height: 19,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.image_search_outlined, size: 20),
            ),
          ),
        ),
      ],
    );
  }

  List<double> _createColorMatrix({
    required double brightness,
    required double contrast,
    required double saturation,
  }) {
    final double brightnessOffset = brightness * 2.55;
    final double contrastValue = 1 + (contrast / 100);
    final double saturationValue = 1 + (saturation / 100);

    const double redWeight = 0.2126;
    const double greenWeight = 0.7152;
    const double blueWeight = 0.0722;

    final double inverseSaturation = 1 - saturationValue;

    final List<double> saturationMatrix = [
      inverseSaturation * redWeight + saturationValue,
      inverseSaturation * greenWeight,
      inverseSaturation * blueWeight,
      0,
      0,
      inverseSaturation * redWeight,
      inverseSaturation * greenWeight + saturationValue,
      inverseSaturation * blueWeight,
      0,
      0,
      inverseSaturation * redWeight,
      inverseSaturation * greenWeight,
      inverseSaturation * blueWeight + saturationValue,
      0,
      0,
      0,
      0,
      0,
      1,
      0,
    ];

    final double contrastOffset = 128 * (1 - contrastValue);

    final List<double> contrastBrightnessMatrix = [
      contrastValue,
      0,
      0,
      0,
      contrastOffset + brightnessOffset,
      0,
      contrastValue,
      0,
      0,
      contrastOffset + brightnessOffset,
      0,
      0,
      contrastValue,
      0,
      contrastOffset + brightnessOffset,
      0,
      0,
      0,
      1,
      0,
    ];

    return _multiplyColorMatrices(contrastBrightnessMatrix, saturationMatrix);
  }

  List<double> _multiplyColorMatrices(List<double> first, List<double> second) {
    final List<double> result = List<double>.filled(20, 0);

    for (int row = 0; row < 4; row++) {
      for (int column = 0; column < 5; column++) {
        double value = column == 4 ? first[(row * 5) + 4] : 0;

        for (int index = 0; index < 4; index++) {
          value += first[(row * 5) + index] * second[(index * 5) + column];
        }

        result[(row * 5) + column] = value;
      }
    }

    return result;
  }

  Widget _buildToolPanel() {
    if (_selectedTool == 2) {
      return Container(
        padding: const EdgeInsets.fromLTRB(18, 13, 18, 10),
        decoration: const BoxDecoration(
          color: AppTheme.surface,
          border: Border(top: BorderSide(color: Colors.white10)),
        ),
        child: Column(
          children: [
            _AdjustmentSlider(
              label: 'Brightness',
              value: _brightness,
              onChanged: (value) {
                setState(() => _brightness = value);
              },
            ),
            _AdjustmentSlider(
              label: 'Contrast',
              value: _contrast,
              onChanged: (value) {
                setState(() => _contrast = value);
              },
            ),
            _AdjustmentSlider(
              label: 'Saturation',
              value: _saturation,
              onChanged: (value) {
                setState(() => _saturation = value);
              },
            ),
          ],
        ),
      );
    }

    if (_selectedTool == 6) {
      return Container(
        height: 86,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: const BoxDecoration(
          color: AppTheme.surface,
          border: Border(top: BorderSide(color: Colors.white10)),
        ),
        child: Row(
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.primary, width: 2),
              ),
              child: const CustomPaint(painter: _CheckerboardPainter()),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Background',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  SizedBox(height: 3),
                  Text(
                    'Base canvas layer',
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Layer visibility',
              onPressed: () {},
              icon: const Icon(Icons.visibility_outlined),
            ),
            IconButton(
              tooltip: 'Add layer',
              onPressed: () {},
              icon: const Icon(Icons.add_box_outlined),
            ),
          ],
        ),
      );
    }

    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        border: Border(top: BorderSide(color: Colors.white10)),
      ),
      child: Row(
        children: [
          Icon(_tools[_selectedTool].icon, size: 18, color: AppTheme.primary),
          const SizedBox(width: 9),
          Text(
            '${_tools[_selectedTool].label} tool selected',
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
          ),
          const Spacer(),
          TextButton(onPressed: () {}, child: const Text('Reset')),
        ],
      ),
    );
  }

  Widget _buildBottomToolbar() {
    return Container(
      height: 78,
      decoration: const BoxDecoration(
        color: AppTheme.background,
        border: Border(top: BorderSide(color: Colors.white10)),
      ),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 7),
        itemCount: _tools.length,
        itemBuilder: (context, index) {
          final tool = _tools[index];
          final selected = _selectedTool == index;

          return InkWell(
            onTap: () {
              setState(() => _selectedTool = index);
            },
            borderRadius: BorderRadius.circular(15),
            child: SizedBox(
              width: 72,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: 38,
                    height: 34,
                    decoration: BoxDecoration(
                      color: selected
                          ? AppTheme.primary.withValues(alpha: 0.18)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      tool.icon,
                      size: 21,
                      color: selected
                          ? AppTheme.primary
                          : AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    tool.label,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
                      color: selected ? Colors.white : AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _AdjustmentSlider extends StatelessWidget {
  const _AdjustmentSlider({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final double value;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 76,
          child: Text(
            label,
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11),
          ),
        ),
        Expanded(
          child: Slider(
            value: value,
            min: -100,
            max: 100,
            onChanged: onChanged,
          ),
        ),
        SizedBox(
          width: 38,
          child: Text(
            value.round().toString(),
            textAlign: TextAlign.end,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }
}

class _EditorTool {
  const _EditorTool(this.label, this.icon);

  final String label;
  final IconData icon;
}

class _CheckerboardPainter extends CustomPainter {
  const _CheckerboardPainter();

  @override
  void paint(Canvas canvas, Size size) {
    const cellSize = 18.0;
    final lightPaint = Paint()..color = const Color(0xFFF1F1F1);
    final darkPaint = Paint()..color = const Color(0xFFD7D7D7);

    canvas.drawRect(Offset.zero & size, lightPaint);

    for (double y = 0; y < size.height; y += cellSize) {
      for (double x = 0; x < size.width; x += cellSize) {
        final row = (y / cellSize).floor();
        final column = (x / cellSize).floor();

        if ((row + column).isOdd) {
          canvas.drawRect(Rect.fromLTWH(x, y, cellSize, cellSize), darkPaint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
