import 'dart:ui';

import 'package:flame/components.dart';
import 'package:stardash/game/base/game_phase.dart';
import 'package:stardash/game/base/has_context.dart';
import 'package:stardash/game/level/level_color.dart';
import 'package:stardash/game/level/level_geometry.dart';
import 'package:stardash/game/level/level_path.dart';
import 'package:stardash/game/level/level_tiles.dart';
import 'package:stardash/game/level/level_transition.dart';
import 'package:stardash/util/log.dart';

extension HasContextExtensions on HasContext {
  Level get level => cache.putIfAbsent('level', () => Level());
}

class Level extends Component with HasPaint, LevelTransition {
  static const double _outer_stroke_width = 2.0;
  static const double _deep_stroke_width = 1.0;
  static const List<double> path_grid_z_levels = [0.0, 0.2, 0.4, 0.6, 0.8, 1.0];

  late int number;
  late LevelColor level_color;

  late LevelGeometry _geometry;
  late LevelGeometry? _previous;

  bool get is_closed => _geometry.is_closed;

  LevelPathType get path_type => _geometry.path_type;

  List<double> get cumulative_normalized_distances => _geometry.cumulative_normalized_distances;

  double get total_normalized_path_length => _geometry.total_normalized_path_length;

  LevelPath get path_definition => _geometry.path_definition;

  double get outer_scale_factor => _geometry.outer_scale_factor;

  double get deep_scale_factor => _geometry.deep_scale_factor;

  Level() : super(priority: -10000);

  void load_level({
    required int number,
    required LevelColor color,
    required LevelPathType path_type,
  }) {
    removeAll(children);

    this.number = number;
    this.level_color = color;

    _previous = number == 1 ? null : _geometry;
    _geometry = LevelGeometry(path_type: path_type);
    log_info('loaded level $number geometry: $_geometry previous: $_previous');

    vanishing_point.setFrom(map_grid_to_screen(0, 1.5));

    add(level_tiles = LevelTiles(level: _geometry, color: color)..effects_enabled = false);

    // Create the path lines (will be drawn on top of tiles)
    _create_all_path_lines();
    _create_connecting_line_segments();
  }

  final _lerp = Vector2.zero();

  Vector2 map_grid_to_screen(double x, double y, {Vector2? out, bool clamp_and_wrap_x = true, bool lerp = false}) {
    if (lerp && _previous != null && needs_lerp) {
      out ??= _lerp;
      
      final p = _previous!.map_grid_to_screen(x, y, clamp_and_wrap_x: clamp_and_wrap_x);
      final c = _geometry.map_grid_to_screen(x, y, clamp_and_wrap_x: clamp_and_wrap_x);
      
      // More stable lerp with proper clamping
      final safe_progress = transition_progress.clamp(0.01, 0.99);
      out.setFrom(p);
      out.lerp(c, safe_progress);
      return out;
    }
    
    // For very small progress values, just use previous geometry
    if (_previous != null && game_phase == GamePhase.entering_level && transition_progress < 0.01) {
      return _previous!.map_grid_to_screen(x, y, out: out, clamp_and_wrap_x: clamp_and_wrap_x);
    }
    
    // For very large progress values, just use current geometry
    return _geometry.map_grid_to_screen(x, y, out: out, clamp_and_wrap_x: clamp_and_wrap_x);
  }

  Vector2 get_orientation_normal(double gridX, {Vector2? out}) {
    return _geometry.get_orientation_normal(gridX, out: out);
  }

  Vector2 get_depth_vector(double gridX, {Vector2? out}) {
    return _geometry.get_depth_vector(gridX, out: out);
  }

  double find_start_x({bool lerp = false}) {
    if (lerp && _previous != null && needs_lerp) {
      final p = _previous!.find_start_x();
      final c = _geometry.find_start_x();
      final safe_progress = transition_progress.clamp(0.01, 0.99);
      return lerpDouble(p, c, safe_progress)!;
    }
    
    // For very small progress values, just use previous geometry
    if (_previous != null && game_phase == GamePhase.entering_level && transition_progress < 0.01) {
      return _previous!.find_start_x();
    }
    
    return _geometry.find_start_x();
  }

  double shortest_grid_x_delta(double fromGridX, double toGridX, {bool lerp = false}) {
    if (lerp && _previous != null && needs_lerp) {
      final p = _previous!.shortest_grid_x_delta(fromGridX, toGridX);
      final c = _geometry.shortest_grid_x_delta(fromGridX, toGridX);
      final safe_progress = transition_progress.clamp(0.01, 0.99);
      return lerpDouble(p, c, safe_progress)!;
    }
    
    // For very small progress values, just use previous geometry
    if (_previous != null && game_phase == GamePhase.entering_level && transition_progress < 0.01) {
      return _previous!.shortest_grid_x_delta(fromGridX, toGridX);
    }
    
    return _geometry.shortest_grid_x_delta(fromGridX, toGridX);
  }

  Vector2 map_grid_xyz_to_screen(double x, double y, double z, {Vector2? out, bool clamp_and_wrap_x = true}) {
    return _geometry.map_grid_xyz_to_screen(x, y, z, out: out, clamp_and_wrap_x: clamp_and_wrap_x);
  }

  void _create_all_path_lines() {
    final int num_vertices = path_definition.vertices.length;
    assert(num_vertices >= 2, "Path must have at least 2 vertices.");

    final int num_segments = is_closed ? num_vertices : num_vertices - 1;
    for (final grid_z in path_grid_z_levels) {
      // Interpolate base color and stroke width based on gridZ
      final t = grid_z;
      final base_color = Color.lerp(level_color.start_color, level_color.end_color, t)!;
      final stroke_width = lerpDouble(_outer_stroke_width, _deep_stroke_width, t)!;

      // Check if it's an inner path (excluding exact 0.0 and 1.0)
      final bool is_inner_path = grid_z > 0.0 && grid_z < 1.0;
      final Color final_color = is_inner_path ? base_color.withAlpha(base_color.alpha ~/ 2) : base_color;

      _create_path_line(grid_z, final_color, stroke_width, num_segments);
    }
  }

  void _create_path_line(double grid_z, Color color, double stroke_width, int num_segments) {
    // Ensure precomputed distances are available via the public getter
    if (cumulative_normalized_distances.isEmpty) {
      log_warn("Cannot create path line: cumulative distances not computed.");
      return;
    }

    // Iterate through the actual segments based on precomputed distances
    for (var i = 0; i < num_segments; i++) {
      // Get normalized distance at start and end of the current segment
      final double dist_start = cumulative_normalized_distances[i];
      final double dist_end = (i == num_segments - 1) ? 1.0 : cumulative_normalized_distances[i + 1];

      // Convert normalized distances [0.0, 1.0] back to gridX [-1.0, 1.0]
      final grid_x_start = dist_start * 2.0 - 1.0;
      final grid_x_end = dist_end * 2.0 - 1.0;

      // Use mapGridToScreen with the accurate gridX values and the provided gridZ.
      final start = map_grid_to_screen(grid_x_start, grid_z, clamp_and_wrap_x: false);
      final end = map_grid_to_screen(grid_x_end, grid_z, clamp_and_wrap_x: false);

      add(_PathSegment(
        shared_parent_paint: paint,
        color: color,
        stroke_width: stroke_width,
        start: start.toOffset(),
        end: end.toOffset(),
      ));
    }
  }

  void _create_connecting_line_segments() {
    const int divisions = 8;
    final num_vertices = path_definition.vertices.length;
    if (num_vertices <= 0) return;

    if (cumulative_normalized_distances.length < num_vertices) {
      log_warn("Cannot create connecting lines: cumulative distances not computed or insufficient.");
      return;
    }

    // Determine the number of connection points (vertices)
    final int num_points_to_draw = num_vertices;

    for (var i = 0; i < num_points_to_draw; i++) {
      // Get the normalized distance for the current vertex
      final double normalized_dist = cumulative_normalized_distances[i];

      // Convert normalized distance [0.0, 1.0] to gridX [-1.0, 1.0]
      final double grid_x = normalized_dist * 2.0 - 1.0;

      for (var j = 0; j < divisions; j++) {
        final grid_z_start = j / divisions;
        final grid_z_end = (j + 1) / divisions;

        // Use mapGridToScreen with the accurate gridX and the calculated gridZ.
        // Use clampAndWrapX: false as these lines are specific points in the path.
        final start = map_grid_to_screen(grid_x, grid_z_start, clamp_and_wrap_x: false);
        final end = map_grid_to_screen(grid_x, grid_z_end, clamp_and_wrap_x: false);

        final t = (j + 0.5) / divisions; // Midpoint for interpolation
        final color = Color.lerp(level_color.start_color, level_color.end_color, t)!;
        final stroke_width = lerpDouble(_outer_stroke_width, _deep_stroke_width, t)!;

        add(_PathSegment(
          shared_parent_paint: paint,
          color: color,
          stroke_width: stroke_width,
          start: start.toOffset(),
          end: end.toOffset(),
        ));
      }
    }
  }
}

class _PathSegment extends Component {
  final Paint shared_parent_paint;
  final Color color;
  final double stroke_width;
  final Offset start;
  final Offset end;

  _PathSegment({
    required this.start,
    required this.color,
    required this.stroke_width,
    required this.end,
    required this.shared_parent_paint,
  });

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    final saved = shared_parent_paint.color;
    if (saved.a < 1.0) {
      // This way we pick up global fade alpha:
      shared_parent_paint.color = color.withValues(alpha: saved.a * color.a);
    } else {
      shared_parent_paint.color = color;
    }
    shared_parent_paint.strokeWidth = stroke_width;
    canvas.drawLine(start, end, shared_parent_paint);
    shared_parent_paint.color = saved;
  }
}
