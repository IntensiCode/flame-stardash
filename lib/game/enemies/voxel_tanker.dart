import 'dart:math';
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:stardash/core/common.dart';
import 'package:stardash/game/base/voxel_entity.dart';
import 'package:stardash/game/enemies/enemy_spawner.dart';
import 'package:stardash/game/enemies/voxel_enemy_base.dart';
import 'package:stardash/game/level/level.dart';

class VoxelTanker extends VoxelEnemyBase with HasVisibility {
  double get approach_speed => (0.1 + 0.02 * (level.number - 1)).clamp(0.1, 0.25);

  bool _spawned = false;

  VoxelTanker({
    required double x,
    double z = 1.0,
  }) {
    anchor = Anchor.center;
    grid_x = x;
    grid_z = z;
    remaining_hit_points = max_hit_points = 3;

    rot_y = 0;
    rot_z = pi;
    x_tilt_rotation.setRotationX(-pi / 6 * (1 - sin(1 * pi)));
  }

  @override
  Future onLoad() async {
    voxel = VoxelEntity(
      voxel_image: await images.load('voxel/tanker20.png'),
      height_frames: 20,
      exhaust_color: Color(0xFFff0600),
      exhaust_color_variance: 0.5,
      parent_size: size,
    );
    voxel.model_scale.setValues(0.6, 0.4, 0.8);
    voxel.exhaust_length = 2;
    await super.onLoad();
  }

  @override
  void set_exhaust_gradient_post_load() {
    voxel.set_exhaust_gradient(0, const Color(0xFF00FFFF));
    voxel.set_exhaust_gradient(1, const Color(0xFF0080FF));
    voxel.set_exhaust_gradient(2, const Color(0xFF0000FF));
    voxel.set_exhaust_gradient(3, const Color(0xFF000080));
    voxel.set_exhaust_gradient(4, const Color(0xFF000000));
  }

  @override
  void update(double dt) {
    super.update(dt);
    state_time += dt;

    switch (state) {
      case EnemyState.materializing:
        on_materialize(dt);
      case EnemyState.approaching:
        _approaching(dt);
        fire_pulse_bullet_when_ready(dt);
      case EnemyState.receding:
        _receding(dt);
        fire_pulse_bullet_when_ready(dt);
      case EnemyState.switching_lane:
        throw 'not supported';
      case EnemyState.leaving:
        on_leaving(dt);
      case EnemyState.exploding:
        on_explode(dt);
    }
  }

  void _approaching(double dt) {
    if (grid_z > 0.0) {
      grid_z -= approach_speed * dt;
    } else {
      grid_z = 0.0;
      if (!_spawned) {
        _spawned = true;
        spawner.spawn_flippers(this);
      }
      recede();
    }
  }

  void _receding(double dt) {
    if (grid_z < 1.0) {
      grid_z += approach_speed * dt;
    } else {
      grid_z = 1.0;
      leave();
    }
  }

  @override
  void on_destroyed() {
    super.on_destroyed();
    if (!_spawned) {
      _spawned = true;
      spawner.spawn_flippers(this);
    }
  }
}
