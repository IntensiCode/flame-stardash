part of 'player.dart';

mixin _PlayerMovement on PositionComponent, HasContext {
  static const double _orientation_smoothing_factor = 0.15;

  // Factor to control how much depth influences tilt (0=none, 1=full)
  static const double _depth_tilt_factor = 0.1;

  // Factor to control yaw based on normal/depth divergence (0=none, 1=full)
  static const double _yaw_factor = 0.5;

  static const double _grid_max_speed = 0.5;
  static const double _grid_acceleration = 2.0;
  static const double _grid_deceleration = 1.5;

  late final VoxelEntity _voxel;

  final _smoothed_normal = Vector2(0, 1); // Default Up
  final _target_normal = Vector2.zero();

  final _smoothed_depth = Vector2(0, -1); // Default depth (towards screen top)
  final _target_depth = Vector2.zero();

  final _base_orientation = Matrix3.identity();
  final _final_orientation = Matrix3.identity();
  final _x_tilt_rotation = Matrix3.rotationX(-pi / 6);

  double _wobble_anim = 0;
  final _max_wobble = pi / 64;
  final _wobble_matrix = Matrix3.identity();
  final _rot_x = Matrix3.identity();
  final _rot_y = Matrix3.identity();
  final _rot_z = Matrix3.identity();

  final _yaw_rotation_z = Matrix3.identity();

  final _temp_vec = Vector3.zero();

  double grid_x = 0.0;
  double _current_grid_speed = 0.0;

  bool _auto_pilot = false;

  @override
  void onMount() {
    // Get the calculated starting gridX from the level logic
    grid_x = level.find_start_x();
    log_info('Player mounting with gridX: $grid_x');

    _current_grid_speed = 0.0;
    position.setFrom(level.map_grid_to_screen(grid_x, 0.0));

    // Initialize smoothed vectors using the final gridX
    level.get_orientation_normal(grid_x, out: _smoothed_normal);
    level.get_depth_vector(grid_x, out: _smoothed_depth);
    _wobble_anim = 0;
    _update_orientation();
  }

  @override
  void update(double dt) {
    if (_auto_pilot) {
      _on_auto(dt);
    } else {
      _on_manual(dt);
    }
    _wrap_around_or_stop();

    level.map_grid_to_screen(grid_x, 0.0, out: position, lerp: true);

    // Get target vectors for current position
    level.get_orientation_normal(grid_x, out: _target_normal);
    level.get_depth_vector(grid_x, out: _target_depth); // Get target depth

    // Smooth both vectors
    _smoothed_normal.lerp(_target_normal, _orientation_smoothing_factor);
    _smoothed_normal.normalize();
    _smoothed_depth.lerp(_target_depth, _orientation_smoothing_factor);
    _smoothed_depth.normalize();

    _update_wobble(dt);
    _update_orientation();
  }

  void _on_auto(double dt) {
    _current_grid_speed = 0.0;

    // --- Autopilot Logic ---
    final target_grid_x = level.find_start_x(lerp: true);
    final delta = level.shortest_grid_x_delta(grid_x, target_grid_x, lerp: true);

    // Move towards target at autopilot speed, but don't overshoot
    final move_amount = delta.sign * min(delta.abs(), _grid_max_speed * dt);

    // Directly update gridX, bypass user input and acceleration/speed logic
    grid_x += move_amount;
  }

  void _on_manual(double dt) {
    var move_input = 0.0;
    if (keys.check(GameKey.left)) move_input -= 1.0;
    if (keys.check(GameKey.right)) move_input += 1.0;

    _apply_speed(dt, move_input);

    // --- Calculate speed scale factor for visually consistent speed ---
    const double reference_path_length = 2 * pi; // Approx normalized length of unit circle
    final double current_path_length = level.total_normalized_path_length;
    // Avoid division by zero if path length is somehow zero
    final double speed_scale_factor = (current_path_length > 1e-6) ? reference_path_length / current_path_length : 1.0;
    // --- Apply scaled speed ---
    grid_x += _current_grid_speed * speed_scale_factor * dt;
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
    final is_closed = level.path_type.closed;
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

  // Temporary vectors for orientation calculation
  final _forward = Vector3.zero();
  final _up = Vector3.zero();
  final _right = Vector3.zero();
  final _depth = Vector3.zero();
  final _ideal_right = Vector3.zero();
  final _actual_right = Vector3.zero();

  void _update_orientation() {
    // 1. Define base vectors (smoothed in update loop)
    //    Normal (Y-up based on tangent rotation)
    //    Depth (Points into screen)
    _up.setValues(_smoothed_normal.x, _smoothed_normal.y, 0);
    _up.normalize();
    _depth.setValues(_smoothed_depth.x, _smoothed_depth.y, 0);
    _depth.normalize();

    // 2. Calculate Forward vector (X-axis, tangent) by rotating Up +90 deg
    //    Up = (ux, uy, 0), Forward = (-uy, ux, 0)
    _forward.setValues(-_up.y, _up.x, 0);
    // No need to normalize _forward if _up is normalized.

    // 3. Calculate Right vector based on desired tilt
    //    actualRight = cross(Forward, Up) -> Should be ~ (0, 0, 1)
    //    idealRight = cross(Forward, Depth) -> Captures tilt relative to depth
    _forward.crossInto(_up, _actual_right);
    _actual_right.normalize();
    _forward.crossInto(_depth, _ideal_right);
    _ideal_right.normalize();

    // Handle cases where vectors are parallel (cross product is zero)
    if (_actual_right.length2 < 1e-12) _actual_right.setValues(0, 0, 1);
    if (_ideal_right.length2 < 1e-12) _ideal_right.setValues(0, 0, 1); // Use standard Z if depth aligns

    // 4. Lerp between actual and ideal Right vector based on factor
    // Manual Lerp: _right = _actualRight * (1 - factor) + _idealRight * factor
    _temp_vec.setFrom(_actual_right);
    _temp_vec.scale(1.0 - _depth_tilt_factor);
    _right.setFrom(_ideal_right);
    _right.scale(_depth_tilt_factor);
    _right.add(_temp_vec);
    _right.normalize();

    // 5. Recalculate final Up vector orthogonal to Forward and final Right
    //    Up = cross(Right, Forward)
    _right.crossInto(_forward, _up);
    _up.normalize();

    // 6. Set matrix columns (Forward, Up, Right) for base orientation
    _base_orientation.setValues(_forward.x, _up.x, _right.x, _forward.y, _up.y, _right.y, _forward.z, _up.z, _right.z);

    // 8. Combine rotations: Base * Tilt * Yaw * Wobble
    _final_orientation.setFrom(_base_orientation);
    _final_orientation.multiply(_x_tilt_rotation); // Apply fixed perspective tilt

    // --- Calculate and apply Yaw adjustment ---
    // Calculate signed 2D angle difference between smoothed vectors
    final angle_normal = atan2(_smoothed_normal.y, _smoothed_normal.x);
    final angle_depth = atan2(_smoothed_depth.y, _smoothed_depth.x);
    double angle_difference = angle_depth - angle_normal;

    // Normalize angle to [-pi, pi]
    while (angle_difference > pi) angle_difference -= 2 * pi;
    while (angle_difference < -pi) angle_difference += 2 * pi;

    final target_yaw_z = angle_difference * _yaw_factor;
    _yaw_rotation_z.setRotationY(-target_yaw_z);
    _final_orientation.multiply(_yaw_rotation_z); // Apply Yaw
    // --- End Yaw adjustment ---

    _final_orientation.multiply(_wobble_matrix); // Apply wobble last

    // 9. Set the final matrix on the voxel entity
    _voxel.orientation_matrix.setFrom(_final_orientation);
  }

  void _update_wobble(double dt) {
    final wobble_x = sin(_wobble_anim * 1.78926) * _max_wobble;
    final wobble_y = sin(_wobble_anim * 1.99292) * _max_wobble;
    final wobble_z = sin(_wobble_anim * 2.12894) * _max_wobble;
    _wobble_anim += dt;

    _rot_x.setRotationX(wobble_x);
    _rot_y.setRotationY(wobble_y);
    _rot_z.setRotationZ(wobble_z);

    _wobble_matrix.setFrom(_rot_z);
    _wobble_matrix.multiply(_rot_y);
    _wobble_matrix.multiply(_rot_x);
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    if (debug) _render_normals(canvas);
  }

  final Paint _debug_normal_paint = Paint()
    ..color = const Color(0xFFFF0000)
    ..strokeWidth = 2;

  final Paint _debug_depth_paint = Paint()
    ..color = const Color(0xFF00FF00)
    ..strokeWidth = 2;

  void _render_normals(Canvas canvas) {
    canvas.translate(size.x / 2, size.y / 2);

    const double line_length = 64.0;
    final Offset center = Offset.zero;

    // Draw Smoothed Normal (Tangent-based Up)
    final Offset normal_end = Offset(
      _smoothed_normal.x * line_length,
      _smoothed_normal.y * line_length,
    );
    canvas.drawLine(center, normal_end, _debug_normal_paint);

    // Draw Smoothed Depth Vector
    final Offset depth_end = Offset(
      _smoothed_depth.x * line_length,
      _smoothed_depth.y * line_length,
    );
    canvas.drawLine(center, depth_end, _debug_depth_paint);

    canvas.translate(-size.x / 2, -size.y / 2); // Reset canvas translation
  }
}
