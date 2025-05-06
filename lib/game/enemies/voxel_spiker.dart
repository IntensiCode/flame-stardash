import 'dart:ui';

import 'package:flame/components.dart';
import 'package:stardash/core/common.dart';
import 'package:stardash/game/base/voxel_entity.dart';
import 'package:stardash/game/enemies/enemy_spawner.dart';
import 'package:stardash/game/enemies/voxel_enemy_base.dart';
import 'package:stardash/game/level/level.dart';
import 'package:stardash/game/player/player.dart';

class VoxelSpiker extends VoxelEnemyBase with HasVisibility {
  double get approach_speed => (0.1 + 0.01 * (level.number - 1)).clamp(0.1, 0.2);

  VoxelSpiker({
    required double x,
    double z = 1.0,
  }) {
    anchor = Anchor.center;
    grid_x = x;
    grid_z = z;
    remaining_hit_points = max_hit_points = 5;
  }

  @override
  Future onLoad() async {
    voxel = VoxelEntity(
      voxel_image: await images.load('voxel/spiker50.png'),
      height_frames: 50,
      exhaust_color: Color(0xFF40F010),
      exhaust_color_variance: 0.5,
      parent_size: size,
    );
    voxel.model_scale.setValues(0.8, 0.8, 0.8);
    voxel.exhaust_length = 2;
    await super.onLoad();
  }

  @override
  void set_exhaust_gradient_post_load() {
    voxel.set_exhaust_gradient(0, const Color(0xFF00FF00));
    voxel.set_exhaust_gradient(1, const Color(0xFF00FF00));
    voxel.set_exhaust_gradient(2, const Color(0xFF00A000));
    voxel.set_exhaust_gradient(3, const Color(0xFF008000));
    voxel.set_exhaust_gradient(4, const Color(0xFF006000));
  }

  @override
  void update(double dt) {
    super.update(dt);
    state_time += dt;

    rot_y += dt;

    switch (state) {
      case VoxelEnemyState.materializing:
        on_materialize(dt);
      case VoxelEnemyState.approaching:
        _approaching(dt);
      case VoxelEnemyState.receding:
        _receding(dt);
      case VoxelEnemyState.switching_lane:
        _switching_lane(dt);
      case VoxelEnemyState.leaving:
        on_leaving(dt);
      case VoxelEnemyState.exploding:
        on_explode(dt);
    }
  }

  void _approaching(double dt) {
    if (!player.is_dead && grid_z > 0.15) {
      grid_z -= approach_speed * dt;
      level.spike_tile(grid_x, grid_z);
    } else {
      grid_z = 0.15;
      recede();
    }
  }

  void _receding(double dt) {
    if (grid_z < 1.0) {
      grid_z += approach_speed * dt;
    } else if (player.is_dead) {
      leave();
    } else {
      grid_z = 1.0;
      if (level_rng.nextBool()) {
        switch_lane();
      } else {
        leave();
        spawner.spawn_tanker(this);
      }
    }
  }

  double? _switch_start_x;
  double? _switch_target_x;
  int? _switch_direction;

  void _switching_lane(double dt) {
    if (_switch_start_x == null || _switch_target_x == null) _pick_next_lane();

    final t = state_time.clamp(0.0, 1.0);
    grid_x = level.interpolate_grid_x(_switch_start_x!, _switch_target_x!, t);

    if (state_time < 1.0) return;

    grid_x = _switch_target_x!; // Snap to actual target lane
    _switch_start_x = null;
    _switch_target_x = null;
    _switch_direction = null;

    approach();
  }

  void _pick_next_lane() {
    final snaps = level.snap_points;

    // Get free lanes information
    final (left_free, right_free, current_idx) = level.find_free_lanes_around(grid_x);

    // Choose direction based on which lanes are free
    if (!left_free && right_free) {
      _switch_direction = 1; // Go right
    } else if (left_free && !right_free) {
      _switch_direction = -1; // Go left
    } else {
      // Both are free or both are spiked - random choice
      _switch_direction = (level.is_closed || (grid_x > snaps.first && grid_x < snaps.last))
          ? (level_rng.nextBool() ? -1 : 1)
          : (grid_x <= snaps.first ? 1 : -1);
    }

    int target_idx = current_idx + _switch_direction!;
    if (level.is_closed) {
      target_idx = (target_idx + snaps.length) % snaps.length;
    } else {
      target_idx = target_idx.clamp(0, snaps.length - 1);
    }

    _switch_start_x = grid_x;
    _switch_target_x = snaps[target_idx];
  }
}
