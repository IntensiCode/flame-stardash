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

class FlipperComponent extends PositionComponent
    with HasContext, HasFakeThreeDee, OnHit, Hostile {
  FlipperComponent({
    required this.start_grid_x,
    required this.start_grid_z,
    this.color = const Color(0xFF00FFAA),
    this.base_size = 24.0,
    this.move_duration = 0.7,
    this.pause_duration = 0.3,
    this.jump_height = 0.3,
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
  final double jump_height;
  double strength;

  @override
  double grid_x = 0.0;

  double _current_grid_y = 0.0;

  @override
  double get grid_y => _current_grid_y;

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
  double _rotation = 0.0;

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
    _rotation += dt * 2.0; // Rotate the cube

    if (_is_moving) {
      double elapsed = _live_time - _move_start_time;
      if (elapsed >= move_duration) {
        grid_x = target_grid_x;
        grid_z = target_grid_z;
        _current_grid_y = 0.0; // Reset height after jump
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

        // Ease in-out quad for horizontal and depth movement
        double easedT = t < 0.5 ? 2 * t * t : 1 - pow(-2 * t + 2, 2) / 2;
        grid_x = _move_start_x + (target_grid_x - _move_start_x) * easedT;
        grid_z = _move_start_z + (target_grid_z - _move_start_z) * easedT;

        // Parabolic jump arc for y-axis
        // sin(t * π) creates a 0->1->0 arc over the duration
        _current_grid_y = jump_height * sin(t * pi);

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

    // Use map_grid_xyz_to_screen to account for height (y-axis)
    level.map_grid_xyz_to_screen(grid_x, grid_y, grid_z, out: position);

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

    // Initialize previousGridX with current position
    double? previousGridX = grid_x;

    for (int i = 0; i < normalizedDistances.length - 1; i++) {
      if (currentDist >= normalizedDistances[i] &&
          currentDist < normalizedDistances[i + 1]) {
        currentVertexIndex = i;
        break;
      }
    }
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
        possibleMoves.add({'grid_x': nextGridX, 'grid_z': grid_z});
      }
    }
    if (currentVertexIndex - 1 >= 0 || level.is_closed) {
      final prevIndex = level.is_closed && currentVertexIndex - 1 < 0
          ? numVertices - 1
          : currentVertexIndex - 1;
      final prevDist = normalizedDistances[prevIndex];
      final prevGridX = prevDist * 2.0 - 1.0;
      if ((prevGridX - previousGridX).abs() > 0.01) {
        possibleMoves.add({'grid_x': prevGridX, 'grid_z': grid_z});
      }
    }

    // Check adjacent z-levels - Flipper can jump multiple z-levels at once
    if (currentZIndex > 0) {
      // Can jump to any lower z-level
      for (int i = 0; i < currentZIndex; i++) {
        possibleMoves.add({'grid_x': grid_x, 'grid_z': zLevels[i]});
      }
    }
    if (currentZIndex < zLevels.length - 1) {
      // Can jump to any higher z-level
      for (int i = currentZIndex + 1; i < zLevels.length; i++) {
        possibleMoves.add({'grid_x': grid_x, 'grid_z': zLevels[i]});
      }
    }

    if (possibleMoves.isNotEmpty) {
      final randomMove = possibleMoves[Random().nextInt(possibleMoves.length)];
      target_grid_x = randomMove['grid_x']!;
      target_grid_z = randomMove['grid_z']!;
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
          'Flipper: No possible moves found at grid_x: $grid_x, grid_z: $grid_z');
      previousGridX = null; // Clear previous position if no moves are possible
    }
  }

  void _moveTowardsPlayer() {
    if (grid_z > 0.0) {
      target_grid_z = 0.0; // Flipper can jump directly to z=0
      _move_start_x = grid_x;
      _move_start_z = grid_z;
      _move_start_time = _live_time;
      _is_moving = true;
    } else {
      final deltaX = level.shortest_grid_x_delta(grid_x, player.grid_x);
      if (deltaX.abs() > 0.01) {
        final moveDirection = deltaX.sign;
        target_grid_x =
            grid_x + moveDirection * 0.2; // Move faster towards player
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

    if (hit_time > 0) {
      _fill_paint.color = OnHit.hit_color;
      _stroke_paint.color = OnHit.hit_color;
    } else {
      _fill_paint.color = color.withAlpha(178);
      _stroke_paint.color = color;
    }

    // Draw a rotating cube
    final halfSize = size.x / 2;
    final cubeSize = size.x * 0.8; // Slightly smaller than the hitbox

    canvas.save();
    canvas.translate(halfSize, halfSize);
    canvas.rotate(_rotation);

    // Calculate cube vertices
    final vertices = _calculateCubeVertices(cubeSize);

    // Draw cube faces
    _drawCubeFaces(canvas, vertices);

    // Draw cube edges
    _drawCubeEdges(canvas, vertices);

    canvas.restore();
  }

  List<Offset> _calculateCubeVertices(double size) {
    final halfSize = size / 2;

    // Cube vertices in isometric view (standing on one corner)
    return [
      Offset(0, -halfSize * 1.2), // Top vertex
      Offset(halfSize, 0), // Right vertex
      Offset(0, halfSize * 1.2), // Bottom vertex
      Offset(-halfSize, 0), // Left vertex
      Offset(0, 0), // Center (for drawing faces)
    ];
  }

  void _drawCubeFaces(Canvas canvas, List<Offset> vertices) {
    // Draw the visible cube faces
    final path = Path();

    // Top face
    path.moveTo(vertices[0].dx, vertices[0].dy);
    path.lineTo(vertices[1].dx, vertices[1].dy);
    path.lineTo(vertices[4].dx, vertices[4].dy);
    path.close();
    canvas.drawPath(path, _fill_paint);

    // Right face
    path.reset();
    path.moveTo(vertices[1].dx, vertices[1].dy);
    path.lineTo(vertices[2].dx, vertices[2].dy);
    path.lineTo(vertices[4].dx, vertices[4].dy);
    path.close();
    canvas.drawPath(path, _fill_paint);

    // Left face
    path.reset();
    path.moveTo(vertices[0].dx, vertices[0].dy);
    path.lineTo(vertices[3].dx, vertices[3].dy);
    path.lineTo(vertices[4].dx, vertices[4].dy);
    path.close();
    canvas.drawPath(path, _fill_paint);
  }

  void _drawCubeEdges(Canvas canvas, List<Offset> vertices) {
    // Draw the cube edges
    final path = Path();

    // Connect all outer vertices to form the cube outline
    path.moveTo(vertices[0].dx, vertices[0].dy);
    path.lineTo(vertices[1].dx, vertices[1].dy);
    path.lineTo(vertices[2].dx, vertices[2].dy);
    path.lineTo(vertices[3].dx, vertices[3].dy);
    path.close();

    // Draw edges to center
    for (int i = 0; i < 4; i++) {
      path.moveTo(vertices[i].dx, vertices[i].dy);
      path.lineTo(vertices[4].dx, vertices[4].dy);
    }

    canvas.drawPath(path, _stroke_paint);
  }

  @override
  void on_hit(double damage) {
    super.on_hit(damage);
    strength -= damage;

    if (strength <= 0) removeFromParent();
  }
}
