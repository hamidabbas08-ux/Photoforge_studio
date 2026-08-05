import 'dart:ui';

enum EditorLayerType {
  background,
  image,
  text,
  shape,
  drawing,
  adjustment,
  group,
}

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
    this.textContent,
    this.textFontSize,
    this.textColorValue,
    this.textBold,
    this.textItalic,
    this.textAlignment,
    this.shapeKind,
    this.shapeFillColorValue,
    this.shapeStrokeColorValue,
    this.shapeStrokeWidth,
    this.shapeCornerRadius,
    this.cutoutOriginalPath,
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

  final String? textContent;
  final double? textFontSize;
  final int? textColorValue;
  final bool? textBold;
  final bool? textItalic;
  final String? textAlignment;

  final String? shapeKind;
  final int? shapeFillColorValue;
  final int? shapeStrokeColorValue;
  final double? shapeStrokeWidth;
  final double? shapeCornerRadius;

  /// Original image retained for Cutout Refine restore mode.
  final String? cutoutOriginalPath;

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
    String? textContent,
    double? textFontSize,
    int? textColorValue,
    bool? textBold,
    bool? textItalic,
    String? textAlignment,
    String? shapeKind,
    int? shapeFillColorValue,
    int? shapeStrokeColorValue,
    double? shapeStrokeWidth,
    double? shapeCornerRadius,
    String? cutoutOriginalPath,
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
      textContent: textContent ?? this.textContent,
      textFontSize: textFontSize ?? this.textFontSize,
      textColorValue: textColorValue ?? this.textColorValue,
      textBold: textBold ?? this.textBold,
      textItalic: textItalic ?? this.textItalic,
      textAlignment: textAlignment ?? this.textAlignment,
      shapeKind: shapeKind ?? this.shapeKind,
      shapeFillColorValue: shapeFillColorValue ?? this.shapeFillColorValue,
      shapeStrokeColorValue:
          shapeStrokeColorValue ?? this.shapeStrokeColorValue,
      shapeStrokeWidth: shapeStrokeWidth ?? this.shapeStrokeWidth,
      shapeCornerRadius: shapeCornerRadius ?? this.shapeCornerRadius,
      cutoutOriginalPath: cutoutOriginalPath ?? this.cutoutOriginalPath,
    );
  }
}
