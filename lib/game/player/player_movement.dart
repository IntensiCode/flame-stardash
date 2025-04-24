part of 'player.dart';

mixin _PlayerMovement on PositionComponent, HasContext, VoxelRotation {
  static const double _grid_max_speed = 0.4;
  static const double _grid_acceleration = 2.5;
  static const double _grid_deceleration = 2.5;

  double _current_grid_speed = 0.0;

  bool get _auto_pilot;

  int? _current_seg_idx = 0;
  int? _target_seg_idx = 0;
  int _last_tap_direction = 0;
  double _previous_move_input = 0.0;

  bool _tap_anchor_needed = true;

  @override
  void onMount() {
    final snap_points = level.snap_points;
    grid_x = level.find_start_x();
    _init_segment_indices(snap_points);

    final anchor_idx = _find_closest_snap_index(grid_x);
    _current_seg_idx = anchor_idx;
    _target_seg_idx = anchor_idx;
    _tap_anchor_needed = false;

    super.onMount();
  }

  @override
  void update(double dt) {
    super.update(dt);

    if (_auto_pilot) {
      level.map_grid_to_screen(grid_x, 0.0, out: position);
    } else {
      _on_manual(dt);
      _wrap_around_or_stop();
      level.map_grid_to_screen(grid_x, 0.0, out: position);
    }
  }

  void _on_manual(double dt) {
    final move_input = _get_move_input();
    _handle_tap(move_input);
    _apply_speed(dt, move_input);
    _sync_segment_indices_on_hold(move_input);
    _check_at_vertex();
    _auto_move_to_target(dt, move_input);
    _auto_snap_to_closest(dt, move_input);
    _apply_speed_scale(dt);
    // Reset anchor flag if idle (no move input and at target)
    if (move_input == 0.0 && _target_seg_idx == _current_seg_idx) {
      _tap_anchor_needed = true;
    }
  }

  void _check_at_vertex() {
    if (level.is_closed) return;

    // Check if player is at one of the edge vertices (-1.0 or 1.0)
    final at_edge_vertex = (grid_x.abs() - 1.0).abs() < 0.01;
    if (at_edge_vertex) _current_seg_idx = null; // Mark as "not snapped"
  }

  double _get_move_input() {
    var move_input = 0.0;
    if (keys.check(GameKey.left)) move_input -= 1.0;
    if (keys.check(GameKey.right)) move_input += 1.0;
    return move_input;
  }

  void _handle_tap(double move_input) {
    if (_previous_move_input == 0.0 && move_input != 0.0) {
      _do_handle_tap(move_input);
    }
    _previous_move_input = move_input;
  }

  void _do_handle_tap(double move_input) {
    final tap_dir = move_input.sign.toInt();
    // Anchor if needed (first tap after idle or direction change)
    if (_tap_anchor_needed || (_last_tap_direction != 0 && tap_dir != _last_tap_direction)) {
      final anchor_idx = _find_closest_snap_index(grid_x);
      _current_seg_idx = anchor_idx;
      _target_seg_idx = anchor_idx;
      // log_info('tap anchor: closest seg idx $_current_seg_idx');
      _tap_anchor_needed = false;
    }
    final snap_points = level.snap_points;

    // Handle null case - find closest index when not snapped
    int current = _current_seg_idx ?? _find_closest_snap_index(grid_x);

    int new_target = current + tap_dir;
    if (level.is_closed) {
      new_target = (new_target + snap_points.length) % snap_points.length;
    } else {
      new_target = new_target.clamp(0, snap_points.length - 1);
    }
    _target_seg_idx = new_target;
    _last_tap_direction = tap_dir;
  }

  void _auto_move_to_target(double dt, double move_input) {
    // Return if user is moving or we're already at target (and snapped)
    if (move_input != 0.0 || (_target_seg_idx == _current_seg_idx && _current_seg_idx != null)) return;

    final snap_points = level.snap_points;
    final idx = (_target_seg_idx ?? 0) % snap_points.length;
    final target_x = snap_points[idx];
    double dx = target_x - grid_x;
    if (level.is_closed) {
      double direct = dx;
      double wrapped = (dx > 0) ? dx - 2.0 : dx + 2.0;
      if (wrapped.abs() < direct.abs()) {
        dx = wrapped;
      }
    }

    final landing_x = _predict_landing_x();
    final dist_now = (target_x - grid_x).abs();
    final dist_landing = (target_x - landing_x).abs();
    if (dx.abs() < 0.01 && (dx * _current_grid_speed != 0 || dist_landing < dist_now)) {
      // log_info('snapped to seg idx $_current_seg_idx grid_x=$grid_x speed $_current_grid_speed');
      grid_x = target_x;
      _current_seg_idx = _target_seg_idx;
      _current_grid_speed = 0.0;
    } else {
      final max_step = _grid_max_speed * 1.25 * dt;
      final step = dx.clamp(-max_step, max_step);
      grid_x += step;
      // grid_x += dx * dt * 10.0;
      _current_grid_speed *= 0.8;
    }
  }

  void _auto_snap_to_closest(double dt, double move_input) {
    // Skip if there's movement input or we have a target to move to
    if (move_input != 0.0 || _current_seg_idx != _target_seg_idx) return;

    // Only run auto-snap when we're snapped (not at vertex)
    if (_current_seg_idx == null) return;

    final landing_x = _predict_landing_x();
    if (landing_x == grid_x) return;

    final closest_idx = _find_closest_snap_index(landing_x);
    final closest_x = level.snap_points[closest_idx];
    final dx = closest_x - grid_x;
    if (dx.abs() > 0.01) {
      // log_info('snapped to closest seg idx $closest_idx grid_x=$grid_x speed $_current_grid_speed');
      grid_x += dx * dt * 10.0;
      _current_grid_speed *= 0.8;
    }
  }

  void _apply_speed_scale(double dt) {
    const double reference_path_length = 2 * pi;
    final double current_path_length = level.total_normalized_path_length;
    final double speed_scale_factor = (current_path_length > 1e-6) ? reference_path_length / current_path_length : 1.0;
    grid_x += _current_grid_speed * speed_scale_factor * dt;
  }

  double _predict_landing_x() {
    if (_current_grid_speed == 0.0) return grid_x;
    final stop_dist =
        _current_grid_speed.abs() * _current_grid_speed / (2 * _grid_deceleration) * _current_grid_speed.sign;
    // log_info('predict landing: grid_x=$grid_x current_speed $_current_grid_speed stop dist $stop_dist');
    return grid_x + stop_dist;
  }

  void _init_segment_indices(List<double> snap_points) {
    _current_seg_idx = _find_closest_snap_index(grid_x);
    _target_seg_idx = _current_seg_idx;
  }

  int _find_closest_snap_index(double grid_x) {
    int closest_idx = 0;
    double min_dist = double.infinity;
    final snap_points = level.snap_points;
    for (int i = 0; i < snap_points.length; i++) {
      final d = (grid_x - snap_points[i % snap_points.length]).abs();
      if (d < min_dist) {
        // log_info('find closest snap index: grid_x=$grid_x snap_points=$snap_points i=$i d=$d');
        min_dist = d;
        closest_idx = i % snap_points.length;
      }
    }
    return closest_idx;
  }

  void _apply_speed(double dt, double move_input) {
    if (move_input != 0) {
      _current_grid_speed += move_input * _grid_acceleration * dt;
      _current_grid_speed = _current_grid_speed.clamp(-_grid_max_speed, _grid_max_speed);
    } else {
      // Decelerate (apply friction)
      if (_current_grid_speed.abs() < 0.01) {
        _current_grid_speed = 0.0; // Snap to zero if slow enough
      } else {
        final friction = _grid_deceleration * dt;
        if (_current_grid_speed > 0) {
          _current_grid_speed = max(0.0, _current_grid_speed - friction);
        } else {
          _current_grid_speed = min(0.0, _current_grid_speed + friction);
        }
      }
    }
  }

  void _wrap_around_or_stop() {
    final is_closed = level.data.closed;
    if (is_closed) {
      // Wrap around
      if (grid_x > 1.0) {
        grid_x -= 2.0;
      } else if (grid_x < -1.0) {
        grid_x += 2.0;
      }
    } else {
      // Clamp and stop speed at boundaries for non-closed paths
      final clampedX = grid_x.clamp(-1.0, 1.0);
      if (clampedX != grid_x) {
        grid_x = clampedX;
        _current_grid_speed = 0.0; // Stop movement
      }
    }
  }

  void _sync_segment_indices_on_hold(double move_input) {
    final dir = move_input.sign.toInt();
    if (dir == 0) return;

    // Don't sync if at vertex (not snapped)
    if (_current_seg_idx == null) return;

    final next_idx = _next_idx(dir * 1);
    final snap_points = level.snap_points;
    final now = _find_closest_snap_index(grid_x);
    final current_x = snap_points[now];
    final next_x = snap_points[next_idx];

    double dx = next_x - current_x;
    double player_dx = grid_x - current_x;
    if (level.is_closed) {
      if (dx > 1.0) dx -= 2.0;
      if (dx < -1.0) dx += 2.0;
      if (player_dx > 1.0) player_dx -= 2.0;
      if (player_dx < -1.0) player_dx += 2.0;
    }

    _current_seg_idx = now;
    if (_target_seg_idx == next_idx) return;
    if (_target_seg_idx == now) _target_seg_idx = next_idx;
  }

  int _next_idx(int step) {
    final snap_points = level.snap_points;
    final now = _current_seg_idx ?? _find_closest_snap_index(grid_x);
    final n = snap_points.length;
    if (level.is_closed) {
      return (now + step + n) % n;
    } else {
      return (now + step).clamp(0, n - 1);
    }
  }
}
