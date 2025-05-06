import 'dart:math';
import 'dart:ui';

import 'package:flame/extensions.dart';
import 'package:flutter/rendering.dart';
import 'package:stardash/game/enemies/enemy_base.dart';
import 'package:stardash/game/level/voxel_rotation.dart';

export 'package:stardash/game/enemies/enemy_base.dart';

class VoxelEnemyBase extends EnemyBase with VoxelRotation {
  VoxelEnemyBase() : super() {
    x_tilt_rotation.setRotationX(-pi - pi / 12);
  }

  void set_exhaust_gradient_post_load() {
    voxel.set_exhaust_gradient(0, const Color(0xFFFF8000));
    voxel.set_exhaust_gradient(1, const Color(0xFFFF0000));
    voxel.set_exhaust_gradient(2, const Color(0xFFA00000));
    voxel.set_exhaust_gradient(3, const Color(0xFF800000));
    voxel.set_exhaust_gradient(4, const Color(0xFF600000));
  }

  @override
  Future onLoad() async {
    await super.onLoad();
    await add(voxel);
    set_exhaust_gradient_post_load();
  }

  @override
  void update(double dt) {
    super.update(dt);
    voxel.render_mode = hit_time > 0 ? 1 : 0;
  }

  @override
  void on_explode(double dt) {
    super.on_explode(dt);
    voxel.exploding = state_time;
  }
}
