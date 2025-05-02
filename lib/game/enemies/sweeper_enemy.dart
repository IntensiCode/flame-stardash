import 'dart:ui';

import 'package:flame/components.dart';
import 'package:stardash/game/base/has_context.dart';
import 'package:stardash/game/level/level.dart';
import 'package:stardash/game/player/player.dart';

enum BasicEnemyState {
  Landing,
  Approaching,
  Hunting,
}

class SweeperEnemy extends PositionComponent with HasContext, HasPaint {
  double gridX = 0.0;
  double gridY = 1.0;
  double gridZ = 1.0;

  static const double _baseSize = 32.0; // Target size at gridZ = 0
  double _currentScale = 0.5; // Initial scale at gridZ = 1.0

  // State Machine
  BasicEnemyState _state = BasicEnemyState.Landing;

  // Fade-in
  static const double _fadeInDuration = 1.5; // seconds
  double _timeAlive = 0.0;

  // Movement Speeds
  static const double _landingSpeedY = 0.5; // grid units per second
  static const double _approachingSpeedZ = 0.2; // grid units per second
  static const double _huntingSpeedX = 0.1; // grid units per second

  SweeperEnemy() : super(anchor: Anchor.center, size: Vector2.all(_baseSize)) {
    paint.color = const Color(0xFFFF0000).withAlpha(0); // Start transparent red
    // Initial position/scale calculated in onMount based on initial grid coords
  }

  @override
  void onMount() {
    super.onMount();
    _updatePositionScalePriority(); // Set initial screen pos and scale
  }

  @override
  void update(double dt) {
    super.update(dt);
    _timeAlive += dt;

    // --- State Machine Logic ---
    switch (_state) {
      case BasicEnemyState.Landing:
        _updateLanding(dt);
        break;
      case BasicEnemyState.Approaching:
        _updateApproaching(dt);
        break;
      case BasicEnemyState.Hunting:
        _updateHunting(dt);
        break;
    }

    // --- Update Screen Position, Scale & Priority ---
    _updatePositionScalePriority();
  }

  void _updateLanding(double dt) {
    // Fade In
    if (_timeAlive < _fadeInDuration) {
      final fadeInProgress = _timeAlive / _fadeInDuration;
      paint.color =
          paint.color.withAlpha((fadeInProgress.clamp(0.0, 1.0) * 255).toInt());
    } else {
      paint.color = paint.color.withAlpha(255); // Ensure full opacity
    }

    // Move Y down
    if (gridY > 0.0) {
      gridY -= _landingSpeedY * dt;
    }

    // Check for state transition
    if (gridY <= 0.0) {
      gridY = 0.0;
      paint.color =
          paint.color.withAlpha(255); // Ensure full opacity on transition
      _state = BasicEnemyState.Approaching;
    }
  }

  void _updateApproaching(double dt) {
    // Move Z towards player
    if (gridZ > 0.0) {
      gridZ -= _approachingSpeedZ * dt;
    }

    // Check for state transition
    if (gridZ <= 0.0) {
      gridZ = 0.0;
      _state = BasicEnemyState.Hunting;
    }
  }

  void _updateHunting(double dt) {
    // Move X towards player
    final targetX = player.grid_x; // Get player's current gridX
    final deltaX = level.shortest_grid_x_delta(gridX, targetX);

    // Move if not already close enough
    if (deltaX.abs() > 0.01) {
      // Tolerance to prevent jitter
      final moveDirection = deltaX.sign;
      double potentialMove = moveDirection * _huntingSpeedX * dt;

      // Prevent overshooting the target in a single step
      if (potentialMove.abs() > deltaX.abs()) {
        potentialMove = deltaX;
      }

      gridX += potentialMove;

      // Apply wrap-around logic for closed paths
      if (level.is_closed) {
        if (gridX > 1.0) gridX -= 2.0;
        if (gridX < -1.0) gridX += 2.0;
      } else {
        // Clamp for open paths (should already be handled by overshoot prevention)
        gridX = gridX.clamp(-1.0, 1.0);
      }
    }
  }

  void _updatePositionScalePriority() {
    // Update scale based on Z
    _currentScale = (1.0 - 0.8 * gridZ).clamp(0.1, 2.0);
    size.setAll(_baseSize * _currentScale);

    // Update screen position using XYZ mapping
    level.map_grid_xyz_to_screen(gridX, gridY, gridZ,
        out: position, clamp_and_wrap_x: false);

    // Update render priority based on depth
    priority = (gridZ * -1000).round();
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    // Draw a circle centered in the component
    final radius = size.x / 2;
    canvas.drawCircle(Offset(radius, radius), radius, paint);
  }
}
