import 'dart:math';

import 'package:flame/components.dart';
import 'package:stardash/core/common.dart';
import 'package:stardash/game/base/camera.dart';

/// Mixin for components that have a position within the fake 3D grid space.
mixin FakeThreeDee on PositionComponent {
  static const double near_z = 0.1; // Adjust as needed
  static const double far_z = 1000.0; // Adjust as needed

  static final _input_point_4d = Vector4.zero();
  static final _camera_space_point_4d = Vector4.zero();
  static final _clip_space_point_4d = Vector4.zero();
  static final _temp = Vector3.zero();
  static final _result = Vector2.zero();

  static final _world_matrix = Matrix4.identity();
  static final _view_matrix = Matrix4.identity();
  static final _projection_matrix = Matrix4.identity();
  static final _wvp_matrix = Matrix4.identity(); // World-View-Projection

  static final _view_world_matrix_temp = Matrix4.identity(); // Temporary matrix

  static var _camera = Camera.standard;

  static set camera(Camera value) {
    _camera = value;
    _update_projection();
  }

  /// Call this whenever the camera or screen size changes.
  static void _update_projection() {
    // --- 1. World Matrix ---
    // Applies global scale and translation FIRST.
    // Modify order if scale/translate should happen differently.
    _world_matrix.setIdentity();
    _world_matrix.translate(_camera.translate);
    _world_matrix.negate(); // TODO: WTF!?
    _temp.setFrom(_camera.scale);
    _temp.x = -_temp.x; // TODO: WTF!?
    _world_matrix.scale(_temp);
    // Note: This applies scale *after* translation in matrix multiplication order (T * S).
    // To apply scale *before* translation (S then T), reverse the calls or multiply:
    // _world_matrix = Matrix4.translation(active_camera.translate) * Matrix4.diagonal3(active_camera.scale);

    // --- 2. View Matrix ---
    // Inverse of camera's world transform (Translate then Rotate)
    // Inverse is Rotate(-pitch) then Translate(-position)
    final rotation = Matrix4.rotationX(-_camera.pitch);
    final translation = Matrix4.translation(-_camera.position);

    // View = Rotation * Translation
    _view_matrix.setFrom(rotation * translation);

    // --- 3. Projection Matrix ---
    // Calculate perspective matrix based on focal length and screen size
    // FOV calculation assumes focal length is in pixels relative to screen height
    final double screen_height = game_size.y; // Assuming game_size is available
    final double screen_width = game_size.x;
    final double aspect_ratio = screen_width / screen_height;
    // Vertical field of view derived from focal length
    final double fov_y_radians = _camera.fov_y_rad;

    setPerspectiveMatrix(_projection_matrix, fov_y_radians, aspect_ratio, near_z, far_z);

    // --- 4. Combined World-View-Projection Matrix (WVP) ---
    // Order: Projection * View * World
    // Calculate step-by-step, storing the final result in _wvp_matrix
    // Note: Matrix multiplication is associative but not commutative.
    // Apply World, then View, then Projection transforms to the point.
    // Matrix order is reversed: P * V * W
    _wvp_matrix.setFrom(_projection_matrix * _view_matrix * _world_matrix);
  }

  /// Helper: Transforms world point to camera space Z using View*World matrix.
  static double _get_camera_space_z(double x, double y, double z) {
    _input_point_4d.setValues(x, y, z, 1.0);

    // Calculate the combined View * World matrix
    _view_world_matrix_temp.setFrom(_view_matrix);
    _view_world_matrix_temp.multiply(_world_matrix);
    _view_world_matrix_temp.negate(); // TODO: WTF!?

    // Copy input to output vector first
    _camera_space_point_4d.setFrom(_input_point_4d);

    // Apply the transformation in-place to the output vector
    _camera_space_point_4d.applyMatrix4(_view_world_matrix_temp);

    // Return the Z coordinate from the transformed vector
    return _camera_space_point_4d.z;
  }

  /// Calculates perspective scale relative to ref_z using camera space z.
  double perspective_scale({
    required double x,
    double y = 0.0,
    required double z,
    double ref_z = 0.0,
  }) {
    final cam_z_target = _get_camera_space_z(x, y, z);
    final cam_z_ref = _get_camera_space_z(x, y, ref_z);
    final double clipped_cam_z_target = max(near_z, cam_z_target);
    final double clipped_cam_z_ref = max(near_z, cam_z_ref);
    if (clipped_cam_z_target.abs() < 1e-9) return 0.0;
    return clipped_cam_z_ref / clipped_cam_z_target;
  }

  /// Projects world coordinate (x, y, z) to screen coordinates using matrices.
  static Vector2 project({required double x, double y = 0.0, required double z, Vector2? out}) {
    // 1. Transform World to Clip Space using combined WVP matrix
    _input_point_4d.setValues(x, y, z, 1.0);

    // Copy input to output vector for clip space calculation
    _clip_space_point_4d.setFrom(_input_point_4d);
    // Apply WVP matrix in-place
    _clip_space_point_4d.applyMatrix4(_wvp_matrix);

    // 2. Perspective Divide (Clip Space to NDC)
    final w = max(0.00001, _clip_space_point_4d.w);
    final double ndc_x = _clip_space_point_4d.x / w;
    final double ndc_y = _clip_space_point_4d.y / w;

    // 3. Viewport Transform (NDC to Screen Coordinates)
    final double screen_width = game_size.x;
    final double screen_height = game_size.y;
    out ??= _result;
    out.x = game_center.x + ndc_x * (screen_width / 2);
    out.y = game_center.y + ndc_y * (screen_height / 2);

    // 4. Apply final 2D Screen Offset
    out.add(_camera.offset);

    return out;
  }

  /// The position along the path or primary horizontal axis in grid space.
  // late double grid_x;
  double get grid_x => grid.x + translation.x;

  set grid_x(double value) => grid.x = value;

  /// The depth position in grid space (0.0=foreground, 1.0=nominal background).
  /// Implementations should return 0.0 if the concept is not applicable.
  // late double grid_z;
  double get grid_z => grid.z + translation.z;

  set grid_z(double value) => grid.z = value;

  final grid = Vector3.zero();
  final translation = Vector3.zero();

  @override
  void update(double dt) {
    super.update(dt);
    priority = (grid_z * -100 + size.y * 0.5).round();
  }

  @override
  String toString() => 'HF3D(x: $grid_x, z: $grid_z)';
}
