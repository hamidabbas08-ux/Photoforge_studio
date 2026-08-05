import 'dart:ui';

import 'package:flutter/foundation.dart';

import '../models/editor_layer.dart';

class LayerController extends ChangeNotifier {
  final List<EditorLayer> _layers = [];

  String? _selectedLayerId;

  List<EditorLayer> get layers => List<EditorLayer>.unmodifiable(_layers);

  String? get selectedLayerId => _selectedLayerId;

  EditorLayer? get selectedLayer {
    final String? id = _selectedLayerId;

    if (id == null) {
      return null;
    }

    for (final EditorLayer layer in _layers) {
      if (layer.id == id) {
        return layer;
      }
    }

    return null;
  }

  bool get hasLayers => _layers.isNotEmpty;

  void clear() {
    _layers.clear();
    _selectedLayerId = null;
    notifyListeners();
  }

  EditorLayer addBackgroundLayer({
    required String imagePath,
    required String name,
  }) {
    final EditorLayer layer = EditorLayer(
      id: _createLayerId(),
      name: name,
      type: EditorLayerType.background,
      imagePath: imagePath,
    );

    // Index 0 is rendered first, therefore it stays behind all layers.
    _layers.insert(0, layer);
    _selectedLayerId = layer.id;
    notifyListeners();

    return layer;
  }

  EditorLayer addImageLayer({required String imagePath, String? name}) {
    final EditorLayer layer = EditorLayer(
      id: _createLayerId(),
      name: name ?? 'Photo Layer ${_layers.length + 1}',
      type: EditorLayerType.image,
      imagePath: imagePath,
    );

    _layers.add(layer);
    _selectedLayerId = layer.id;
    notifyListeners();

    return layer;
  }

  EditorLayer addTextLayer({
    required String imagePath,
    required String text,
    required double fontSize,
    required int colorValue,
    required bool bold,
    required bool italic,
    required String textAlignment,
  }) {
    final String cleanText = text.trim();

    final EditorLayer layer = EditorLayer(
      id: _createLayerId(),
      name: _textLayerName(cleanText),
      type: EditorLayerType.text,
      imagePath: imagePath,
      textContent: cleanText,
      textFontSize: fontSize,
      textColorValue: colorValue,
      textBold: bold,
      textItalic: italic,
      textAlignment: textAlignment,
    );

    _layers.add(layer);
    _selectedLayerId = layer.id;
    notifyListeners();

    return layer;
  }

  void updateTextLayer({
    required String layerId,
    required String imagePath,
    required String text,
    required double fontSize,
    required int colorValue,
    required bool bold,
    required bool italic,
    required String textAlignment,
  }) {
    final String cleanText = text.trim();

    if (cleanText.isEmpty) {
      return;
    }

    _updateLayer(
      layerId,
      (EditorLayer layer) => layer.copyWith(
        name: _textLayerName(cleanText),
        imagePath: imagePath,
        textContent: cleanText,
        textFontSize: fontSize,
        textColorValue: colorValue,
        textBold: bold,
        textItalic: italic,
        textAlignment: textAlignment,
      ),
    );
  }

  String _textLayerName(String text) {
    if (text.length > 24) {
      return '${text.substring(0, 24)}...';
    }

    return text;
  }

  EditorLayer addShapeLayer({
    required String imagePath,
    required String shapeName,
    required String shapeKind,
    required int fillColorValue,
    required int strokeColorValue,
    required double strokeWidth,
    required double cornerRadius,
  }) {
    final EditorLayer layer = EditorLayer(
      id: _createLayerId(),
      name: shapeName,
      type: EditorLayerType.shape,
      imagePath: imagePath,
      shapeKind: shapeKind,
      shapeFillColorValue: fillColorValue,
      shapeStrokeColorValue: strokeColorValue,
      shapeStrokeWidth: strokeWidth,
      shapeCornerRadius: cornerRadius,
    );

    _layers.add(layer);
    _selectedLayerId = layer.id;
    notifyListeners();

    return layer;
  }

  void updateShapeLayer({
    required String layerId,
    required String imagePath,
    required String shapeName,
    required String shapeKind,
    required int fillColorValue,
    required int strokeColorValue,
    required double strokeWidth,
    required double cornerRadius,
  }) {
    _updateLayer(
      layerId,
      (EditorLayer layer) => layer.copyWith(
        name: shapeName,
        imagePath: imagePath,
        shapeKind: shapeKind,
        shapeFillColorValue: fillColorValue,
        shapeStrokeColorValue: strokeColorValue,
        shapeStrokeWidth: strokeWidth,
        shapeCornerRadius: cornerRadius,
      ),
    );
  }

  EditorLayer addDrawingLayer({required String imagePath}) {
    final int drawingCount = _layers
        .where((EditorLayer layer) => layer.type == EditorLayerType.drawing)
        .length;

    final EditorLayer layer = EditorLayer(
      id: _createLayerId(),
      name: 'Drawing Layer ${drawingCount + 1}',
      type: EditorLayerType.drawing,
      imagePath: imagePath,
    );

    _layers.add(layer);
    _selectedLayerId = layer.id;
    notifyListeners();

    return layer;
  }

  void updateLayerImagePath({
    required String layerId,
    required String imagePath,
    String? cutoutOriginalPath,
  }) {
    final EditorLayer? layer = _layerById(layerId);

    if (layer == null || layer.isLocked || imagePath.isEmpty) {
      return;
    }

    _updateLayer(
      layerId,
      (EditorLayer currentLayer) => currentLayer.copyWith(
        imagePath: imagePath,
        cutoutOriginalPath:
            cutoutOriginalPath ?? currentLayer.cutoutOriginalPath,
      ),
    );
  }

  void selectLayer(String layerId) {
    if (!_containsLayer(layerId)) {
      return;
    }

    _selectedLayerId = layerId;
    notifyListeners();
  }

  void toggleVisibility(String layerId) {
    _updateLayer(
      layerId,
      (layer) => layer.copyWith(isVisible: !layer.isVisible),
    );
  }

  void toggleLock(String layerId) {
    _updateLayer(layerId, (layer) => layer.copyWith(isLocked: !layer.isLocked));
  }

  void renameLayer(String layerId, String newName) {
    final String cleanName = newName.trim();

    if (cleanName.isEmpty) {
      return;
    }

    _updateLayer(layerId, (layer) => layer.copyWith(name: cleanName));
  }

  void setOpacity(String layerId, double opacity) {
    _updateLayer(
      layerId,
      (layer) => layer.copyWith(opacity: opacity.clamp(0.0, 1.0)),
    );
  }

  void setBlendMode(String layerId, EditorBlendMode blendMode) {
    _updateLayer(layerId, (layer) => layer.copyWith(blendMode: blendMode));
  }

  void moveLayerUp(String layerId) {
    final int index = _indexOf(layerId);

    if (index < 0 || index >= _layers.length - 1) {
      return;
    }

    final EditorLayer layer = _layers.removeAt(index);
    _layers.insert(index + 1, layer);

    notifyListeners();
  }

  void moveLayerDown(String layerId) {
    final int index = _indexOf(layerId);

    if (index <= 0) {
      return;
    }

    final EditorLayer layer = _layers.removeAt(index);
    _layers.insert(index - 1, layer);

    notifyListeners();
  }

  EditorLayer? duplicateLayer(String layerId) {
    final int index = _indexOf(layerId);

    if (index < 0) {
      return null;
    }

    final EditorLayer source = _layers[index];

    final EditorLayer duplicate = source.copyWith(
      id: _createLayerId(),
      name: '${source.name} Copy',
      offset: source.offset.translate(18, 18),
    );

    _layers.insert(index + 1, duplicate);
    _selectedLayerId = duplicate.id;

    notifyListeners();

    return duplicate;
  }

  void deleteLayer(String layerId) {
    final int index = _indexOf(layerId);

    if (index < 0) {
      return;
    }

    _layers.removeAt(index);

    if (_selectedLayerId == layerId) {
      if (_layers.isEmpty) {
        _selectedLayerId = null;
      } else {
        final int nextIndex = index.clamp(0, _layers.length - 1);

        _selectedLayerId = _layers[nextIndex].id;
      }
    }

    notifyListeners();
  }

  void setLayerTransform({
    required String layerId,
    required Offset offset,
    required double scaleX,
    required double scaleY,
    required double rotation,
  }) {
    final EditorLayer? layer = _layerById(layerId);

    if (layer == null || layer.isLocked) {
      return;
    }

    _updateLayer(
      layerId,
      (currentLayer) => currentLayer.copyWith(
        offset: offset,
        scaleX: scaleX.clamp(0.08, 12.0),
        scaleY: scaleY.clamp(0.08, 12.0),
        rotation: rotation,
      ),
    );
  }

  void resetLayerTransform(String layerId) {
    final EditorLayer? layer = _layerById(layerId);

    if (layer == null || layer.isLocked) {
      return;
    }

    _updateLayer(
      layerId,
      (currentLayer) => currentLayer.copyWith(
        offset: Offset.zero,
        scaleX: 1,
        scaleY: 1,
        rotation: 0,
      ),
    );
  }

  void replaceAllLayers({
    required List<EditorLayer> layers,
    String? selectedLayerId,
  }) {
    _layers
      ..clear()
      ..addAll(layers);

    if (_layers.isEmpty) {
      _selectedLayerId = null;
    } else if (selectedLayerId != null && _containsLayer(selectedLayerId)) {
      _selectedLayerId = selectedLayerId;
    } else {
      _selectedLayerId = _layers.last.id;
    }

    notifyListeners();
  }

  void replaceAllWithImage(String imagePath) {
    _layers
      ..clear()
      ..add(
        EditorLayer(
          id: _createLayerId(),
          name: 'Photo Layer 1',
          type: EditorLayerType.image,
          imagePath: imagePath,
        ),
      );

    _selectedLayerId = _layers.first.id;
    notifyListeners();
  }

  void _updateLayer(
    String layerId,
    EditorLayer Function(EditorLayer layer) update,
  ) {
    final int index = _indexOf(layerId);

    if (index < 0) {
      return;
    }

    _layers[index] = update(_layers[index]);
    notifyListeners();
  }

  EditorLayer? _layerById(String layerId) {
    final int index = _indexOf(layerId);

    if (index < 0) {
      return null;
    }

    return _layers[index];
  }

  int _indexOf(String layerId) {
    return _layers.indexWhere((layer) => layer.id == layerId);
  }

  bool _containsLayer(String layerId) {
    return _indexOf(layerId) >= 0;
  }

  String _createLayerId() {
    return 'layer_${DateTime.now().microsecondsSinceEpoch}';
  }
}
