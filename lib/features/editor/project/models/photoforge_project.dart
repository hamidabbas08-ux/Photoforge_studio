class PhotoForgeProject {
  const PhotoForgeProject({
    required this.version,
    required this.projectName,
    required this.createdAt,
    required this.updatedAt,
    required this.canvasWidth,
    required this.canvasHeight,
    required this.layers,
    required this.brightness,
    required this.contrast,
    required this.saturation,
    required this.exposure,
    required this.highlights,
    required this.shadows,
    required this.temperature,
    required this.tint,
    required this.vignette,
    required this.filterId,
    required this.quarterTurns,
    required this.flipHorizontal,
    required this.flipVertical,
    required this.cropAspectRatio,
  });

  final int version;
  final String projectName;
  final DateTime createdAt;
  final DateTime updatedAt;

  final int canvasWidth;
  final int canvasHeight;

  final List<PhotoForgeProjectLayer> layers;

  final double brightness;
  final double contrast;
  final double saturation;
  final double exposure;
  final double highlights;
  final double shadows;
  final double temperature;
  final double tint;
  final double vignette;
  final String filterId;

  final int quarterTurns;
  final bool flipHorizontal;
  final bool flipVertical;
  final double? cropAspectRatio;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'version': version,
      'projectName': projectName,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'canvasWidth': canvasWidth,
      'canvasHeight': canvasHeight,
      'layers': layers
          .map((PhotoForgeProjectLayer layer) => layer.toJson())
          .toList(),
      'brightness': brightness,
      'contrast': contrast,
      'saturation': saturation,
      'exposure': exposure,
      'highlights': highlights,
      'shadows': shadows,
      'temperature': temperature,
      'tint': tint,
      'vignette': vignette,
      'filterId': filterId,
      'quarterTurns': quarterTurns,
      'flipHorizontal': flipHorizontal,
      'flipVertical': flipVertical,
      'cropAspectRatio': cropAspectRatio,
    };
  }

  factory PhotoForgeProject.fromJson(Map<String, Object?> json) {
    final List<Object?> rawLayers =
        json['layers'] as List<Object?>? ?? <Object?>[];

    return PhotoForgeProject(
      version: (json['version'] as num?)?.toInt() ?? 1,
      projectName: json['projectName'] as String? ?? 'Untitled Project',
      createdAt:
          DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
      updatedAt:
          DateTime.tryParse(json['updatedAt'] as String? ?? '') ??
          DateTime.now(),
      canvasWidth: (json['canvasWidth'] as num?)?.toInt() ?? 1080,
      canvasHeight: (json['canvasHeight'] as num?)?.toInt() ?? 1080,
      layers: rawLayers
          .map(
            (Object? item) => PhotoForgeProjectLayer.fromJson(
              Map<String, Object?>.from(item! as Map),
            ),
          )
          .toList(),
      brightness: (json['brightness'] as num?)?.toDouble() ?? 0,
      contrast: (json['contrast'] as num?)?.toDouble() ?? 0,
      saturation: (json['saturation'] as num?)?.toDouble() ?? 0,
      exposure: (json['exposure'] as num?)?.toDouble() ?? 0,
      highlights: (json['highlights'] as num?)?.toDouble() ?? 0,
      shadows: (json['shadows'] as num?)?.toDouble() ?? 0,
      temperature: (json['temperature'] as num?)?.toDouble() ?? 0,
      tint: (json['tint'] as num?)?.toDouble() ?? 0,
      vignette: (json['vignette'] as num?)?.toDouble() ?? 0,
      filterId: json['filterId'] as String? ?? 'original',
      quarterTurns: (json['quarterTurns'] as num?)?.toInt() ?? 0,
      flipHorizontal: json['flipHorizontal'] as bool? ?? false,
      flipVertical: json['flipVertical'] as bool? ?? false,
      cropAspectRatio: (json['cropAspectRatio'] as num?)?.toDouble(),
    );
  }
}

class PhotoForgeProjectLayer {
  const PhotoForgeProjectLayer({
    required this.id,
    required this.name,
    required this.type,
    required this.imagePath,
    required this.isVisible,
    required this.isLocked,
    required this.opacity,
    required this.blendMode,
    required this.offsetX,
    required this.offsetY,
    required this.scaleX,
    required this.scaleY,
    required this.rotation,
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
  });

  final String id;
  final String name;
  final String type;
  final String? imagePath;

  final bool isVisible;
  final bool isLocked;
  final double opacity;
  final String blendMode;

  final double offsetX;
  final double offsetY;
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

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'id': id,
      'name': name,
      'type': type,
      'imagePath': imagePath,
      'isVisible': isVisible,
      'isLocked': isLocked,
      'opacity': opacity,
      'blendMode': blendMode,
      'offsetX': offsetX,
      'offsetY': offsetY,
      'scaleX': scaleX,
      'scaleY': scaleY,
      'rotation': rotation,
      'textContent': textContent,
      'textFontSize': textFontSize,
      'textColorValue': textColorValue,
      'textBold': textBold,
      'textItalic': textItalic,
      'textAlignment': textAlignment,
      'shapeKind': shapeKind,
      'shapeFillColorValue': shapeFillColorValue,
      'shapeStrokeColorValue': shapeStrokeColorValue,
      'shapeStrokeWidth': shapeStrokeWidth,
      'shapeCornerRadius': shapeCornerRadius,
    };
  }

  factory PhotoForgeProjectLayer.fromJson(Map<String, Object?> json) {
    return PhotoForgeProjectLayer(
      id:
          json['id'] as String? ??
          'layer_${DateTime.now().microsecondsSinceEpoch}',
      name: json['name'] as String? ?? 'Layer',
      type: json['type'] as String? ?? 'image',
      imagePath: json['imagePath'] as String?,
      isVisible: json['isVisible'] as bool? ?? true,
      isLocked: json['isLocked'] as bool? ?? false,
      opacity: (json['opacity'] as num?)?.toDouble() ?? 1,
      blendMode: json['blendMode'] as String? ?? 'normal',
      offsetX: (json['offsetX'] as num?)?.toDouble() ?? 0,
      offsetY: (json['offsetY'] as num?)?.toDouble() ?? 0,
      scaleX: (json['scaleX'] as num?)?.toDouble() ?? 1,
      scaleY: (json['scaleY'] as num?)?.toDouble() ?? 1,
      rotation: (json['rotation'] as num?)?.toDouble() ?? 0,
      textContent: json['textContent'] as String?,
      textFontSize: (json['textFontSize'] as num?)?.toDouble(),
      textColorValue: (json['textColorValue'] as num?)?.toInt(),
      textBold: json['textBold'] as bool?,
      textItalic: json['textItalic'] as bool?,
      textAlignment: json['textAlignment'] as String?,
      shapeKind: json['shapeKind'] as String?,
      shapeFillColorValue: (json['shapeFillColorValue'] as num?)?.toInt(),
      shapeStrokeColorValue: (json['shapeStrokeColorValue'] as num?)?.toInt(),
      shapeStrokeWidth: (json['shapeStrokeWidth'] as num?)?.toDouble(),
      shapeCornerRadius: (json['shapeCornerRadius'] as num?)?.toDouble(),
    );
  }
}
