import 'dart:math';
import 'dart:ui';

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flutter/animation.dart'; // Import for Curves
import 'package:stardash/core/common.dart'; // For gameHeight/Width access?
import 'package:stardash/game/base/fake_three_d.dart';
import 'package:stardash/game/base/has_context.dart';
import 'package:stardash/game/base/kinds.dart';
import 'package:stardash/game/enemies/vector_spike.dart';
import 'package:stardash/game/level/level.dart';
import 'package:stardash/game/player/player.dart';
import 'package:stardash/util/log.dart';

class VectorCrawler extends PositionComponent with HasContext, FakeThreeDee, OnHit, Hostile {
  VectorCrawler({
    required this.grid_x,
    this.color = const Color(0xFF00FF00),
    this.baseSegmentSize = 20,
    int initialNumberOfSegments = 10,
    this.segmentTimeOffset = 0.2,
    // Movement Parameters
    this.move_distance = 0.1,
    this.move_duration = 1.2,
    this.pauseDuration = 0.3,
    // Visual Parameters
    this.visualSegmentSpacingZ = 0.00,
    this.wobble_amplitude_y = -5.0,
    this.alphaFalloff = 0.8,
    // Falling Parameters
    this.gravity = 150.0, // Pixels per second per second
  })  : numberOfSegments = initialNumberOfSegments,
        _finalBaseSegmentSize = baseSegmentSize * 1.1,
        _cycle_duration = move_duration + pauseDuration,
        assert(initialNumberOfSegments >= 1),
        super(anchor: Anchor.bottomCenter) {
    // Initialize state lists BEFORE calculating _timeAtZeroZ
    _segmentGridZ = List.filled(numberOfSegments, 1.0, growable: true);
    _segmentFallDistance = List.filled(numberOfSegments, 0.0, growable: true);
    _segmentFallVelocity = List.filled(numberOfSegments, 0.0, growable: true);
    _segmentFallDirection = List.filled(numberOfSegments, null, growable: true);

    // Pre-calculate when a segment (starting at Z=1.0) reaches Z=0
    _timeAtZeroZ = _calculateTimeAtZeroZ();

    // Initialize Z positions based on time=0 and visual spacing
    for (int i = 0; i < numberOfSegments; i++) {
      final effectiveTime = 0.0 - i * segmentTimeOffset;
      // Use the state calc, but only need Z for initialization
      final state = _calculateSegmentMovementState(effectiveTime);
      _segmentGridZ[i] = state.grid_z + i * visualSegmentSpacingZ;
      _segmentGridZ[i] = max(0.0, _segmentGridZ[i]); // Clamp initial Z
    }
  }

  final double grid_x;
  final Color color;
  final double baseSegmentSize;
  final double _finalBaseSegmentSize;
  int numberOfSegments;
  final double segmentTimeOffset;
  final double move_distance;
  final double move_duration;
  final double pauseDuration;
  final double _cycle_duration;
  final double visualSegmentSpacingZ;
  final double wobble_amplitude_y;
  final double alphaFalloff;
  final double gravity;

  // --- State ---
  late final List<double> _segmentGridZ; // Current visual Z (pinned at 0 when falling)
  late final List<double> _segmentFallDistance; // Distance fallen along fall direction
  late final List<double> _segmentFallVelocity; // Speed along fall direction
  late final List<Vector2?> _segmentFallDirection; // Normalized fall direction vector
  double _liveTime = 0.0;

  // --- Configuration ---
  final Curve _moveCurve = Curves.easeInOutCubic;
  late final double _timeAtZeroZ;
  bool _hasSpawnedSpike = false;

  // --- Rendering & Collision ---
  final Paint _segmentFillPaint = Paint();
  final Paint _segmentStrokePaint = Paint();
  final Vector2 _screenPos = Vector2.zero();
  final Vector2 _relativePos = Vector2.zero();
  final Vector2 _fallDirVec = Vector2.zero(); // Temp vector for fall direction
  late final CircleHitbox _headHitbox;
  late final int _baseFillAlpha;
  late final int _baseStrokeAlpha;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    _headHitbox = CircleHitbox(
      radius: _finalBaseSegmentSize / 2,
      anchor: Anchor.topLeft,
      collisionType: CollisionType.passive,
    );
    await add(_headHitbox);

    _segmentFillPaint.color = color.withOpacity(0.5);
    _segmentFillPaint.style = PaintingStyle.fill;
    _baseFillAlpha = _segmentFillPaint.color.alpha;
    _segmentStrokePaint.color = color;
    _segmentStrokePaint.style = PaintingStyle.stroke;
    _segmentStrokePaint.strokeWidth = 2.0;
    _baseStrokeAlpha = _segmentStrokePaint.color.alpha;

    _updatePositionAndSize();
  }

  void _updateSizeAndHitbox() {
    final headZ = _segmentGridZ[0];
    // Calculate relative scale using perspective function
    final relativeScale = perspective_scale(
          x: grid_x,
          z: headZ,
        ) /
        level.outer_scale_factor;
    // Clamp minimum scale to avoid zero or negative size
    final headScale = max(0.1, relativeScale);

    final headSegmentVisualSize = _finalBaseSegmentSize * headScale;
    size.setAll(headSegmentVisualSize);
    if (_headHitbox.isMounted) {
      _headHitbox.radius = headSegmentVisualSize / 2;
    }
  }

  void _updatePositionAndSize() {
    final headZForPosition = max(0.0, _segmentGridZ[0]);
    level.map_grid_to_screen(grid_x, headZForPosition, out: position);
    _updateSizeAndHitbox();
  }

  /// Calculates the time it takes for the base Z position (without visual offset)
  /// to reach 0.0. Uses the component's move/pause parameters.
  double _calculateTimeAtZeroZ() {
    final stepsNeeded = (1.0 / move_distance).ceil();
    double time = (stepsNeeded - 1) * _cycle_duration;
    double remainingZ = 1.0 - (stepsNeeded - 1) * move_distance;
    if (remainingZ > 1e-6) {
      // Simplified time calc for the last partial step
      time += (remainingZ / move_distance) * move_duration;
    }
    return time;
  }

  /// Calculates the movement state (gridZ, wobbleOffsetY, isPastZeroTime)
  /// for a segment based on its effective time, BEFORE visual spacing or falling.
  ({
    double grid_z,
    double wobble_offset_y,
    bool is_past_zero_time,
  }) _calculateSegmentMovementState(double effectiveTime) {
    if (effectiveTime < 0) effectiveTime = 0;

    final bool is_past_zero_time = effectiveTime >= _timeAtZeroZ;
    double current_grid_z;
    double wobble_offset_y = 0.0;

    final cycles_completed = (effectiveTime / _cycle_duration).floor();
    final time_in_cycle = effectiveTime % _cycle_duration;
    final z_at_cycle_start = 1.0 - cycles_completed * move_distance;

    if (time_in_cycle <= move_duration) {
      // Moving phase
      final z_at_move_end = z_at_cycle_start - move_distance;
      final t = (time_in_cycle / move_duration).clamp(0.0, 1.0);
      final curved_t = _moveCurve.transform(t);
      current_grid_z = lerpDouble(z_at_cycle_start, z_at_move_end, curved_t)!;
      if (!is_past_zero_time) {
        wobble_offset_y = sin(pi * t) * wobble_amplitude_y;
      }
    } else {
      // Pausing phase
      current_grid_z = z_at_cycle_start - move_distance;
    }

    final display_z = max(0.0, current_grid_z); // Visually clamp Z >= 0

    return (grid_z: display_z, wobble_offset_y: wobble_offset_y, is_past_zero_time: is_past_zero_time);
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (_segmentGridZ.isEmpty) return;

    _liveTime += dt;
    bool lastSegmentOffScreen = true;

    for (int i = 0; i < numberOfSegments; i++) {
      final effectiveTime = _liveTime - i * segmentTimeOffset;
      final state = _calculateSegmentMovementState(effectiveTime);

      // --- Spawn Spike when head reaches z=0 ---
      if (i == 0 && state.is_past_zero_time && !_hasSpawnedSpike) {
        _spawnSpike();
        _hasSpawnedSpike = true;
      }

      // --- Handle Falling State Transition and Physics ---
      if (state.is_past_zero_time) {
        if (_segmentFallDirection[i] == null) {
          // --- Start Falling ---
          _segmentGridZ[i] = 0.0;
          _segmentFallVelocity[i] = 0.0;
          _segmentFallDistance[i] = 0.0;
          level.get_depth_vector(grid_x, out: _fallDirVec);
          _fallDirVec.invert();
          _fallDirVec.normalize();
          _segmentFallDirection[i] = _fallDirVec.clone();

          // Remove hitbox if this is the last segment starting to fall
          if (i == numberOfSegments - 1) {
            if (_headHitbox.isMounted && !_headHitbox.isRemoving) {
              _headHitbox.removeFromParent();
            }
          }
        }

        // --- Continue Falling ---
        _segmentFallVelocity[i] += gravity * dt;
        _segmentFallDistance[i] += _segmentFallVelocity[i] * dt;
        _segmentGridZ[i] = 0.0; // Keep Z pinned visually
      } else {
        // --- Normal Movement ---
        _segmentGridZ[i] = state.grid_z + i * visualSegmentSpacingZ;
        _segmentGridZ[i] = max(0.0, _segmentGridZ[i]);
      }

      // --- Check if segment is off-screen (for removal check) ---
      if (_segmentFallDirection[i] != null) {
        level.map_grid_to_screen(grid_x, 0.0, out: _screenPos); // Base screen pos at Z=0
        final fallOffset = _segmentFallDirection[i]! * _segmentFallDistance[i];
        final currentScreenPos = _screenPos + fallOffset;
        // Check if within rough screen bounds + buffer
        if (currentScreenPos.y < game.size.y + baseSegmentSize * 2 &&
            currentScreenPos.y > -baseSegmentSize * 2 &&
            currentScreenPos.x < game.size.x + baseSegmentSize * 2 &&
            currentScreenPos.x > -baseSegmentSize * 2) {
          lastSegmentOffScreen = false; // This segment is still visible
        }
      } else {
        lastSegmentOffScreen = false; // Not falling yet
      }
    } // End of segment loop

    _updatePositionAndSize();

    // Remove if the *last* segment is considered off-screen
    if (lastSegmentOffScreen) {
      removeFromParent();
      return;
    }
  }

  void _spawnSpike() {
    final spike = VectorSpike(
      initial_grid_x: grid_x,
      target_grid_x: player.grid_x,
      damage: 10.0,
    );
    level.add(spike);
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    final Vector2 headAbsPos = position;

    for (int i = numberOfSegments - 1; i >= 0; i--) {
      final segmentGridZ = _segmentGridZ[i];
      final effectiveTime = _liveTime - i * segmentTimeOffset;
      // Need wobble value from state calculation for rendering non-falling segments
      final state = _calculateSegmentMovementState(effectiveTime);

      final mapZ = _segmentFallDirection[i] != null ? 0.0 : segmentGridZ;

      level.map_grid_to_screen(grid_x, mapZ, out: _screenPos);
      _relativePos.setFrom(_screenPos - headAbsPos);
      _relativePos.x += size.x / 2;
      _relativePos.y += size.y / 2;

      // Add offsets
      if (_segmentFallDirection[i] != null) {
        _relativePos.add(_segmentFallDirection[i]! * _segmentFallDistance[i]);
      } else if (i > 0) {
        _relativePos.y += state.wobble_offset_y; // Use calculated wobble
      }

      // Calculate relative scale using perspective function
      final relativeScale = perspective_scale(x: grid_x, z: segmentGridZ);
      // Clamp minimum scale
      final scale = max(0.1, relativeScale);

      final segmentVisualSize = _finalBaseSegmentSize * scale;

      final double alphaMultiplier = pow(alphaFalloff, i).toDouble();
      final int fillAlpha = (_baseFillAlpha * alphaMultiplier).round().clamp(0, 255);
      final int strokeAlpha = (_baseStrokeAlpha * alphaMultiplier).round().clamp(0, 255);

      final cf = hit_time > 0.0 ? OnHit.hit_color : _segmentFillPaint.color.withAlpha(fillAlpha);
      final cs = hit_time > 0.0 ? OnHit.hit_color : _segmentStrokePaint.color.withAlpha(strokeAlpha);
      _segmentFillPaint.color = cf;
      _segmentStrokePaint.color = cs;

      canvas.drawCircle(_relativePos.toOffset(), segmentVisualSize / 2, _segmentFillPaint);
      canvas.drawCircle(_relativePos.toOffset(), segmentVisualSize / 2, _segmentStrokePaint);

      _segmentFillPaint.color = color.withAlpha(_baseFillAlpha);
      _segmentStrokePaint.color = color.withAlpha(_baseStrokeAlpha);
    }
  }

  // --- HasFakeThreeDee Mixin Implementation ---

  @override
  double get grid_z => _segmentGridZ.isNotEmpty ? _segmentGridZ[0] : 0.0; // Use head segment Z

  // --- Hostile Mixin Implementation ---

  @override
  void on_hit(double damage, {bool score = true}) {
    if (numberOfSegments <= 0) return;

    super.on_hit(damage);

    // Remove head segment state
    _segmentGridZ.removeAt(0);
    _segmentFallDistance.removeAt(0);
    _segmentFallVelocity.removeAt(0);
    _segmentFallDirection.removeAt(0);

    // Decrement segment count
    numberOfSegments -= 1;

    // Adjust live time to simulate push back
    _liveTime -= 5 * segmentTimeOffset;
    _liveTime = max(0.0, _liveTime); // Ensure liveTime doesn't go negative

    // Check if crawler should be removed
    if (numberOfSegments <= 0) {
      log_info('Crawler at $grid_x destroyed!');
      removeFromParent();
    } else {
      // Update size/position based on the new head
      _updatePositionAndSize();
    }
  }
}
