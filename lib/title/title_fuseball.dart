import 'dart:ui';
import 'package:flame/components.dart';
import 'package:stardash/util/pixelate.dart';
import 'package:stardash/util/uniforms.dart';

class TitleFuseball extends PositionComponent with HasPaint {
  late FragmentShader _shader;

  double _anim_time = 0.0;

  @override
  Future onLoad() async {
    await super.onLoad();
    _shader = await load_shader('fuseball.frag');
    paint.shader = _shader;
  }

  @override
  void update(double dt) {
    super.update(dt);
    _anim_time += dt;
  }

  @override
  void render(Canvas canvas) {
    final img = pixelate(size.x.toInt(), size.y.toInt(), (canvas) {
      _shader.setFloat(0, size.x);
      _shader.setFloat(1, size.y);
      _shader.setFloat(2, _anim_time);
      paint.shader = _shader;
      canvas.drawRect(Rect.fromLTWH(0, 0, size.x, size.y), paint);
    });
    paint.shader = null;
    canvas.drawImage(img, Offset.zero, paint);
  }
}
