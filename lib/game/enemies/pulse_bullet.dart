import 'dart:ui';

import 'package:flame/components.dart';
import 'package:stardash/aural/audio_system.dart';
import 'package:stardash/game/base/decals.dart';
import 'package:stardash/game/base/fake_three_d.dart';
import 'package:stardash/game/base/has_context.dart';
import 'package:stardash/game/level/level.dart';
import 'package:stardash/game/player/player.dart';
import 'package:stardash/util/mutable.dart';

// TODO: POOLING!

class PulseBullet extends PositionComponent with HasContext, HasPaint, FakeThreeDee {
  static final _center = MutableOffset(0, 0);

  static const double _speed = 0.6;
  static const double _radius = 4.0;

  final double damage;

  double _scale = 1.0;

  final _outer_color = const Color(0xFFFFA500); // Orange
  final _inner_color = const Color(0xFFFFE0B2); // Light Orange

  PulseBullet({required double x, required double z, this.damage = 1.0})
      : super(anchor: Anchor.center, size: Vector2.all(_radius * 2)) {
    grid_x = x;
    grid_z = z;
  }

  @override
  void onMount() {
    super.onMount();
    audio.play(Sound.shot);
  }

  @override
  void update(double dt) {
    super.update(dt);

    grid_z -= _speed * dt;
    if (grid_z <= 0.0) {
      decals.spawn3d(Decal.sparkle, this);
      removeFromParent();
      return;
    }

    level.map_grid_to_screen(grid_x, grid_z, clamp_and_wrap_x: false, out: position);

    // Calculate perspective scaling
    _scale = perspective_scale(x: grid_x, z: grid_z);

    // Update visual size and hitbox size based on current scale
    final scaledDiameter = _radius * _scale * 2;
    size.setAll(scaledDiameter);

    if (grid_z < 0.1 && player.is_affected_by(this)) {
      player.on_hit(damage);
      removeFromParent();
    }
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    final radius = _radius * _scale;
    final inner = radius * 0.6;

    _center.dx = radius;
    _center.dy = radius;

    paint.color = _outer_color;
    canvas.drawCircle(_center, radius, paint);

    paint.color = _inner_color;
    canvas.drawCircle(_center, inner, paint);
  }

// @override
// void onCollisionStart(Set<Vector2> intersectionPoints, PositionComponent other) {
//   super.onCollisionStart(intersectionPoints, other);
//   if (other case Friendly f) {
//     if (f.is_affected_by(this)) {
//       f.on_hit(damage);
//       removeFromParent();
//     }
//   }
// }
}
