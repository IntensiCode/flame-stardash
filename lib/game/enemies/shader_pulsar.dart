import 'dart:math';
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:stardash/core/common.dart';
import 'package:stardash/game/enemies/enemy_base.dart';
import 'package:stardash/game/enemies/enemy_spawner.dart';
import 'package:stardash/game/level/level.dart';
import 'package:stardash/game/player/player.dart';
import 'package:stardash/util/pixelate.dart';
import 'package:stardash/util/uniforms.dart';

class ShaderPulsar extends EnemyBase {
  late FragmentShader _shader;

  double? prev_grid_x;
  double? switch_start_x;
  double? switch_target_x;
  int? switch_direction;

  double _anim_time = 0.0;

  double get approach_speed => (0.1 + 0.02 * (level.number - 15)).clamp(0.1, 0.3);

  double get switch_duration => (2.0 - 0.05 * (level.number - 15)).clamp(1.0, 2.0);

  double get cooldown_time => (3.0 - 0.05 * (level.number - 15)).clamp(1.5, 3.0);

  double get zap_time => (0.5 + 0.05 * (level.number - 15)).clamp(0.5, 0.8);

  ShaderPulsar({
    required double x,
    required double y,
  }) {
    grid_x = x;
    grid_z = y;
    remaining_hit_points = max_hit_points = 2;
    smoke_when_destroyed = false;
  }

  @override
  Future onLoad() async {
    await super.onLoad();
    _shader = await load_shader('pulsar.frag');
    paint.shader = _shader;
  }

  static final _up = Vector2(0, 1);
  final _orientation = Vector2.zero();
  final _smooth = Vector2.zero();

  @override
  void update(double dt) {
    super.update(dt);

    size.setAll(64 * perspective_scale(x: grid_x, z: grid_z));

    level.get_orientation_normal(grid_x, out: _orientation);
    _smooth.lerp(_orientation, 0.5);
    angle = -_smooth.angleToSigned(_up);

    state_time += dt;
    _anim_time += dt;

    switch (state) {
      case EnemyState.materializing:
        on_materialize(dt);
      case EnemyState.approaching:
        _consider_electrification(dt);
        _approach(dt);
      case EnemyState.receding:
        _consider_electrification(dt);
        _recede(dt);
      case EnemyState.switching_lane:
        _switching_lane(dt);
      case EnemyState.leaving:
        on_leaving(dt);
      case EnemyState.exploding:
        on_explode(dt);
        if (state_time > 0.1) removeFromParent();
    }
  }

  double _cooldown = 0.0;

  void _consider_electrification(double dt) {
    _cooldown = (_cooldown - dt).clamp(0.0, 0.1);
    if (level_rng.nextDouble() < 0.002 && _cooldown <= 0.0) {
      level.electrify(grid_x, zap_time);
      _cooldown = cooldown_time + level_rng.nextDouble() * cooldown_time * 0.25;
    }
  }

  void _recede(dt) {
    grid_z = (grid_z + dt * approach_speed).clamp(0.0, 1.0);
    if (grid_z >= 0.1 && grid_z < 0.9) {
      _consider_switching_lane();
    } else if (grid_z >= 1.0) {
      approach();
    }
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

    if (blocked_time <= 0.0) {
      grid_z = (grid_z - dt * approach_speed).clamp(0.0, 1.0);
    }

    if (grid_z < 0.01) {
      recede();
    } else {
      _consider_switching_lane();
    }
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

    switch_start_x = grid_x;
    switch_target_x = target_x;

    // Calculate and store the switch direction
    final delta_x = level.shortest_grid_x_delta(switch_start_x!, switch_target_x!);
    switch_direction = delta_x.sign.toInt();

    switch_lane();
  }

  bool _is_blocked([double? x]) {
    final z = max(0.0, grid.z - EnemySpawner.lane_delta);
    return !spawner.is_lane_free(x ?? grid_x, z, self: this);
  }

  int _pick_lane() {
    final pick = blocked_time > 0 ? true : level_rng.nextDouble() < 0.002;
    return pick ? _pick_random_neighbor_lane() : -1;
  }

  int _pick_random_neighbor_lane() {
    final current_idx = level.find_snap_index(grid_x);

    final step = level_rng.nextBool() ? 1 : -1;
    final (target, _) = level.find_snap_index(grid_x, delta: step);
    return target == current_idx ? -1 : target;
  }

  void _switching_lane(double dt) {
    assert(switch_start_x != null && switch_target_x != null);

    final t = (state_time / switch_duration).clamp(0.0, 1.0);
    grid_x = level.interpolate_grid_x(switch_start_x!, switch_target_x!, t);

    if (state_time < switch_duration) return;

    grid_x = switch_target_x!; // Snap to actual target lane

    _back_to_moving();
  }

  void _back_to_moving() {
    switch_start_x = null;
    switch_target_x = null;
    switch_direction = null;
    if (level_rng.nextBool()) {
      approach();
    } else {
      recede();
    }
  }

  @override
  render(Canvas canvas) {
    final img = pixelate(size.x.toInt(), size.y.toInt(), (canvas) {
      _shader.setFloat(0, size.x);
      _shader.setFloat(1, size.y);
      _shader.setFloat(2, _anim_time);
      _shader.setFloat(3, 3.0);
      _shader.setFloat(4, hit_time.sign);
      paint.shader = _shader;
      canvas.drawRect(Rect.fromLTWH(0, 0, size.x, size.y), paint);
    });
    paint.shader = null;
    canvas.drawImage(img, Offset.zero, paint);
  }
}
