import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

class LayerBlendMask extends SingleChildRenderObjectWidget {
  const LayerBlendMask({super.key, required this.blendMode, super.child});

  final BlendMode blendMode;

  @override
  RenderObject createRenderObject(BuildContext context) {
    return RenderLayerBlendMask(blendMode);
  }

  @override
  void updateRenderObject(
    BuildContext context,
    covariant RenderLayerBlendMask renderObject,
  ) {
    renderObject.blendMode = blendMode;
  }
}

class RenderLayerBlendMask extends RenderProxyBox {
  RenderLayerBlendMask(this._blendMode);

  BlendMode _blendMode;

  BlendMode get blendMode => _blendMode;

  set blendMode(BlendMode value) {
    if (_blendMode == value) {
      return;
    }

    _blendMode = value;
    markNeedsPaint();
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (child == null) {
      return;
    }

    final Canvas canvas = context.canvas;
    final Rect bounds = offset & size;

    canvas.saveLayer(bounds, Paint()..blendMode = _blendMode);

    context.paintChild(child!, offset);
    canvas.restore();
  }
}
