import 'dart:ui';

import 'editor_layer.dart';

class LayerBlendMapper {
  LayerBlendMapper._();

  static BlendMode toFlutterBlendMode(EditorBlendMode mode) {
    switch (mode) {
      case EditorBlendMode.normal:
        return BlendMode.srcOver;

      case EditorBlendMode.multiply:
        return BlendMode.multiply;

      case EditorBlendMode.screen:
        return BlendMode.screen;

      case EditorBlendMode.overlay:
        return BlendMode.overlay;

      case EditorBlendMode.softLight:
        return BlendMode.softLight;

      case EditorBlendMode.hardLight:
        return BlendMode.hardLight;

      case EditorBlendMode.darken:
        return BlendMode.darken;

      case EditorBlendMode.lighten:
        return BlendMode.lighten;

      case EditorBlendMode.difference:
        return BlendMode.difference;
    }
  }

  static String label(EditorBlendMode mode) {
    switch (mode) {
      case EditorBlendMode.normal:
        return 'Normal';

      case EditorBlendMode.multiply:
        return 'Multiply';

      case EditorBlendMode.screen:
        return 'Screen';

      case EditorBlendMode.overlay:
        return 'Overlay';

      case EditorBlendMode.softLight:
        return 'Soft Light';

      case EditorBlendMode.hardLight:
        return 'Hard Light';

      case EditorBlendMode.darken:
        return 'Darken';

      case EditorBlendMode.lighten:
        return 'Lighten';

      case EditorBlendMode.difference:
        return 'Difference';
    }
  }
}
