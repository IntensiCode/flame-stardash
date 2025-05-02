import 'dart:math';
import 'dart:ui';

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:stardash/game/base/fake_three_d.dart';
import 'package:stardash/game/base/has_context.dart';
import 'package:stardash/game/base/kinds.dart';
import 'package:stardash/game/level/level.dart';
import 'package:stardash/game/player/player.dart';
import 'package:stardash/util/log.dart';

class SkimmerComponent extends PositionComponent
    with HasContext, HasFakeThreeDee, OnHit, Hostile {
  //
  SkimmerComponent({
    required this.start_grid_x,
    required this.start_grid_z,
    this.color = const Color(0xFFFFA500),
    this.base_size = 24.0,
    this.move_duration = 0.5,
    this.pause_duration = 0.25,
    this.strength = 5,
  }) : super(anchor: Anchor.center) {
    grid_x = start_grid_x;
    grid_z = start_grid_z;
    target_grid_x = grid_x;
    target_grid_z = grid_z;
  }

  final double start_grid_x;
  final double start_grid_z;
  final Color color;
  final double base_size;
  final double move_duration;
  final double pause_duration;
  double strength;

  @override
  double grid_x = 0.0;

  @override
  double get grid_y => 0.0;

  @override
  double grid_z = 0.0;

  double target_grid_x = 0.0;
  double target_grid_z = 0.0;
  double _current_scale = 0.5;
  double _live_time = 0.0;
  double _move_start_time = 0.0;
  double _move_start_x = 0.0;
  double _move_start_z = 0.0;
  bool _is_moving = false;

  final Paint _fill_paint = Paint();
  final Paint _stroke_paint = Paint();
  late final CircleHitbox _hitbox;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    _hitbox = CircleHitbox(
      radius: base_size / 2,
      anchor: Anchor.center,
      collisionType: CollisionType.passive,
    );
    await add(_hitbox);

    _fill_paint.color = color.withAlpha(178);
    _fill_paint.style = PaintingStyle.fill;
    _stroke_paint.color = color;
    _stroke_paint.style = PaintingStyle.stroke;
    _stroke_paint.strokeWidth = 2.0;

    _updatePositionAndSize();
  }

  @override
  void update(double dt) {
    super.update(dt);
    _live_time += dt;

    if (_is_moving) {
      double elapsed = _live_time - _move_start_time;
      if (elapsed >= move_duration) {
        grid_x = target_grid_x;
        grid_z = target_grid_z;
        _is_moving = false;
        _move_start_time = _live_time;
        _updatePositionAndSize();
        if (grid_z <= 0.0) {
          _moveTowardsPlayer();
        } else {
          _chooseNextVertex();
        }
      } else {
        double t = (elapsed / move_duration).clamp(0.0, 1.0);
        double easedT = t < 0.5
            ? 2 * t * t
            : 1 - pow(-2 * t + 2, 2) / 2; // Ease in-out quad
        grid_x = _move_start_x + (target_grid_x - _move_start_x) * easedT;
        grid_z = _move_start_z + (target_grid_z - _move_start_z) * easedT;
        _updatePositionAndSize();
      }
    } else {
      if (_live_time - _move_start_time >= pause_duration) {
        if (grid_z <= 0.0) {
          _moveTowardsPlayer();
        } else {
          _chooseNextVertex();
        }
      }
    }
  }

  void _updatePositionAndSize() {
    _current_scale = (1.0 - 0.7 * grid_z).clamp(0.1, 1.5);
    size.setAll(base_size * _current_scale);
    level.map_grid_to_screen(grid_x, grid_z, out: position);
    priority = (grid_z * -1000).round();
    if (_hitbox.isMounted) {
      _hitbox.radius = size.x / 2;
    }
  }

  void _chooseNextVertex() {
    final possibleMoves = <Map<String, double>>[];
    final zLevels = Level.path_grid_z_levels;
    final currentZIndex = zLevels.indexWhere((z) => (z - grid_z).abs() < 0.01);
    final vertices = level.path_definition.vertices;
    final numVertices = vertices.length;
    final normalizedDistances = level.cumulative_normalized_distances;
    final currentDist = (grid_x + 1.0) / 2.0;
    int currentVertexIndex = 0;

    // Initialize previousGridX here
    double? previousGridX = grid_x; // Track current position initially

    for (int i = 0; i < normalizedDistances.length - 1; i++) {
      if (currentDist >= normalizedDistances[i] &&
          currentDist < normalizedDistances[i + 1]) {
        currentVertexIndex = i;
        break;
      }
    }
    // Rest of the method remains the same...

    if (currentDist >= normalizedDistances.last) {
      currentVertexIndex = level.is_closed ? 0 : normalizedDistances.length - 2;
    }

    // // Track previous position to avoid moving back
    // double? previousGridX;

    // Check adjacent vertices along x-axis
    if (currentVertexIndex + 1 < numVertices || level.is_closed) {
      final nextIndex = level.is_closed && currentVertexIndex + 1 == numVertices
          ? 0
          : currentVertexIndex + 1;
      final nextDist = normalizedDistances[nextIndex];
      final nextGridX = nextDist * 2.0 - 1.0;
      if ((nextGridX - previousGridX).abs() > 0.01) {
        possibleMoves.add({'grid_x': nextGridX, 'gridZ': grid_z});
      }
    }
    if (currentVertexIndex - 1 >= 0 || level.is_closed) {
      final prevIndex = level.is_closed && currentVertexIndex - 1 < 0
          ? numVertices - 1
          : currentVertexIndex - 1;
      final prevDist = normalizedDistances[prevIndex];
      final prevGridX = prevDist * 2.0 - 1.0;
      if ((prevGridX - previousGridX).abs() > 0.01) {
        possibleMoves.add({'grid_x': prevGridX, 'gridZ': grid_z});
      }
    }

    // Check adjacent z-levels
    if (currentZIndex > 0) {
      final lowerZ = zLevels[currentZIndex - 1];
      possibleMoves.add({'grid_x': grid_x, 'gridZ': lowerZ});
    }
    if (currentZIndex < zLevels.length - 1) {
      final higherZ = zLevels[currentZIndex + 1];
      possibleMoves.add({'grid_x': grid_x, 'gridZ': higherZ});
    }

    if (possibleMoves.isNotEmpty) {
      final randomMove = possibleMoves[Random().nextInt(possibleMoves.length)];
      target_grid_x = randomMove['grid_x']!;
      target_grid_z = randomMove['gridZ']!;
      if ((target_grid_x - grid_x).abs() > 0.01 ||
          (target_grid_z - grid_z).abs() > 0.01) {
        previousGridX = grid_x;
        _move_start_x = grid_x;
        _move_start_z = grid_z;
        _move_start_time = _live_time;
        _is_moving = true;
      }
    } else {
      log_warn(
          'Skimmer: No possible moves found at grid_x: $grid_x, gridZ: $grid_z');
      previousGridX = null; // Clear previous position if no moves are possible
    }
  }

  void _moveTowardsPlayer() {
    if (grid_z > 0.0) {
      target_grid_z =
          grid_z - Level.path_grid_z_levels[1] + Level.path_grid_z_levels[0];
      if (target_grid_z < 0.0) target_grid_z = 0.0;
      _move_start_x = grid_x;
      _move_start_z = grid_z;
      _move_start_time = _live_time;
      _is_moving = true;
    } else {
      final deltaX = level.shortest_grid_x_delta(grid_x, player.grid_x);
      if (deltaX.abs() > 0.01) {
        final moveDirection = deltaX.sign;
        target_grid_x = grid_x + moveDirection * 0.1;
        if (level.is_closed) {
          if (target_grid_x > 1.0) target_grid_x -= 2.0;
          if (target_grid_x < -1.0) target_grid_x += 2.0;
        } else {
          target_grid_x = target_grid_x.clamp(-1.0, 1.0);
        }
        target_grid_z = grid_z;
        _move_start_x = grid_x;
        _move_start_z = grid_z;
        _move_start_time = _live_time;
        _is_moving = true;
      }
    }
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    final radius = size.x / 2;
    if (hit_time > 0) {
      _fill_paint.color = OnHit.hit_color;
      _stroke_paint.color = OnHit.hit_color;
    } else {
      _fill_paint.color = color.withValues(alpha: 0.7);
      _stroke_paint.color = color;
    }
    canvas.drawCircle(Offset(radius, radius), radius, _fill_paint);
    canvas.drawCircle(Offset(radius, radius), radius, _stroke_paint);
  }

  // --- Hostile Mixin Implementation ---
  @override
  void on_hit(double damage) {
    super.on_hit(damage);
    strength -= damage;

    // TODO: Add particle effects or scoring later
    if (strength <= 0) removeFromParent();
  }
}
