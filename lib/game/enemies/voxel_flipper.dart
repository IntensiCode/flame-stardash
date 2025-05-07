import 'dart:math';
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:stardash/aural/audio_system.dart';
import 'package:stardash/core/common.dart';
import 'package:stardash/game/base/voxel_entity.dart';
import 'package:stardash/game/enemies/enemy_spawner.dart';
import 'package:stardash/game/enemies/voxel_enemy_base.dart';
import 'package:stardash/game/level/level.dart';
import 'package:stardash/game/player/player.dart';

class VoxelFlipper extends VoxelEnemyBase with HasVisibility {
  static const base_height = 0.25; // voxel model dependant

  double? prev_grid_x;
  double? switch_start_x;
  double? switch_target_x;
  int? switch_direction;

  double get approach_speed => (0.2 + 0.01 * (level.number - 1)).clamp(0.2, 0.3);

  double get switch_duration => (1.25 - 0.02 * (level.number - 1)).clamp(0.8, 1.0);

  double get flip_dist => (0.2 - 0.05 * (level.number - 1)).clamp(0.1, 0.2);

  VoxelFlipper({
    required double x,
    required double y,
  }) {
    grid_x = x;
    grid_z = y;
    remaining_hit_points = max_hit_points = 1;
    smoothing = 0.01;
    yaw_factor = 0.3;
    base_size = 56;
    rot_y = pi;
  }

  @override
  Future onLoad() async {
    voxel = VoxelEntity(
      voxel_image: await images.load('voxel/flipper16.png'),
      height_frames: 16,
      exhaust_color: Color(0xFF00FFAA),
      exhaust_color_variance: 0.3,
      parent_size: size,
    );
    voxel.model_scale.setValues(0.8, 0.3, 0.8);
    voxel.exhaust_length = 2;
    await super.onLoad();
  }

  @override
  void update(double dt) {
    super.update(dt);

    final height = base_height * size.y;
    position.translate(target_normal.x * height, target_normal.y * height);

    state_time += dt;

    switch (state) {
      case EnemyState.materializing:
        on_materialize(dt);
      case EnemyState.approaching:
        _approach(dt);
        fire_pulse_bullet_when_ready(dt);
      case EnemyState.receding:
        _recede(dt);
      case EnemyState.switching_lane:
        _switching_lane(dt);
      case EnemyState.leaving:
        on_leaving(dt);
      case EnemyState.exploding:
        on_explode(dt);
    }
  }

  void _recede(dt) {
    grid_z = (grid_z + dt * approach_speed).clamp(0.0, 1.0);
    if (grid_z >= 1.0) leave();
  }

  double blocked_time = 0.0;

  void _approach(double dt) {
    if (player.is_dead) {
      recede();
      return;
    }

    if (blocked_time > 0.0) {
      blocked_time = (blocked_time - dt).clamp(0.0, 0.1);
      return;
    }

    if (_is_blocked()) {
      blocked_time = 0.1;
    }

    x_tilt_rotation.setRotationX(-pi / 12 * (1 - sin(1 * pi)));
    if (blocked_time <= 0.0) {
      grid_z = (grid_z - dt * approach_speed).clamp(0.0, 1.0);
    }
    _consider_switching_lane();
  }

  void _consider_switching_lane() {
    final target_idx = _pick_lane();
    if (target_idx == -1) return;

    double target_x = level.snap_points[target_idx];
    if (_is_blocked(target_x)) {
      // Special case: flipper at z 0.0 has to switch to not make it too easy!
      if (grid.z > 0.01) return;
      // target_x = grid_x;
    }

    audio.play(Sound.homing);

    switch_start_x = grid_x;
    switch_target_x = target_x;

    // Calculate and store the switch direction
    final delta_x = level.shortest_grid_x_delta(switch_start_x!, switch_target_x!);
    switch_direction = delta_x.sign.toInt();

    state = EnemyState.switching_lane;
    state_time = 0.0;
  }

  bool _is_blocked([double? x]) {
    // using grid.z to exclude the flip translation:
    final z = max(0.0, grid.z - EnemySpawner.lane_delta);
    return !spawner.is_lane_free(x ?? grid_x, z, self: this);
  }

  int _pick_lane() {
    if (grid_z < 0.01) {
      final it = _pick_lane_towards_player();
      if (it != -1) return it;

      final target_x = level.snap_points[it];
      if (!_is_blocked(target_x)) return it;
    }

    final pick = blocked_time > 0 ? true : level_rng.nextDouble() < 0.005;
    if (level.number > 1 && pick) {
      final it = _pick_random_neighbor_lane();
      if (it != -1) return it;
    }

    return -1;
  }

  int _pick_random_neighbor_lane() {
    final current_idx = level.find_snap_index(grid_x);

    final step = level_rng.nextBool() ? 1 : -1;
    final (target, _) = level.find_snap_index(grid_x, delta: step);
    return target == current_idx ? -1 : target;
  }

  int _pick_lane_towards_player() {
    if (player.is_dead) return -1;

    final player_x = player.grid_x;

    final (l, ls) = level.find_snap_index(grid_x, delta: -1, clamp: false);
    final (r, rs) = level.find_snap_index(grid_x, delta: 1, clamp: false);
    if (l == -1 && r == -1) return -1;
    if (l == -1) return r;
    if (r == -1) return l;

    // Two valid neighbors, find the one closer to the player
    final dist_left = level.shortest_grid_x_delta(ls, player_x).abs();
    final dist_right = level.shortest_grid_x_delta(rs, player_x).abs();
    return dist_left <= dist_right ? l : r;
  }

  void _switching_lane(double dt) {
    assert(switch_start_x != null && switch_target_x != null);

    final t = (state_time / switch_duration).clamp(0.0, 1.0);
    grid_x = level.interpolate_grid_x(switch_start_x!, switch_target_x!, t);

    final target_rot = switch_direction! * pi;
    rot_z = -lerpDouble(0.0, target_rot, t)!;
    translation.z = sin(t * pi) * flip_dist;
    x_tilt_rotation.setRotationX(-pi / 12 * (1 - sin(t * pi)));

    if (state_time < switch_duration) return;

    grid_x = switch_target_x!; // Snap to actual target lane

    _back_to_approaching();
  }

  void _back_to_approaching() {
    switch_start_x = null;
    switch_target_x = null;
    switch_direction = null;

    approach();

    // reset rot_z to 0 or pi, whatever is closest:
    rot_z = (rot_z / pi).round() * pi;
  }
}
