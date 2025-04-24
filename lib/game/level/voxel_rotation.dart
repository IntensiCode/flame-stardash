import 'dart:math';
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:stardash/core/common.dart';
import 'package:stardash/game/base/fake_three_d.dart';
import 'package:stardash/game/base/has_context.dart';
import 'package:stardash/game/base/voxel_entity.dart';
import 'package:stardash/game/level/level.dart';

mixin VoxelRotation on PositionComponent, HasContext, FakeThreeDee {
  double smoothing = 0.05;

  // Factor to control how much depth influences tilt (0=none, 1=full)
  double depth_tilt_factor = 0.1;

  // Factor to control yaw based on normal/depth divergence (0=none, 1=full)
  double yaw_factor = 0.5;

  final _base_orientation = Matrix3.identity();
  final _final_orientation = Matrix3.identity();
  final x_tilt_rotation = Matrix3.identity();

  final _wobble_matrix = Matrix3.identity();
  final _rot_x = Matrix3.identity();
  final _rot_y = Matrix3.identity();
  final _rot_z = Matrix3.identity();

  final _yaw_rotation_z = Matrix3.identity();
  final _temp_vec = Vector3.zero();

  late final VoxelEntity voxel;

  final smoothed_normal = Vector2(0, 1); // Default Up
  final target_normal = Vector2.zero();

  final smoothed_depth = Vector2(0, -1); // Default depth (towards screen top)
  final target_depth = Vector2.zero();

  double base_size = 64;
  double max_wobble = pi / 64;
  double wobble_anim = 0;
  double rot_y = 0;
  double rot_z = 0;

  @override
  void onMount() {
    super.onMount();

    level.map_grid_to_screen(grid_x, grid_z, out: position);

    // Initialize smoothed vectors using the final gridX
    level.get_orientation_normal(grid_x, out: smoothed_normal);
    level.get_depth_vector(grid_x, out: smoothed_depth);

    update_orientation();
  }

  @override
  void update(double dt) {
    super.update(dt);

    // Get target vectors for current position
    level.get_orientation_normal(grid_x, out: target_normal);
    level.get_depth_vector(grid_x, out: target_depth); // Get target depth

    // Smooth both vectors
    // smoothed_normal.setFrom(target_normal);
    smoothed_normal.lerp(target_normal, smoothing);
    smoothed_normal.normalize();
    // smoothed_depth.setFrom(target_depth);
    smoothed_depth.lerp(target_depth, smoothing);
    smoothed_depth.normalize();

    update_rotation(dt);
    update_orientation();

    final scale = perspective_scale(x: grid_x, z: grid_z);
    size.setAll(base_size * scale);
  }

  // Temporary vectors for orientation calculation
  final _forward = Vector3.zero();
  final _up = Vector3.zero();
  final _right = Vector3.zero();
  final _depth = Vector3.zero();
  final _ideal_right = Vector3.zero();
  final _actual_right = Vector3.zero();

  void update_orientation() {
    // 1. Define base vectors (smoothed in update loop)
    //    Normal (Y-up based on tangent rotation)
    //    Depth (Points into screen)
    _up.setValues(smoothed_normal.x, smoothed_normal.y, 0);
    _up.normalize();
    _depth.setValues(smoothed_depth.x, smoothed_depth.y, 0);
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
    _temp_vec.scale(1.0 - depth_tilt_factor);
    _right.setFrom(_ideal_right);
    _right.scale(depth_tilt_factor);
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
    _final_orientation.multiply(x_tilt_rotation); // Apply fixed perspective tilt

    // --- Calculate and apply Yaw adjustment ---
    // Calculate signed 2D angle difference between smoothed vectors
    final angle_normal = atan2(smoothed_normal.y, smoothed_normal.x);
    final angle_depth = atan2(smoothed_depth.y, smoothed_depth.x);
    double angle_difference = angle_depth - angle_normal;

    // Normalize angle to [-pi, pi]
    while (angle_difference > pi) angle_difference -= 2 * pi;
    while (angle_difference < -pi) angle_difference += 2 * pi;

    final target_yaw_z = angle_difference * yaw_factor;
    _yaw_rotation_z.setRotationY(-target_yaw_z);
    _final_orientation.multiply(_yaw_rotation_z); // Apply Yaw
    // --- End Yaw adjustment ---

    _final_orientation.multiply(_wobble_matrix); // Apply wobble last

    // 9. Set the final matrix on the voxel entity
    voxel.orientation_matrix.setFrom(_final_orientation);
  }

  void update_rotation(double dt) {
    final wobble_x = sin(wobble_anim * 1.78926) * max_wobble;
    final wobble_y = sin(wobble_anim * 1.99292) * max_wobble;
    final wobble_z = sin(wobble_anim * 2.12894) * max_wobble;
    wobble_anim += dt;

    _rot_x.setRotationX(wobble_x);
    _rot_y.setRotationY(wobble_y + rot_y);
    _rot_z.setRotationZ(wobble_z + rot_z);

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
      smoothed_normal.x * line_length,
      smoothed_normal.y * line_length,
    );
    canvas.drawLine(center, normal_end, _debug_normal_paint);

    // Draw Smoothed Depth Vector
    final Offset depth_end = Offset(
      smoothed_depth.x * line_length,
      smoothed_depth.y * line_length,
    );
    canvas.drawLine(center, depth_end, _debug_depth_paint);

    canvas.translate(-size.x / 2, -size.y / 2); // Reset canvas translation
  }
}
