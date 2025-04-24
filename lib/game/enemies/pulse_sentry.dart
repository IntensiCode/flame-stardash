import 'dart:math';
import 'dart:ui';

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flutter/animation.dart'; // Import for Curves
import 'package:flutter/material.dart';
import 'package:stardash/game/base/fake_three_d.dart';
import 'package:stardash/game/base/has_context.dart';
import 'package:stardash/game/base/kinds.dart';
import 'package:stardash/game/enemies/pulse_bullet.dart';
import 'package:stardash/game/level/level.dart';
import 'package:stardash/util/log.dart';

class PulseSentryComponent extends PositionComponent with HasContext, HasFakeThreeDee, OnHit, Hostile {
  static const double initialStrength = 10.0;

  PulseSentryComponent({
    required this.grid_x,
    this.color = const Color(0xFFFF00FF), // Magenta color
    this.baseSize = 25.0,
    this.zSpeed = 0.11, // Constant speed towards stopZ
    this.stopZ = 0.66, // Stops further out
    // Firing Parameters
    this.fireInterval = 2.0, // Matches pulse duration
    // Pulsing Parameters
    this.pulseDuration = 2.0, // 1 sec grow, 1 sec shrink
    this.maxPulseScaleFactor = 1.5, // How much bigger it gets
    // Visual Parameters
    this.alphaFalloff = 0.8,
    // Falling Parameters (might not be needed if it stops)
    this.gravity = 150.0,
  })  : _strength = initialStrength,
        _segmentGridZ = 1.0,
        // Start at Z=1.0
        super(anchor: Anchor.center);

  @override
  final double grid_x;

  final Color color;
  final double baseSize;
  final double zSpeed;
  final double stopZ;
  final double fireInterval;
  final double pulseDuration;
  final double maxPulseScaleFactor;
  final double alphaFalloff;
  final double gravity; // Keep for potential future use?

  // --- State ---
  double _strength;
  double _segmentGridZ;
  double _fireTimer = 0.0;
  bool _isStopped = false;
  double _pulseTimer = 0.0;
  double _pulseScaleMultiplier = 1.0;

  // --- Configuration ---
  final Curve _pulseCurve = Curves.easeInOutCubic;

  // --- Rendering & Collision ---
  final Paint _bodyFillPaint = Paint();
  final Paint _bodyStrokePaint = Paint();
  late final CircleHitbox _hitbox;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    _hitbox = CircleHitbox(
      radius: baseSize / 2,
      anchor: Anchor.topLeft, // Relative to component's center anchor
      collisionType: CollisionType.passive,
    );
    await add(_hitbox);

    _bodyFillPaint.color = color.withOpacity(0.6);
    _bodyFillPaint.style = PaintingStyle.fill;
    _bodyStrokePaint.color = color;
    _bodyStrokePaint.style = PaintingStyle.stroke;
    _bodyStrokePaint.strokeWidth = 2.0;

    _updatePositionAndSize();
  }

  void _updatePulse(double dt) {
    if (!_isStopped) return; // Only pulse when stopped

    _pulseTimer = (_pulseTimer + dt) % pulseDuration;
    final halfDuration = pulseDuration / 2.0;
    final t = _pulseTimer / halfDuration;

    double curveValue;
    if (t <= 1.0) {
      // Growing phase (0 to 1)
      curveValue = _pulseCurve.transform(t);
    } else {
      // Shrinking phase (1 to 0)
      curveValue = _pulseCurve.transform(2.0 - t);
    }

    // Map curve value (0 to 1) to scale multiplier (1.0 to maxPulseScaleFactor)
    _pulseScaleMultiplier = 1.0 + (maxPulseScaleFactor - 1.0) * curveValue;
  }

  void _updateSizeAndHitbox() {
    final perspectiveScale = perspective_scale_factor(
          _segmentGridZ,
          level.outer_scale_factor,
          level.deep_scale_factor,
        ) /
        level.outer_scale_factor;
    final baseScale = max(0.1, perspectiveScale);

    // Calculate scale based on strength (1.0 at full, 0.25 at zero)
    final strengthScaleMultiplier = (0.25 + 0.75 * (_strength / initialStrength)).clamp(0.25, 1.0);

    // Apply pulse scale and strength scale multiplier
    final currentScale = baseScale * _pulseScaleMultiplier * strengthScaleMultiplier;
    final currentVisualSize = baseSize * currentScale;

    size.setAll(currentVisualSize);
    if (_hitbox.isMounted) {
      _hitbox.radius = currentVisualSize / 2;
    }
  }

  void _updatePositionAndSize() {
    level.map_grid_to_screen(grid_x, _segmentGridZ, out: position);
    _updateSizeAndHitbox();
  }

  void _move(double dt) {
    if (_isStopped) return;

    // Move towards stopZ with constant speed
    _segmentGridZ -= zSpeed * dt;

    // Clamp Z to stop point and check if stopped
    if (_segmentGridZ <= stopZ) {
      _segmentGridZ = stopZ;
      _isStopped = true;
      _fireTimer = fireInterval / 2.0; // Prime to fire at peak pulse
      _pulseTimer = 0.0; // Start pulse from beginning
      log_info('PulseSentry at $grid_x stopped at Z=$_segmentGridZ');
    }
  }

  void _firePulse(double dt) {
    if (!_isStopped) return;

    _fireTimer -= dt;

    // Check if it's time to fire AND the pulse is near its peak
    final halfDuration = pulseDuration / 2.0;
    final peakTimeTolerance = dt * 1.5; // Allow firing slightly around the peak
    final isAtPeak = (_pulseTimer - halfDuration).abs() < peakTimeTolerance;

    if (_fireTimer <= 0 && isAtPeak) {
      // Calculate bullet damage based on current strength
      final bulletDamage = (0.25 + 0.75 * (_strength / initialStrength)).clamp(0.25, 1.0);

      final bullet = PulseBullet(
        initial_grid_x: grid_x,
        initial_grid_z: _segmentGridZ,
        damage: bulletDamage,
      );
      parent?.add(bullet); // Add to the same parent (likely the Level)
      _fireTimer = fireInterval; // Reset timer for the next shot
    }
  }

  @override
  void update(double dt) {
    super.update(dt);

    _move(dt);
    _updatePulse(dt); // Update pulse timer and scale
    _firePulse(dt);
    _updatePositionAndSize(); // Update size *after* pulse and strength calculation

    // Simple removal check if it somehow goes past the stop point (shouldn't happen)
    if (_segmentGridZ < 0) {
      removeFromParent();
    }
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    // Center the drawing within the component's size
    final renderCenter = size / 2;

    // Radius is now directly half of the calculated size (which includes pulse and strength)
    final radius = size.x / 2;

    // Adjust alpha if needed (e.g., fading in/out)
    // For now, keep alpha constant
    if (hit_time > 0) {
      _bodyFillPaint.color = Colors.white;
      _bodyStrokePaint.color = Colors.white;
    } else {
      _bodyFillPaint.color = color.withValues(alpha: 0.6);
      _bodyStrokePaint.color = color;
    }

    canvas.drawCircle(renderCenter.toOffset(), radius, _bodyFillPaint);
    canvas.drawCircle(renderCenter.toOffset(), radius, _bodyStrokePaint);
  }

  // --- HasFakeThreeDee Mixin Implementation ---
  @override
  double get grid_y => 0.0;

  @override
  double get grid_z => _segmentGridZ;

  // --- Hostile Mixin Implementation ---
  @override
  void on_hit(double damage) {
    super.on_hit(damage);
    _strength -= damage;

    if (_strength <= 0) {
      removeFromParent();
      // TODO: Add particle effects or scoring later
    } else {
      // Force an update to size/hitbox immediately after taking damage
      _updatePositionAndSize();
    }
  }
}
