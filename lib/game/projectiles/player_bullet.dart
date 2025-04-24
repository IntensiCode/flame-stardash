import 'dart:ui';

import 'package:flame/components.dart';
import 'package:stardash/game/base/fake_three_d.dart';
import 'package:stardash/game/base/has_context.dart';
import 'package:stardash/game/base/kinds.dart';
import 'package:stardash/game/projectiles/projectile_movement.dart';
import 'package:stardash/util/mutable.dart';

class PlayerBullet extends PositionComponent
    with HasContext, HasPaint, HasVisibility, FakeThreeDee, ProjectileMovement {
  //

  static const double _speed = 0.8;
  static const double _fade_start_z = 1.0;
  static const double _remove_z = 1.0;
  static const double _damage = 1.0;
  static const double _base_radius = 8.0;

  static const outer_color = Color(0xFF0050FF); // Dark blue
  static const inner_color = Color(0xFFFFFFFF); // White

  static final _center = MutableOffset(0, 0);

  PlayerBullet() : super(anchor: Anchor.center, size: Vector2.all(_base_radius * 2)) {
    projectile_speed = _speed;
    projectile_remove_z = _remove_z;
    projectile_damage = _damage;
  }

  @override
  bool is_target(Component c) => c is! Friendly;

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    double alpha = 1.0;
    if (grid_z > _fade_start_z) {
      final fadeProgress = (grid_z - _fade_start_z) / (_remove_z - _fade_start_z);
      alpha = (1.0 - fadeProgress).clamp(0.0, 1.0);
    }

    final radius = _base_radius * perspective_scale(x: grid_x, z: grid_z);
    _center.dx = size.x / 2;
    _center.dy = size.y / 2;

    paint.color = outer_color.withValues(alpha: alpha);
    canvas.drawCircle(_center, radius, paint);

    paint.color = inner_color.withValues(alpha: alpha);
    canvas.drawCircle(_center, radius * 0.6, paint);
  }
}
