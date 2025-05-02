import 'dart:ui';

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:stardash/game/base/fake_three_d.dart';
import 'package:stardash/game/base/has_context.dart';
import 'package:stardash/game/base/kinds.dart';
import 'package:stardash/game/level/level.dart';
import 'package:stardash/util/mutable.dart';

class PulseBullet extends PositionComponent
    with HasContext, HasFakeThreeDee, CollisionCallbacks {
  final double initial_grid_x;
  final double initial_grid_z;
  final double damage; // Damage dealt by this bullet
  double _gridZ;
  static const double _gridZSpeed = 0.6; // Slower than player bullet?
  static const double _fadeEndZ = -0.2; // Fade out past the player plane
  static const double _removeZ = -0.5; // Remove further out

  // Base radius and scale factor
  static const double _baseRadius = 4.0; // Slightly smaller?
  double _currentScale = 1.0;

  // Paints for circles (different color)
  final Paint _outerPaint = Paint()..color = const Color(0xFFFFA500); // Orange
  final Paint _innerPaint = Paint()
    ..color = const Color(0xFFFFE0B2); // Light Orange

  late final CircleHitbox _hitbox;

  PulseBullet({
    required this.initial_grid_x,
    required this.initial_grid_z,
    required this.damage,
  })  : _gridZ = initial_grid_z,
        super(anchor: Anchor.center, size: Vector2.all(_baseRadius * 2));

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    _hitbox = CircleHitbox(radius: _baseRadius, anchor: Anchor.topLeft);
    add(_hitbox);
  }

  @override
  void onMount() {
    super.onMount();
    // Initial position calculated based on spawn Z
    position.setFrom(level.map_grid_to_screen(initial_grid_x, _gridZ,
        clamp_and_wrap_x: false));
  }

  @override
  void update(double dt) {
    super.update(dt);

    // Move along Z axis (negative direction)
    _gridZ -= _gridZSpeed * dt;

    // Remove if past the removal point
    if (_gridZ <= _removeZ) {
      removeFromParent();
      return;
    }

    // Update screen position
    level.map_grid_to_screen(initial_grid_x, _gridZ,
        out: position, clamp_and_wrap_x: false);

    // Update priority based on depth
    priority = (_gridZ * -1000).round();

    // Calculate perspective scaling
    _currentScale = perspective_scale_factor(
          _gridZ,
          level.outer_scale_factor,
          level.deep_scale_factor,
        ) /
        level.outer_scale_factor;

    // Update visual size and hitbox size based on current scale
    final scaledDiameter = _baseRadius * _currentScale * 2;
    size.setAll(scaledDiameter);
    _hitbox.radius = scaledDiameter / 2;

    // Handle alpha fade out (fades as it approaches Z=0)
    double alpha = 1.0;
    if (_gridZ < 0) {
      // Start fading when gridZ goes negative
      final fadeProgress =
          (_gridZ / _fadeEndZ).clamp(0.0, 1.0); // Fade from 0 to fadeEndZ
      alpha = (1.0 - fadeProgress).clamp(0.0, 1.0);
    }
    _outerPaint.color = _outerPaint.color.withAlpha((alpha * 255).toInt());
    _innerPaint.color = _innerPaint.color.withAlpha((alpha * 255).toInt());
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    final scaledOuterRadius = _baseRadius * _currentScale;
    final scaledInnerRadius = scaledOuterRadius * 0.6;

    _center.dx = scaledOuterRadius;
    _center.dy = scaledOuterRadius;
    canvas.drawCircle(_center, scaledOuterRadius, _outerPaint);
    canvas.drawCircle(_center, scaledInnerRadius, _innerPaint);
  }

  static final _center = MutableOffset(0, 0);

  // --- HasFakeThreeDee Mixin ---
  @override
  double get grid_x => initial_grid_x;

  @override
  double get grid_y => 0.0;

  @override
  double get grid_z => _gridZ;

  @override
  void onCollisionStart(
      Set<Vector2> intersectionPoints, PositionComponent other) {
    super.onCollisionStart(intersectionPoints, other);

    // Check if the other component is Friendly and HasFakeThreeDee
    if (other case Friendly friendlyTarget && HasFakeThreeDee threeDeeTarget) {
      // Check if "z" is "close" (near the player plane Z=0)
      if ((threeDeeTarget.grid_z - grid_z).abs() < 0.1) {
        // Apply damage and remove bullet
        friendlyTarget.on_hit(damage); // Use the bullet's damage
        removeFromParent();
      }
    }
  }
}
