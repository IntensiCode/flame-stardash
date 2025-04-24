import 'dart:math';
import 'dart:ui'; // Added for Paint, Offset, Color

import 'package:flame/components.dart';
import 'package:flame/extensions.dart';
import 'package:stardash/core/atlas.dart';
// Removed PlayerBullet import - no firing
import 'package:stardash/game/base/has_context.dart';
import 'package:stardash/game/level/level.dart';
import 'package:stardash/game/base/voxel_entity.dart';
import 'package:stardash/input/game_keys.dart';
// Removed Keys import - no player input

// Removed Player HasContext extension

class VoxelEnemy extends PositionComponent with HasContext, _EnemyMovement {
  VoxelEnemy() : super() {
    anchor = Anchor.center;
    size.setAll(32); // Use same base size as player for now
  }

  @override
  Future onLoad() async {
    // Using player asset for now, replace with enemy asset later
    final voxelImage = atlas.sprite('voxel/squashamid50');
    _voxel = VoxelEntity(
      voxel_image: voxelImage,
      height_frames: 50,
      exhaust_color: Color(0xFF67ff48),
      parent_size: size,
    );
    _voxel.model_scale.setValues(0.8, 0.8, 0.8); // Same scale as player
    _voxel.exhaust_length = 8; // Same exhaust as player
    await add(_voxel);
    // Set different exhaust colors if needed
    _voxel.set_exhaust_color(0, const Color(0xFFFF8000));
    _voxel.set_exhaust_color(1, const Color(0xFFFF0000));
    _voxel.set_exhaust_color(2, const Color(0xFFA00000));
    _voxel.set_exhaust_color(3, const Color(0xFF800000));
    _voxel.set_exhaust_color(4, const Color(0xFF600000));
  }

  @override
  void onMount() {
    super.onMount();
    // Initialize enemy state here if needed in the future
    gridZ = 1.0; // <<< SET ENEMY DEPTH TO 1.0
  }

// Removed update override - movement handled in mixin
// Removed firing logic (_handleFiring, _fireBullet, related variables)
}

// Renamed mixin to avoid conflict if Player is also present
mixin _EnemyMovement on PositionComponent, HasContext {
  // This mixin is largely copied from Player._PlayerMovement
  // but removes player input and uses a configurable gridZ

  late final VoxelEntity _voxel;

  double gridX = 0.0;
  double gridZ = 0.0; // <<< ADDED gridZ FIELD
  double _currentGridSpeed = 0.0;
  static const double _gridMaxSpeed = 0.2; // Enemy might be slower
  static const double _gridAcceleration = 1.0; // Enemy might accelerate differently
  static const double _gridDeceleration = 1.5;

  // Orientation fields remain the same
  final _smoothedNormal = Vector2(0, 1);
  final _targetNormal = Vector2.zero();
  final _smoothedDepth = Vector2(0, -1);
  final _targetDepth = Vector2.zero();
  static const double _orientationSmoothingFactor = 0.15;
  static const double _depthTiltFactor = 0.1;
  static const double _yawFactor = 0.5;
  static final _baseOrientation = Matrix3.identity();
  static final _finalOrientation = Matrix3.identity();
  static final _xTiltRotation = Matrix3.rotationX(-pi / 12);
  double _wobbleAnim = 0;
  static final _maxWobble = pi / 64;
  static final _wobbleMatrix = Matrix3.identity();
  static final _rotX = Matrix3.identity();
  final _rotY = Matrix3.identity();
  static final _rotZ = Matrix3.identity();
  final _yawRotationZ = Matrix3.identity();
  final _tempVec = Vector3.zero();

  // Temporary vectors for orientation calculation (were missing)
  final _forward = Vector3.zero();
  final _up = Vector3.zero();
  final _right = Vector3.zero();
  final _depth = Vector3.zero();
  final _idealRight = Vector3.zero();
  final _actualRight = Vector3.zero();

  @override
  void onMount() {
    // gridZ is set by the VoxelEnemy class
    gridX = 0.0; // Start at center X
    _currentGridSpeed = 0.0;
    position.setFrom(level.map_grid_to_screen(gridX, gridZ)); // <<< USE gridZ
    level.get_orientation_normal(gridX, out: _smoothedNormal);
    level.get_depth_vector(gridX, out: _smoothedDepth);
    _wobbleAnim = 0;
    _updateOrientation();
  }

  @override
  void update(double dt) {
    _updateGridMovement(dt);
    gridZ = 0.5 + sin(_wobbleAnim / 2.623123) * 0.5;
    gridX += cos(_wobbleAnim * 0.96843) * 0.0051;
    level.map_grid_to_screen(gridX, gridZ, out: position); // <<< USE gridZ

    // Orientation updates remain the same
    level.get_orientation_normal(gridX, out: _targetNormal);
    level.get_depth_vector(gridX, out: _targetDepth);
    _smoothedNormal.lerp(_targetNormal, _orientationSmoothingFactor);
    _smoothedNormal.normalize();
    _smoothedDepth.lerp(_targetDepth, _orientationSmoothingFactor);
    _smoothedDepth.normalize();
    _updateWobble(dt);
    _updateOrientation();

    // Update render priority based on depth
    priority = (gridZ * -1000).round(); // Higher Z = lower priority (further back)

    final scale = lerpDouble(1.0, 0.25, sqrt(gridZ)) ?? 1.0;
    size.setAll(64 * scale); // Scale based on gridZ
  }

  void _updateGridMovement(double dt) {
    var moveInput = 0.0;
    if (keys.check(GameKey.left)) moveInput -= 1.0;
    if (keys.check(GameKey.right)) moveInput += 1.0;

    // --- Uses same speed/wrap logic as player, but without input ---
    _applySpeed(dt, moveInput);

    // Use same visually consistent speed logic
    const double referencePathLength = 2 * pi;
    final double currentPathLength = level.total_normalized_path_length;
    final double speedScaleFactor = (currentPathLength > 1e-6) ? referencePathLength / currentPathLength : 1.0;
    gridX += _currentGridSpeed * speedScaleFactor * dt;

    _wrapAroundOrStop();
  }

  // _applySpeed remains largely the same, driven by moveInput (which is 0 for now)
  void _applySpeed(double dt, double moveInput) {
    if (moveInput != 0) {
      _currentGridSpeed += moveInput * _gridAcceleration * dt;
      _currentGridSpeed = _currentGridSpeed.clamp(-_gridMaxSpeed, _gridMaxSpeed);
    } else {
      if (_currentGridSpeed.abs() < 0.01) {
        _currentGridSpeed = 0.0;
      } else {
        final friction = _gridDeceleration * dt;
        if (_currentGridSpeed > 0) {
          _currentGridSpeed = max(0.0, _currentGridSpeed - friction);
        } else {
          _currentGridSpeed = min(0.0, _currentGridSpeed + friction);
        }
      }
    }
  }

  // _wrapAroundOrStop remains the same
  void _wrapAroundOrStop() {
    final isClosed = level.path_type.closed;
    if (isClosed) {
      if (gridX > 1.0)
        gridX -= 2.0;
      else if (gridX < -1.0) gridX += 2.0;
    } else {
      final clampedX = gridX.clamp(-1.0, 1.0);
      if (clampedX != gridX) {
        gridX = clampedX;
        _currentGridSpeed = 0.0;
      }
    }
  }

  // _updateOrientation remains the same
  void _updateOrientation() {
    _up.setValues(_smoothedNormal.x, _smoothedNormal.y, 0);
    _up.normalize();
    _depth.setValues(_smoothedDepth.x, _smoothedDepth.y, 0);
    _depth.normalize();
    _forward.setValues(-_up.y, _up.x, 0);
    _forward.crossInto(_up, _actualRight);
    _actualRight.normalize();
    _forward.crossInto(_depth, _idealRight);
    _idealRight.normalize();
    if (_actualRight.length2 < 1e-12) _actualRight.setValues(0, 0, 1);
    if (_idealRight.length2 < 1e-12) _idealRight.setValues(0, 0, 1);
    _tempVec.setFrom(_actualRight);
    _tempVec.scale(1.0 - _depthTiltFactor);
    _right.setFrom(_idealRight);
    _right.scale(_depthTiltFactor);
    _right.add(_tempVec);
    _right.normalize();
    _right.crossInto(_forward, _up);
    _up.normalize();
    _baseOrientation.setValues(_forward.x, _up.x, _right.x, _forward.y, _up.y, _right.y, _forward.z, _up.z, _right.z);
    _finalOrientation.setFrom(_baseOrientation);
    _finalOrientation.multiply(_xTiltRotation);
    final angleNormal = atan2(_smoothedNormal.y, _smoothedNormal.x);
    final angleDepth = atan2(_smoothedDepth.y, _smoothedDepth.x);
    double angleDifference = angleDepth - angleNormal;
    while (angleDifference > pi) angleDifference -= 2 * pi;
    while (angleDifference < -pi) angleDifference += 2 * pi;
    final targetYawZ = angleDifference * _yawFactor;
    _yawRotationZ.setRotationY(-targetYawZ); // Corrected to Y-axis for Z-yaw
    _finalOrientation.multiply(_yawRotationZ);
    _finalOrientation.multiply(_wobbleMatrix);
    _voxel.orientation_matrix.setFrom(_finalOrientation);
  }

  // _updateWobble remains the same
  void _updateWobble(double dt) {
    final wobbleX = sin(_wobbleAnim * 1.78926) * _maxWobble;
    final wobbleY = _wobbleAnim; // sin(_wobbleAnim * 1.99292) * _maxWobble;
    final wobbleZ = sin(_wobbleAnim * 2.12894) * _maxWobble;
    _wobbleAnim += dt;
    _rotX.setRotationX(wobbleX - pi);
    _rotY.setRotationY(wobbleY);
    _rotZ.setRotationZ(wobbleZ);
    _wobbleMatrix.setFrom(_rotZ);
    _wobbleMatrix.multiply(_rotY);
    _wobbleMatrix.multiply(_rotX);
  }

// Removed render override and debug drawing - VoxelEntity handles render
}
