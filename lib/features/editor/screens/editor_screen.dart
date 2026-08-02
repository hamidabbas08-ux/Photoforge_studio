import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/theme/app_theme.dart';
import '../../../services/export/image_export_service.dart';
import '../../../services/image/image_import_service.dart';
import '../models/editor_image.dart';
import '../models/photo_filter_preset.dart';
import '../project/models/photoforge_project.dart';
import '../project/services/project_file_service.dart';
import '../layers/controllers/layer_controller.dart';
import '../layers/models/editor_layer.dart';
import '../layers/models/layer_blend_mapper.dart';
import '../layers/widgets/layer_blend_mask.dart';

class EditorScreen extends StatefulWidget {
  const EditorScreen({
    super.key,
    required this.projectName,
    this.initialImage,
    this.initialProject,
  });

  final String projectName;
  final EditorImage? initialImage;
  final PhotoForgeProject? initialProject;

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen> {
  final LayerController _layerController = LayerController();
  int _selectedTool = 0;
  EditorImage? _editorImage;
  bool _isImporting = false;
  bool _isExporting = false;
  bool _isSavingProject = false;
  Size _lastCanvasSize = Size.zero;

  double _brightness = 0;
  double _contrast = 0;
  double _saturation = 0;
  String _selectedFilterId = 'original';

  int _quarterTurns = 0;
  bool _flipHorizontal = false;
  bool _flipVertical = false;
  double? _cropAspectRatio;

  Offset _gestureStartOffset = Offset.zero;
  Offset _gestureStartFocalPoint = Offset.zero;
  double _gestureStartScaleX = 1;
  double _gestureStartScaleY = 1;
  double _gestureStartRotation = 0;

  final List<_EditorSnapshot> _undoHistory = [];
  final List<_EditorSnapshot> _redoHistory = [];

  static const List<_EditorTool> _tools = [
    _EditorTool('Move', Icons.open_with_rounded),
    _EditorTool('Crop', Icons.crop_rounded),
    _EditorTool('Adjust', Icons.tune_rounded),
    _EditorTool('Transform', Icons.transform_rounded),
    _EditorTool('Filters', Icons.filter_vintage_outlined),
    _EditorTool('Retouch', Icons.auto_fix_high_rounded),
    _EditorTool('Text', Icons.text_fields_rounded),
    _EditorTool('Layers', Icons.layers_outlined),
  ];

  @override
  void initState() {
    super.initState();

    final PhotoForgeProject? project = widget.initialProject;

    if (project != null) {
      _restoreProject(project);
    } else {
      _editorImage = widget.initialImage;

      final String? imagePath = widget.initialImage?.path;

      if (imagePath != null && imagePath.isNotEmpty) {
        _layerController.replaceAllWithImage(imagePath);
      }
    }
  }

  void _restoreProject(PhotoForgeProject project) {
    final List<EditorLayer> restoredLayers = project.layers
        .map(
          (PhotoForgeProjectLayer layer) => EditorLayer(
            id: layer.id,
            name: layer.name,
            type: _parseLayerType(layer.type),
            imagePath: layer.imagePath,
            isVisible: layer.isVisible,
            isLocked: layer.isLocked,
            opacity: layer.opacity,
            blendMode: _parseBlendMode(layer.blendMode),
            offset: Offset(layer.offsetX, layer.offsetY),
            scaleX: layer.scaleX,
            scaleY: layer.scaleY,
            rotation: layer.rotation,
          ),
        )
        .toList();

    _layerController.replaceAllLayers(layers: restoredLayers);

    String? baseImagePath;

    for (final EditorLayer layer in restoredLayers) {
      final String? imagePath = layer.imagePath;

      if (imagePath != null &&
          imagePath.isNotEmpty &&
          File(imagePath).existsSync()) {
        baseImagePath = imagePath;
        break;
      }
    }

    if (baseImagePath != null) {
      _editorImage = EditorImage(
        path: baseImagePath,
        width: project.canvasWidth,
        height: project.canvasHeight,
      );
    }

    _brightness = project.brightness;
    _contrast = project.contrast;
    _saturation = project.saturation;
    _selectedFilterId = project.filterId;
    _quarterTurns = project.quarterTurns;
    _flipHorizontal = project.flipHorizontal;
    _flipVertical = project.flipVertical;
    _cropAspectRatio = project.cropAspectRatio;
  }

  EditorLayerType _parseLayerType(String value) {
    return EditorLayerType.values.firstWhere(
      (EditorLayerType type) => type.name == value,
      orElse: () => EditorLayerType.image,
    );
  }

  EditorBlendMode _parseBlendMode(String value) {
    return EditorBlendMode.values.firstWhere(
      (EditorBlendMode mode) => mode.name == value,
      orElse: () => EditorBlendMode.normal,
    );
  }

  @override
  void dispose() {
    _layerController.dispose();
    super.dispose();
  }

  _EditorSnapshot get _currentSnapshot {
    return _EditorSnapshot(
      brightness: _brightness,
      contrast: _contrast,
      saturation: _saturation,
      filterId: _selectedFilterId,
      quarterTurns: _quarterTurns,
      flipHorizontal: _flipHorizontal,
      flipVertical: _flipVertical,
      cropAspectRatio: _cropAspectRatio,
      layers: List<EditorLayer>.from(_layerController.layers),
      selectedLayerId: _layerController.selectedLayerId,
    );
  }

  void _recordHistory() {
    _undoHistory.add(_currentSnapshot);

    if (_undoHistory.length > 50) {
      _undoHistory.removeAt(0);
    }

    _redoHistory.clear();
  }

  void _restoreSnapshot(_EditorSnapshot snapshot) {
    setState(() {
      _brightness = snapshot.brightness;
      _contrast = snapshot.contrast;
      _saturation = snapshot.saturation;
      _selectedFilterId = snapshot.filterId;
      _quarterTurns = snapshot.quarterTurns;
      _flipHorizontal = snapshot.flipHorizontal;
      _flipVertical = snapshot.flipVertical;
      _cropAspectRatio = snapshot.cropAspectRatio;

      _layerController.replaceAllLayers(
        layers: List<EditorLayer>.from(snapshot.layers),
        selectedLayerId: snapshot.selectedLayerId,
      );
    });
  }

  void _undo() {
    if (_undoHistory.isEmpty) {
      return;
    }

    final _EditorSnapshot previous = _undoHistory.removeLast();
    _redoHistory.add(_currentSnapshot);
    _restoreSnapshot(previous);
  }

  void _redo() {
    if (_redoHistory.isEmpty) {
      return;
    }

    final _EditorSnapshot next = _redoHistory.removeLast();
    _undoHistory.add(_currentSnapshot);
    _restoreSnapshot(next);
  }

  void _applyAction(VoidCallback action) {
    _recordHistory();

    setState(action);
  }

  void _applyLayerAction(VoidCallback action) {
    _recordHistory();
    action();

    if (mounted) {
      setState(() {});
    }
  }

  void _resetAll() {
    if (_editorImage == null) {
      return;
    }

    _recordHistory();

    setState(() {
      _brightness = 0;
      _contrast = 0;
      _saturation = 0;
      _selectedFilterId = 'original';
      _quarterTurns = 0;
      _flipHorizontal = false;
      _flipVertical = false;
      _cropAspectRatio = null;
    });
  }

  Future<void> _pickImage({bool addAsLayer = false}) async {
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

      if (addAsLayer && _layerController.hasLayers) {
        _applyLayerAction(
          () => _layerController.addImageLayer(imagePath: image.path),
        );
      } else {
        _layerController.replaceAllWithImage(image.path);

        setState(() {
          _editorImage = image;
          _brightness = 0;
          _contrast = 0;
          _saturation = 0;
          _selectedFilterId = 'original';
          _quarterTurns = 0;
          _flipHorizontal = false;
          _flipVertical = false;
          _cropAspectRatio = null;
          _undoHistory.clear();
          _redoHistory.clear();
        });
      }
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

  Future<void> _showExportSheet() async {
    if (_editorImage == null || _isExporting) {
      return;
    }

    final PhotoExportFormat?
    selectedFormat = await showModalBottomSheet<PhotoExportFormat>(
      context: context,
      backgroundColor: AppTheme.surface,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Export Image',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Export at the original image resolution.',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                ),
                const SizedBox(height: 18),
                _ExportFormatTile(
                  icon: Icons.image_outlined,
                  title: 'PNG',
                  subtitle: 'Lossless quality and transparency support',
                  onTap: () {
                    Navigator.of(sheetContext).pop(PhotoExportFormat.png);
                  },
                ),
                const SizedBox(height: 10),
                _ExportFormatTile(
                  icon: Icons.photo_outlined,
                  title: 'JPG',
                  subtitle: 'High quality with a smaller file size',
                  onTap: () {
                    Navigator.of(sheetContext).pop(PhotoExportFormat.jpg);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );

    if (selectedFormat == null || !mounted) {
      return;
    }

    await _exportImage(selectedFormat);
  }

  Future<void> _exportImage(PhotoExportFormat format) async {
    final EditorImage? image = _editorImage;

    if (image == null || _isExporting) {
      return;
    }

    setState(() => _isExporting = true);

    try {
      final File exportedFile = await ImageExportService.instance.export(
        sourcePath: image.path,
        projectName: widget.projectName,
        layers: [
          for (final EditorLayer layer in _layerController.layers)
            <String, Object?>{
              'imagePath': layer.imagePath,
              'isVisible': layer.isVisible,
              'opacity': layer.opacity,
              'blendMode': layer.blendMode.name,
              'offsetX': layer.offset.dx,
              'offsetY': layer.offset.dy,
              'scaleX': layer.scaleX,
              'scaleY': layer.scaleY,
              'rotation': layer.rotation,
            },
        ],
        previewCanvasWidth: _lastCanvasSize.width,
        previewCanvasHeight: _lastCanvasSize.height,
        brightness: _brightness,
        contrast: _contrast,
        saturation: _saturation,
        filterId: _selectedFilterId,
        quarterTurns: _quarterTurns,
        flipHorizontal: _flipHorizontal,
        flipVertical: _flipVertical,
        cropAspectRatio: _cropAspectRatio,
        format: format,
        jpgQuality: 95,
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Export completed: ${exportedFile.path.split('/').last}',
          ),
        ),
      );

      await SharePlus.instance.share(
        ShareParams(
          title: 'PhotoForge Studio Export',
          text: 'Created with PhotoForge Studio',
          files: [XFile(exportedFile.path)],
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Export failed: $error')));
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
  }

  void _onLayerScaleStart(ScaleStartDetails details, EditorLayer layer) {
    if (layer.isLocked || _selectedTool != 0) {
      return;
    }

    _recordHistory();
    _layerController.selectLayer(layer.id);

    _gestureStartOffset = layer.offset;
    _gestureStartFocalPoint = details.localFocalPoint;
    _gestureStartScaleX = layer.scaleX;
    _gestureStartScaleY = layer.scaleY;
    _gestureStartRotation = layer.rotation;
  }

  void _onLayerScaleUpdate(ScaleUpdateDetails details, EditorLayer layer) {
    if (layer.isLocked || _selectedTool != 0) {
      return;
    }

    final Offset movement = details.localFocalPoint - _gestureStartFocalPoint;

    final double newScaleX = _gestureStartScaleX * details.scale;

    final double newScaleY = _gestureStartScaleY * details.scale;

    final double newRotation = _gestureStartRotation + details.rotation;

    _layerController.setLayerTransform(
      layerId: layer.id,
      offset: _gestureStartOffset + movement,
      scaleX: newScaleX,
      scaleY: newScaleY,
      rotation: newRotation,
    );
  }

  PhotoForgeProject _createProjectDocument() {
    final EditorImage? image = _editorImage;
    final DateTime now = DateTime.now();

    return PhotoForgeProject(
      version: 1,
      projectName: widget.projectName,
      createdAt: now,
      updatedAt: now,
      canvasWidth: image?.width ?? 1080,
      canvasHeight: image?.height ?? 1080,
      layers: [
        for (final EditorLayer layer in _layerController.layers)
          PhotoForgeProjectLayer(
            id: layer.id,
            name: layer.name,
            type: layer.type.name,
            imagePath: layer.imagePath,
            isVisible: layer.isVisible,
            isLocked: layer.isLocked,
            opacity: layer.opacity,
            blendMode: layer.blendMode.name,
            offsetX: layer.offset.dx,
            offsetY: layer.offset.dy,
            scaleX: layer.scaleX,
            scaleY: layer.scaleY,
            rotation: layer.rotation,
          ),
      ],
      brightness: _brightness,
      contrast: _contrast,
      saturation: _saturation,
      filterId: _selectedFilterId,
      quarterTurns: _quarterTurns,
      flipHorizontal: _flipHorizontal,
      flipVertical: _flipVertical,
      cropAspectRatio: _cropAspectRatio,
    );
  }

  Future<void> _saveEditableProject() async {
    if (_isSavingProject || !_layerController.hasLayers) {
      return;
    }

    setState(() => _isSavingProject = true);

    try {
      final PhotoForgeProject project = _createProjectDocument();

      final File savedFile = await ProjectFileService.instance.saveProject(
        project,
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Project saved: ${savedFile.path.split('/').last}'),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Project could not be saved: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _isSavingProject = false);
      }
    }
  }

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
    final EditorImage? image = _editorImage;

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
                Text(
                  image == null
                      ? 'No image selected'
                      : '${image.width} × ${image.height} px',
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Undo',
            onPressed: _undoHistory.isEmpty ? null : _undo,
            icon: const Icon(Icons.undo_rounded),
          ),
          IconButton(
            tooltip: 'Redo',
            onPressed: _redoHistory.isEmpty ? null : _redo,
            icon: const Icon(Icons.redo_rounded),
          ),
          IconButton(
            tooltip: 'Save editable project',
            onPressed: image == null || _isSavingProject
                ? null
                : _saveEditableProject,
            icon: _isSavingProject
                ? const SizedBox(
                    width: 19,
                    height: 19,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save_outlined),
          ),
          FilledButton(
            onPressed: image == null || _isExporting ? null : _showExportSheet,
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
              minimumSize: const Size(0, 38),
              padding: const EdgeInsets.symmetric(horizontal: 14),
            ),
            child: _isExporting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text(
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
          if (image == null) {
            return Center(
              child: SizedBox(
                width: 310,
                height: 310,
                child: _buildEmptyCanvas(),
              ),
            );
          }

          final Size canvasSize = _calculateCanvasSize(
            image: image,
            maximumWidth: math.max(100, constraints.maxWidth - 40),
            maximumHeight: math.max(100, constraints.maxHeight - 40),
          );

          _lastCanvasSize = canvasSize;

          return InteractiveViewer(
            panEnabled: _selectedTool != 0,
            scaleEnabled: _selectedTool != 0,
            minScale: 0.35,
            maxScale: 8,
            boundaryMargin: const EdgeInsets.all(300),
            child: Center(
              child: Container(
                width: canvasSize.width,
                height: canvasSize.height,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white24),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black87,
                      blurRadius: 30,
                      offset: Offset(0, 18),
                    ),
                  ],
                ),
                child: _buildImageCanvas(image),
              ),
            ),
          );
        },
      ),
    );
  }

  Size _calculateCanvasSize({
    required EditorImage image,
    required double maximumWidth,
    required double maximumHeight,
  }) {
    double aspectRatio;

    if (_cropAspectRatio != null) {
      aspectRatio = _cropAspectRatio!;
    } else {
      aspectRatio = image.width / image.height;

      if (_quarterTurns.isOdd) {
        aspectRatio = 1 / aspectRatio;
      }
    }

    double width = maximumWidth;
    double height = width / aspectRatio;

    if (height > maximumHeight) {
      height = maximumHeight;
      width = height * aspectRatio;
    }

    return Size(math.max(100, width), math.max(100, height));
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
    final double scaleX = _flipHorizontal ? -1 : 1;
    final double scaleY = _flipVertical ? -1 : 1;

    return ClipRect(
      child: Stack(
        fit: StackFit.expand,
        children: [
          const CustomPaint(painter: _CheckerboardPainter()),
          ColorFiltered(
            colorFilter: ColorFilter.matrix(
              _multiplyColorMatrices(
                _createColorMatrix(
                  brightness: _brightness,
                  contrast: _contrast,
                  saturation: _saturation,
                ),
                PhotoFilterPreset.byId(_selectedFilterId).previewMatrix,
              ),
            ),
            child: Transform(
              alignment: Alignment.center,
              transform: Matrix4.identity()
                ..scaleByDouble(scaleX, scaleY, 1, 1)
                ..rotateZ(_quarterTurns * math.pi / 2),
              child: AnimatedBuilder(
                animation: _layerController,
                builder: (context, child) {
                  final List<EditorLayer> visibleLayers = _layerController
                      .layers
                      .where(
                        (layer) => layer.isVisible && layer.imagePath != null,
                      )
                      .toList();

                  if (visibleLayers.isEmpty) {
                    return const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.visibility_off_outlined,
                            color: Colors.black45,
                            size: 34,
                          ),
                          SizedBox(height: 9),
                          Text(
                            'All layers are hidden',
                            style: TextStyle(
                              color: Colors.black54,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return Stack(
                    fit: StackFit.expand,
                    children: [
                      for (final EditorLayer layer in visibleLayers)
                        _buildCanvasLayer(layer),
                    ],
                  );
                },
              ),
            ),
          ),
          Positioned(
            top: 8,
            right: 8,
            child: Material(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(10),
              child: IconButton(
                tooltip: 'Replace complete project image',
                onPressed: _isImporting
                    ? null
                    : () {
                        _pickImage();
                      },
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
      ),
    );
  }

  Widget _buildCanvasLayer(EditorLayer layer) {
    final String? imagePath = layer.imagePath;

    if (imagePath == null) {
      return const SizedBox.shrink();
    }

    final bool selected = layer.id == _layerController.selectedLayerId;

    Widget layerImage = Transform(
      alignment: Alignment.center,
      transform: Matrix4.identity()
        ..translateByDouble(layer.offset.dx, layer.offset.dy, 0, 1)
        ..rotateZ(layer.rotation)
        ..scaleByDouble(layer.scaleX, layer.scaleY, 1, 1),
      child: Image.file(
        File(imagePath),
        fit: BoxFit.cover,
        filterQuality: FilterQuality.high,
        gaplessPlayback: true,
        errorBuilder: (context, error, stackTrace) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Layer image unavailable\n$error',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.black87, fontSize: 11),
              ),
            ),
          );
        },
      ),
    );

    layerImage = Opacity(
      opacity: layer.opacity.clamp(0.0, 1.0),
      child: layerImage,
    );

    if (selected && _selectedTool == 0 && !layer.isLocked) {
      layerImage = GestureDetector(
        behavior: HitTestBehavior.opaque,
        onScaleStart: (details) {
          _onLayerScaleStart(details, layer);
        },
        onScaleUpdate: (details) {
          _onLayerScaleUpdate(details, layer);
        },
        child: layerImage,
      );
    }

    if (layer.blendMode != EditorBlendMode.normal) {
      layerImage = LayerBlendMask(
        blendMode: LayerBlendMapper.toFlutterBlendMode(layer.blendMode),
        child: layerImage,
      );
    }

    return Positioned.fill(
      child: Stack(
        fit: StackFit.expand,
        children: [
          layerImage,
          if (selected && (_selectedTool == 0 || _selectedTool == 7))
            IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: AppTheme.primary, width: 2),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildToolPanel() {
    if (_selectedTool == 1) {
      return _buildCropPanel();
    }

    if (_selectedTool == 2) {
      return _buildAdjustPanel();
    }

    if (_selectedTool == 3) {
      return _buildTransformPanel();
    }

    if (_selectedTool == 4) {
      return _buildFiltersPanel();
    }

    if (_selectedTool == 7) {
      return _buildLayersPanel();
    }

    return Container(
      height: 56,
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
          TextButton(onPressed: _resetAll, child: const Text('Reset all')),
        ],
      ),
    );
  }

  Widget _buildCropPanel() {
    final List<_CropPreset> presets = [
      const _CropPreset('Original', null),
      const _CropPreset('1:1', 1),
      const _CropPreset('4:5', 4 / 5),
      const _CropPreset('3:4', 3 / 4),
      const _CropPreset('16:9', 16 / 9),
      const _CropPreset('9:16', 9 / 16),
    ];

    return Container(
      height: 92,
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        border: Border(top: BorderSide(color: Colors.white10)),
      ),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        itemCount: presets.length,
        separatorBuilder: (context, index) => const SizedBox(width: 9),
        itemBuilder: (context, index) {
          final _CropPreset preset = presets[index];
          final bool selected = _cropAspectRatio == preset.aspectRatio;

          return ChoiceChip(
            selected: selected,
            label: Text(preset.label),
            onSelected: (_) {
              if (_editorImage == null) {
                return;
              }

              _applyAction(() {
                _cropAspectRatio = preset.aspectRatio;
              });
            },
          );
        },
      ),
    );
  }

  Widget _buildAdjustPanel() {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 8),
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        border: Border(top: BorderSide(color: Colors.white10)),
      ),
      child: Column(
        children: [
          _AdjustmentSlider(
            label: 'Brightness',
            value: _brightness,
            onChangeStart: (_) => _recordHistory(),
            onChanged: (value) {
              setState(() => _brightness = value);
            },
          ),
          _AdjustmentSlider(
            label: 'Contrast',
            value: _contrast,
            onChangeStart: (_) => _recordHistory(),
            onChanged: (value) {
              setState(() => _contrast = value);
            },
          ),
          _AdjustmentSlider(
            label: 'Saturation',
            value: _saturation,
            onChangeStart: (_) => _recordHistory(),
            onChanged: (value) {
              setState(() => _saturation = value);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildFiltersPanel() {
    final EditorImage? image = _editorImage;

    return Container(
      height: 116,
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        border: Border(top: BorderSide(color: Colors.white10)),
      ),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        itemCount: PhotoFilterPreset.presets.length,
        separatorBuilder: (context, index) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final PhotoFilterPreset preset = PhotoFilterPreset.presets[index];

          final bool selected = preset.id == _selectedFilterId;

          return GestureDetector(
            onTap: image == null
                ? null
                : () {
                    if (preset.id == _selectedFilterId) {
                      return;
                    }

                    _applyAction(() {
                      _selectedFilterId = preset.id;
                    });
                  },
            child: SizedBox(
              width: 74,
              child: Column(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: 64,
                    height: 64,
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(
                        color: selected ? AppTheme.primary : Colors.white12,
                        width: selected ? 2 : 1,
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: image == null
                          ? const CustomPaint(painter: _CheckerboardPainter())
                          : ColorFiltered(
                              colorFilter: ColorFilter.matrix(
                                preset.previewMatrix,
                              ),
                              child: Image.file(
                                File(image.path),
                                fit: BoxFit.cover,
                                cacheWidth: 180,
                                filterQuality: FilterQuality.medium,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    preset.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: selected ? Colors.white : AppTheme.textSecondary,
                      fontSize: 10,
                      fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
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

  Widget _buildTransformPanel() {
    return Container(
      height: 92,
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        border: Border(top: BorderSide(color: Colors.white10)),
      ),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        children: [
          _TransformAction(
            icon: Icons.rotate_left_rounded,
            label: 'Rotate left',
            onTap: () {
              if (_editorImage == null) return;

              _applyAction(() {
                _quarterTurns = (_quarterTurns + 3) % 4;
              });
            },
          ),
          _TransformAction(
            icon: Icons.rotate_right_rounded,
            label: 'Rotate right',
            onTap: () {
              if (_editorImage == null) return;

              _applyAction(() {
                _quarterTurns = (_quarterTurns + 1) % 4;
              });
            },
          ),
          _TransformAction(
            icon: Icons.flip_rounded,
            label: 'Flip H',
            onTap: () {
              if (_editorImage == null) return;

              _applyAction(() {
                _flipHorizontal = !_flipHorizontal;
              });
            },
          ),
          _TransformAction(
            icon: Icons.flip_rounded,
            label: 'Flip V',
            quarterTurns: 1,
            onTap: () {
              if (_editorImage == null) return;

              _applyAction(() {
                _flipVertical = !_flipVertical;
              });
            },
          ),
          _TransformAction(
            icon: Icons.restart_alt_rounded,
            label: 'Reset',
            onTap: _resetAll,
          ),
        ],
      ),
    );
  }

  Future<void> _showLayerProperties(EditorLayer layer) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppTheme.surface,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        return AnimatedBuilder(
          animation: _layerController,
          builder: (context, child) {
            final EditorLayer? currentLayer = _layerController.layers
                .where((item) => item.id == layer.id)
                .firstOrNull;

            if (currentLayer == null) {
              return const SafeArea(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('Layer no longer exists.'),
                ),
              );
            }

            return SafeArea(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  20,
                  4,
                  20,
                  20 + MediaQuery.viewInsetsOf(sheetContext).bottom,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Layer Properties',
                                style: TextStyle(
                                  fontSize: 21,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                currentLayer.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: AppTheme.textSecondary,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: currentLayer.isVisible
                              ? 'Hide layer'
                              : 'Show layer',
                          onPressed: () {
                            _applyLayerAction(
                              () => _layerController.toggleVisibility(
                                currentLayer.id,
                              ),
                            );
                          },
                          icon: Icon(
                            currentLayer.isVisible
                                ? Icons.visibility_rounded
                                : Icons.visibility_off_rounded,
                          ),
                        ),
                        IconButton(
                          tooltip: currentLayer.isLocked
                              ? 'Unlock layer'
                              : 'Lock layer',
                          onPressed: () {
                            _applyLayerAction(
                              () =>
                                  _layerController.toggleLock(currentLayer.id),
                            );
                          },
                          icon: Icon(
                            currentLayer.isLocked
                                ? Icons.lock_rounded
                                : Icons.lock_open_rounded,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    const Text(
                      'Opacity',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: Slider(
                            value: currentLayer.opacity,
                            min: 0,
                            max: 1,
                            divisions: 100,
                            label: '${(currentLayer.opacity * 100).round()}%',
                            onChangeStart: currentLayer.isLocked
                                ? null
                                : (_) {
                                    _recordHistory();
                                  },
                            onChanged: currentLayer.isLocked
                                ? null
                                : (value) {
                                    _layerController.setOpacity(
                                      currentLayer.id,
                                      value,
                                    );
                                  },
                          ),
                        ),
                        SizedBox(
                          width: 48,
                          child: Text(
                            '${(currentLayer.opacity * 100).round()}%',
                            textAlign: TextAlign.end,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    const Text(
                      'Blend Mode',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<EditorBlendMode>(
                      initialValue: currentLayer.blendMode,
                      isExpanded: true,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: AppTheme.surfaceLight,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                      ),
                      items: [
                        for (final EditorBlendMode mode
                            in EditorBlendMode.values)
                          DropdownMenuItem(
                            value: mode,
                            child: Text(LayerBlendMapper.label(mode)),
                          ),
                      ],
                      onChanged: currentLayer.isLocked
                          ? null
                          : (mode) {
                              if (mode == null) {
                                return;
                              }

                              _applyLayerAction(
                                () => _layerController.setBlendMode(
                                  currentLayer.id,
                                  mode,
                                ),
                              );
                            },
                    ),
                    const SizedBox(height: 20),

                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceLight,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white10),
                      ),
                      child: Column(
                        children: [
                          _LayerPropertyRow(
                            label: 'Position',
                            value:
                                'X ${currentLayer.offset.dx.round()}  ·  Y ${currentLayer.offset.dy.round()}',
                          ),
                          const SizedBox(height: 10),
                          _LayerPropertyRow(
                            label: 'Scale',
                            value: '${(currentLayer.scaleX * 100).round()}%',
                          ),
                          const SizedBox(height: 10),
                          _LayerPropertyRow(
                            label: 'Rotation',
                            value:
                                '${(currentLayer.rotation * 180 / 3.141592653589793).round()}°',
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),

                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: currentLayer.isLocked
                            ? null
                            : () {
                                _applyLayerAction(
                                  () => _layerController.resetLayerTransform(
                                    currentLayer.id,
                                  ),
                                );
                              },
                        icon: const Icon(Icons.restart_alt_rounded),
                        label: const Text('Reset Layer Transform'),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () {
                          Navigator.of(sheetContext).pop();
                        },
                        child: const Text('Done'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _renameSelectedLayer(EditorLayer layer) async {
    final TextEditingController controller = TextEditingController(
      text: layer.name,
    );

    final String? newName = await showDialog<String>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Rename Layer'),
          content: TextField(
            controller: controller,
            autofocus: true,
            maxLength: 60,
            textInputAction: TextInputAction.done,
            decoration: const InputDecoration(
              labelText: 'Layer name',
              hintText: 'Enter a layer name',
            ),
            onSubmitted: (String value) {
              final String cleanName = value.trim();

              if (cleanName.isNotEmpty) {
                Navigator.of(dialogContext).pop(cleanName);
              }
            },
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final String cleanName = controller.text.trim();

                if (cleanName.isNotEmpty) {
                  Navigator.of(dialogContext).pop(cleanName);
                }
              },
              child: const Text('Rename'),
            ),
          ],
        );
      },
    );

    controller.dispose();

    if (!mounted || newName == null || newName.trim().isEmpty) {
      return;
    }

    _applyLayerAction(() => _layerController.renameLayer(layer.id, newName));
  }

  Future<void> _confirmDeleteLayer(EditorLayer layer) async {
    final bool? shouldDelete = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Delete Layer?'),
          content: Text(
            '“${layer.name}” will be removed from this project. '
            'This action cannot be undone after saving.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (!mounted || shouldDelete != true) {
      return;
    }

    _applyLayerAction(() => _layerController.deleteLayer(layer.id));

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${layer.name} deleted'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Widget _buildLayersPanel() {
    return AnimatedBuilder(
      animation: _layerController,
      builder: (context, child) {
        final List<EditorLayer> layers = _layerController.layers.reversed
            .toList();

        final EditorLayer? selectedLayer = _layerController.selectedLayer;

        return Container(
          height: 214,
          decoration: const BoxDecoration(
            color: AppTheme.surface,
            border: Border(top: BorderSide(color: Colors.white10)),
          ),
          child: Column(
            children: [
              SizedBox(
                height: 122,
                child: Row(
                  children: [
                    Expanded(
                      child: layers.isEmpty
                          ? const Center(
                              child: Text(
                                'No layers yet',
                                style: TextStyle(
                                  color: AppTheme.textSecondary,
                                  fontSize: 12,
                                ),
                              ),
                            )
                          : ListView.separated(
                              scrollDirection: Axis.horizontal,
                              physics: const BouncingScrollPhysics(),
                              padding: const EdgeInsets.all(12),
                              itemCount: layers.length,
                              separatorBuilder: (context, index) =>
                                  const SizedBox(width: 10),
                              itemBuilder: (context, index) {
                                final EditorLayer layer = layers[index];

                                final bool selected =
                                    layer.id ==
                                    _layerController.selectedLayerId;

                                return _buildLayerCard(layer, selected);
                              },
                            ),
                    ),
                    Container(
                      width: 62,
                      margin: const EdgeInsets.fromLTRB(0, 12, 10, 12),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceLight,
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(color: Colors.white10),
                      ),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(15),
                        onTap: _isImporting
                            ? null
                            : () {
                                _pickImage(addAsLayer: true);
                              },
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _isImporting
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(
                                    Icons.add_photo_alternate_outlined,
                                    color: AppTheme.primary,
                                    size: 27,
                                  ),
                            const SizedBox(height: 7),
                            const Text(
                              'Add Layer',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: AppTheme.textSecondary,
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: selectedLayer == null
                    ? const Center(
                        child: Text(
                          'Select a layer to manage it',
                          style: TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 11,
                          ),
                        ),
                      )
                    : Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 7,
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    selectedLayer.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 12,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    selectedLayer.isLocked
                                        ? 'Layer locked'
                                        : 'Image layer selected',
                                    style: const TextStyle(
                                      color: AppTheme.textSecondary,
                                      fontSize: 9,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            _LayerActionButton(
                              tooltip: selectedLayer.isVisible
                                  ? 'Hide layer'
                                  : 'Show layer',
                              icon: selectedLayer.isVisible
                                  ? Icons.visibility_rounded
                                  : Icons.visibility_off_rounded,
                              onPressed: () {
                                _applyLayerAction(
                                  () => _layerController.toggleVisibility(
                                    selectedLayer.id,
                                  ),
                                );
                              },
                            ),
                            _LayerActionButton(
                              tooltip: selectedLayer.isLocked
                                  ? 'Unlock layer'
                                  : 'Lock layer',
                              icon: selectedLayer.isLocked
                                  ? Icons.lock_rounded
                                  : Icons.lock_open_rounded,
                              onPressed: () {
                                _applyLayerAction(
                                  () => _layerController.toggleLock(
                                    selectedLayer.id,
                                  ),
                                );
                              },
                            ),
                            _LayerActionButton(
                              tooltip: 'Move layer up',
                              icon: Icons.arrow_upward_rounded,
                              onPressed: () {
                                _applyLayerAction(
                                  () => _layerController.moveLayerUp(
                                    selectedLayer.id,
                                  ),
                                );
                              },
                            ),
                            _LayerActionButton(
                              tooltip: 'Move layer down',
                              icon: Icons.arrow_downward_rounded,
                              onPressed: () {
                                _applyLayerAction(
                                  () => _layerController.moveLayerDown(
                                    selectedLayer.id,
                                  ),
                                );
                              },
                            ),
                            _LayerActionButton(
                              tooltip: 'Rename layer',
                              icon: Icons.drive_file_rename_outline_rounded,
                              onPressed: () {
                                _renameSelectedLayer(selectedLayer);
                              },
                            ),
                            _LayerActionButton(
                              tooltip: 'Layer properties',
                              icon: Icons.tune_rounded,
                              onPressed: () {
                                _showLayerProperties(selectedLayer);
                              },
                            ),
                            _LayerActionButton(
                              tooltip: 'Duplicate layer',
                              icon: Icons.copy_rounded,
                              onPressed: selectedLayer.isLocked
                                  ? null
                                  : () {
                                      _applyLayerAction(
                                        () => _layerController.duplicateLayer(
                                          selectedLayer.id,
                                        ),
                                      );
                                    },
                            ),
                            _LayerActionButton(
                              tooltip: 'Delete layer',
                              icon: Icons.delete_outline_rounded,
                              onPressed: selectedLayer.isLocked
                                  ? null
                                  : () {
                                      _confirmDeleteLayer(selectedLayer);
                                    },
                            ),
                          ],
                        ),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLayerCard(EditorLayer layer, bool selected) {
    return GestureDetector(
      onTap: () {
        _layerController.selectLayer(layer.id);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 88,
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: selected
              ? AppTheme.primary.withValues(alpha: 0.16)
              : AppTheme.surfaceLight,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? AppTheme.primary : Colors.white10,
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(9),
                      color: Colors.black26,
                    ),
                    child: layer.imagePath == null
                        ? const CustomPaint(painter: _CheckerboardPainter())
                        : ClipRRect(
                            borderRadius: BorderRadius.circular(9),
                            child: Image.file(
                              File(layer.imagePath!),
                              fit: BoxFit.cover,
                              cacheWidth: 180,
                              errorBuilder: (context, error, stackTrace) {
                                return const Icon(
                                  Icons.broken_image_outlined,
                                  color: AppTheme.textSecondary,
                                );
                              },
                            ),
                          ),
                  ),
                  if (!layer.isVisible)
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: const Center(
                        child: Icon(Icons.visibility_off_rounded, size: 21),
                      ),
                    ),
                  if (layer.isLocked)
                    Positioned(
                      top: 4,
                      right: 4,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.67),
                          borderRadius: BorderRadius.circular(7),
                        ),
                        child: const Icon(Icons.lock_rounded, size: 13),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 5),
            Text(
              layer.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: selected ? Colors.white : AppTheme.textSecondary,
                fontSize: 9,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
              ),
            ),
          ],
        ),
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
        padding: const EdgeInsets.symmetric(horizontal: 7),
        itemCount: _tools.length,
        itemBuilder: (context, index) {
          final _EditorTool tool = _tools[index];
          final bool selected = _selectedTool == index;

          return InkWell(
            onTap: () {
              setState(() => _selectedTool = index);
            },
            borderRadius: BorderRadius.circular(15),
            child: SizedBox(
              width: 76,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: 40,
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

    final List<double> adjustmentMatrix = [
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

    return _multiplyColorMatrices(adjustmentMatrix, saturationMatrix);
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
}

class _LayerPropertyRow extends StatelessWidget {
  const _LayerPropertyRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11),
          ),
        ),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 11),
        ),
      ],
    );
  }
}

class _LayerActionButton extends StatelessWidget {
  const _LayerActionButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      visualDensity: VisualDensity.compact,
      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
      padding: const EdgeInsets.all(7),
      icon: Icon(icon, size: 19),
    );
  }
}

class _ExportFormatTile extends StatelessWidget {
  const _ExportFormatTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.surfaceLight,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white10),
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: AppTheme.primary),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
  }
}

class _AdjustmentSlider extends StatelessWidget {
  const _AdjustmentSlider({
    required this.label,
    required this.value,
    required this.onChanged,
    required this.onChangeStart,
  });

  final String label;
  final double value;
  final ValueChanged<double> onChanged;
  final ValueChanged<double> onChangeStart;

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
            onChangeStart: onChangeStart,
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

class _TransformAction extends StatelessWidget {
  const _TransformAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.quarterTurns = 0,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final int quarterTurns;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: SizedBox(
        width: 86,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            RotatedBox(
              quarterTurns: quarterTurns,
              child: Icon(icon, color: AppTheme.primary),
            ),
            const SizedBox(height: 7),
            Text(
              label,
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EditorTool {
  const _EditorTool(this.label, this.icon);

  final String label;
  final IconData icon;
}

class _CropPreset {
  const _CropPreset(this.label, this.aspectRatio);

  final String label;
  final double? aspectRatio;
}

class _EditorSnapshot {
  const _EditorSnapshot({
    required this.brightness,
    required this.contrast,
    required this.saturation,
    required this.filterId,
    required this.quarterTurns,
    required this.flipHorizontal,
    required this.flipVertical,
    required this.cropAspectRatio,
    required this.layers,
    required this.selectedLayerId,
  });

  final double brightness;
  final double contrast;
  final double saturation;
  final String filterId;
  final int quarterTurns;
  final bool flipHorizontal;
  final bool flipVertical;
  final double? cropAspectRatio;
  final List<EditorLayer> layers;
  final String? selectedLayerId;
}

class _CheckerboardPainter extends CustomPainter {
  const _CheckerboardPainter();

  @override
  void paint(Canvas canvas, Size size) {
    const double cellSize = 18;
    final Paint lightPaint = Paint()..color = const Color(0xFFF1F1F1);
    final Paint darkPaint = Paint()..color = const Color(0xFFD7D7D7);

    canvas.drawRect(Offset.zero & size, lightPaint);

    for (double y = 0; y < size.height; y += cellSize) {
      for (double x = 0; x < size.width; x += cellSize) {
        final int row = (y / cellSize).floor();
        final int column = (x / cellSize).floor();

        if ((row + column).isOdd) {
          canvas.drawRect(Rect.fromLTWH(x, y, cellSize, cellSize), darkPaint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
