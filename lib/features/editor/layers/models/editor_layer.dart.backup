import 'dart:ui';

enum EditorLayerType { image, text, shape, adjustment, group }

enum EditorBlendMode {
  normal,
  multiply,
  screen,
  overlay,
  softLight,
  hardLight,
  darken,
  lighten,
  difference,
}

class EditorLayer {
  const EditorLayer({
    required this.id,
    required this.name,
    required this.type,
    this.imagePath,
    this.isVisible = true,
    this.isLocked = false,
    this.opacity = 1,
    this.blendMode = EditorBlendMode.normal,
    this.offset = Offset.zero,
    this.scaleX = 1,
    this.scaleY = 1,
    this.rotation = 0,
  });

  final String id;
  final String name;
  final EditorLayerType type;
  final String? imagePath;

  final bool isVisible;
  final bool isLocked;
  final double opacity;
  final EditorBlendMode blendMode;

  final Offset offset;
  final double scaleX;
  final double scaleY;
  final double rotation;

  EditorLayer copyWith({
    String? id,
    String? name,
    EditorLayerType? type,
    String? imagePath,
    bool? isVisible,
    bool? isLocked,
    double? opacity,
    EditorBlendMode? blendMode,
    Offset? offset,
    double? scaleX,
    double? scaleY,
    double? rotation,
  }) {
    return EditorLayer(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      imagePath: imagePath ?? this.imagePath,
      isVisible: isVisible ?? this.isVisible,
      isLocked: isLocked ?? this.isLocked,
      opacity: opacity ?? this.opacity,
      blendMode: blendMode ?? this.blendMode,
      offset: offset ?? this.offset,
      scaleX: scaleX ?? this.scaleX,
      scaleY: scaleY ?? this.scaleY,
      rotation: rotation ?? this.rotation,
    );
  }
}
