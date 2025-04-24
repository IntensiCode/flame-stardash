import 'dart:ui';

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flutter/animation.dart';
import 'package:stardash/game/base/fake_three_d.dart';
import 'package:stardash/game/base/has_context.dart';
import 'package:stardash/game/base/kinds.dart';
import 'package:stardash/game/level/level.dart';

class VectorSpike extends PositionComponent with HasContext, FakeThreeDee, CollisionCallbacks {
  final double initial_grid_x;
  final double target_grid_x;
  final double damage; // Damage dealt by this spike
  double _gridX;
  static const double _gridXSpeed = 0.3; // Speed towards player on X axis
  static const double _lifetime = 1.0; // Lifetime in seconds

  // Base size for the crossed lines
  static const double _baseSize = 8.0;
  double _currentScale = 1.0;

  // Paints for the crossed lines
  final Paint _linePaint = Paint()
    ..color = const Color(0xFFFFA500) // Orange
    ..strokeWidth = 2.0;

  late final RectangleHitbox _hitbox;

  double _timeAlive = 0.0;
  double _rotation = 0.0;
  final Curve _fadeCurve = Curves.easeInCubic;

  VectorSpike({
    required this.initial_grid_x,
    required this.target_grid_x,
    required this.damage,
  })  : _gridX = initial_grid_x,
        super(anchor: Anchor.center, size: Vector2.all(_baseSize * 2));

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    _hitbox = RectangleHitbox(size: Vector2.all(_baseSize));
    add(_hitbox);
  }

  @override
  void onMount() {
    super.onMount();
    // Initial position calculated based on spawn X
    position.setFrom(level.map_grid_to_screen(initial_grid_x, 0.0, clamp_and_wrap_x: false));
  }

  @override
  void update(double dt) {
    super.update(dt);

    _timeAlive += dt;
    // Remove if lifetime exceeded
    if (_timeAlive >= _lifetime) {
      removeFromParent();
      return;
    }

    // Move along X axis towards player
    final deltaX = target_grid_x - _gridX;
    if (deltaX.abs() > 0.01) {
      final moveDirection = deltaX.sign;
      double potentialMove = moveDirection * _gridXSpeed * dt;
      if (potentialMove.abs() > deltaX.abs()) {
        potentialMove = deltaX;
      }
      _gridX += potentialMove;
    }

    // Update screen position
    level.map_grid_to_screen(_gridX, 0.0, out: position, clamp_and_wrap_x: false);

    // Update priority based on depth
    priority = 0; // Fixed at z=0

    // Calculate perspective scaling (fixed at z=0)
    _currentScale = perspective_scale(x: grid_x, z: 0.0);

    // Update visual size and hitbox size based on current scale
    final scaledSize = _baseSize * _currentScale * 2;
    size.setAll(scaledSize);
    _hitbox.size.setAll(scaledSize);

    // Handle alpha fade out
    final fadeProgress = (_timeAlive / _lifetime).clamp(0.0, 1.0);
    final curvedFade = _fadeCurve.transform(fadeProgress);
    final alpha = (1.0 - curvedFade / 3).clamp(0.0, 1.0);
    _linePaint.color = _linePaint.color.withOpacity(alpha);

    // Update rotation for visual effect
    _rotation += dt * 2; // Rotate at 2 radians per second
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    final scaledSize = _baseSize * _currentScale;
    final centerX = scaledSize;
    final centerY = scaledSize;

    canvas.save();
    canvas.translate(centerX, centerY);
    canvas.rotate(_rotation);

    // Draw first line
    canvas.drawLine(Offset(-scaledSize, 0), Offset(scaledSize, 0), _linePaint);
    // Draw second line
    canvas.drawLine(Offset(0, -scaledSize), Offset(0, scaledSize), _linePaint);

    canvas.restore();
  }

  // --- HasFakeThreeDee Mixin ---
  @override
  double get grid_x => _gridX;

  @override
  double get grid_z => 0.0;

  @override
  void onCollisionStart(Set<Vector2> intersectionPoints, PositionComponent other) {
    super.onCollisionStart(intersectionPoints, other);

    // Check if the other component is Friendly and HasFakeThreeDee
    if (other case Friendly friendlyTarget && FakeThreeDee threeDeeTarget) {
      // Check if "z" is "close" (near the player plane Z=0)
      if ((threeDeeTarget.grid_z - grid_z).abs() < 0.1) {
        // Apply damage and remove spike
        friendlyTarget.on_hit(damage);
        removeFromParent();
      }
    }
  }
}
