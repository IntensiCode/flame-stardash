import 'dart:ui';

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:stardash/game/base/fake_three_d.dart';
import 'package:stardash/game/base/has_context.dart';
import 'package:stardash/game/base/kinds.dart';
import 'package:stardash/game/level/level.dart';
import 'package:stardash/util/mutable.dart';

class PlayerBullet extends PositionComponent
    with HasContext, HasFakeThreeDee, CollisionCallbacks {
  final double initial_grid_x;
  double _gridZ = 0.0;
  static const double _gridZSpeed = 0.8;
  static const double _fadeStartZ = 1.0;
  static const double _removeZ = 1.5;

  // Base radius and scale factor
  static const double _baseRadius = 5.0;
  double _currentScale = 1.0;

  // Paints for circles
  final Paint _outerPaint = Paint()
    ..color = const Color(0xFF0050FF); // Dark blue
  final Paint _innerPaint = Paint()..color = const Color(0xFFFFFFFF); // White

  late final CircleHitbox _hitbox;

  PlayerBullet({required this.initial_grid_x})
      : super(anchor: Anchor.center, size: Vector2.all(_baseRadius * 2)) {
    // No size set here, calculated dynamically
    _gridZ = 0.0;
    // Initial position calculation moved to onMount
    // size.setAll(_baseRadius * 2);
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    _hitbox = CircleHitbox(radius: _baseRadius, anchor: Anchor.topLeft);
    add(_hitbox);
  }

  @override
  void onMount() {
    super.onMount();
    // Calculate initial position here, now that context (level) is available
    position.setFrom(level.map_grid_to_screen(initial_grid_x, _gridZ,
        clamp_and_wrap_x: false));
  }

  @override
  void update(double dt) {
    super.update(dt);

    // Move along Z axis
    _gridZ += _gridZSpeed * dt;

    // Remove if past the removal point
    if (_gridZ >= _removeZ) {
      removeFromParent();
      return;
    }

    // Update screen position
    level.map_grid_to_screen(initial_grid_x, _gridZ,
        out: position, clamp_and_wrap_x: false);

    // Update priority based on depth
    priority = (_gridZ * -1000).round();

    // Calculate perspective scaling using the centralized function
    // Note: getPerspectiveScaleFactor clamps gridZ between 0.0 and 1.0 internally
    // Divide by outerScaleFactor to get a relative scale multiplier (1.0 down to 0.25)
    _currentScale = perspective_scale_factor(
          _gridZ,
          level.outer_scale_factor, // Use outer scale from level
          level.deep_scale_factor, // Use deep scale from level
        ) /
        level.outer_scale_factor;

    // Update visual size and hitbox size based on current scale
    final scaledDiameter = _baseRadius * _currentScale * 2;
    size.setAll(scaledDiameter); // Update component size
    _hitbox.radius = scaledDiameter / 2; // Update hitbox radius
    // The hitbox position is relative to the component's anchor (topLeft now),
    // so we don't need to adjust its position here.

    // Handle alpha fade out
    double alpha = 1.0;
    if (_gridZ > _fadeStartZ) {
      final fadeProgress = (_gridZ - _fadeStartZ) / (_removeZ - _fadeStartZ);
      alpha = (1.0 - fadeProgress).clamp(0.0, 1.0);
    }
    _outerPaint.color = _outerPaint.color.withAlpha((alpha * 255).toInt());
    _innerPaint.color = _innerPaint.color.withAlpha((alpha * 255).toInt());
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    final scaledOuterRadius = _baseRadius * _currentScale;
    final scaledInnerRadius =
        scaledOuterRadius * 0.6; // Inner is smaller portion

    _center.dx = scaledOuterRadius;
    _center.dy = scaledOuterRadius;
    // Draw outer circle
    canvas.drawCircle(_center, scaledOuterRadius, _outerPaint);
    // Draw inner circle
    canvas.drawCircle(_center, scaledInnerRadius, _innerPaint);
  }

  static final _center = MutableOffset(0, 0);

  // --- HasFakeThreeDee Mixin ---

  @override
  double get grid_x => initial_grid_x; // Bullet's X is fixed after spawn

  @override
  double get grid_y => 0.0; // Bullets travel along the Z-plane

  @override
  double get grid_z => _gridZ;

  @override
  void onCollisionStart(
      Set<Vector2> intersectionPoints, PositionComponent other) {
    super.onCollisionStart(intersectionPoints, other);

    // Check if the other component is both Hostile and HasFakeThreeDee
    if (other case Hostile hostileTarget && HasFakeThreeDee threeDeeTarget) {
      // Check if "z" is "close":
      if ((threeDeeTarget.grid_z - grid_z).abs() < 0.1) {
        // Apply damage and remove bullet
        hostileTarget.on_hit(1.0); // TODO: Define actual bullet damage
        removeFromParent();
      }
    }
  }
}
