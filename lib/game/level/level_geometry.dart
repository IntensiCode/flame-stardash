import 'dart:math';

import 'package:flame/components.dart';
import 'package:stardash/core/common.dart';
import 'package:stardash/game/base/fake_three_d.dart';
import 'package:stardash/game/level/level_data.dart';
import 'package:stardash/game/level/level_path.dart';
import 'package:stardash/util/log.dart';

mixin LevelGeometry {
  LevelData get data;

  late bool is_closed;
  late LevelPath path;
  late double min_dimension;
  late double base_scale;

  late double outer_scale_factor;
  late double deep_scale_factor;
  late List<double> grid_points;
  late List<double> snap_points;

  final center = Vector2.zero();

  final _normalized_segment_lengths = <double>[];
  final cumulative_normalized_distances = <double>[];
  var total_normalized_path_length = 0.0;

  final _normalized_point = Vector2.zero();
  final _va = Vector2.zero();
  final _vb = Vector2.zero();

  final _v1 = Vector2.zero();
  final _v2 = Vector2.zero();
  final _tangent = Vector2.zero();

  void init_geometry() {
    this.path = data.path;
    this.is_closed = data.closed;
    _compute_path_data();
    _compute_grid_points();
    _compute_snap_points();
  }

  @override
  String toString() => 'LevelGeometry($data)';

  void _compute_grid_points() {
    final result = <double>[];
    final distances = cumulative_normalized_distances;
    final n = distances.length;
    for (int i = 0; i < n; i++) {
      result.add(distances[i] * 2 - 1);
    }
    grid_points = result;
  }

  /// Returns a list of grid_x values corresponding to the midpoints between each pair of consecutive vertices.
  void _compute_snap_points() {
    final mids = <double>[];
    final distances = cumulative_normalized_distances;
    final n = distances.length;
    for (int i = 0; i < n - 1; i++) {
      final mid = (distances[i] + distances[i + 1]) / 2.0;
      mids.add(mid * 2.0 - 1.0);
    }
    snap_points = mids;
  }

  void _compute_path_data() {
    // --- Calculate and Store Scaling Parameters ---
    min_dimension = min(game_width, game_height);
    base_scale = (min_dimension * 0.9) / 2.0;
    // path_scale = path_type.scale;
    // path_translate = path_type.translate;
    is_closed = data.closed;
    outer_scale_factor = base_scale;
    deep_scale_factor = base_scale / 4.0;
    center.setFrom(game_center);

    // --- Precompute Path Lengths ---
    _precompute_path_lengths();
  }

  void _precompute_path_lengths() {
    _normalized_segment_lengths.clear();
    cumulative_normalized_distances.clear();
    total_normalized_path_length = 0;

    final vertices = path.vertices;
    final num_vertices = vertices.length;

    cumulative_normalized_distances.add(0.0); // Start at distance 0

    for (var i = 0; i < num_vertices - 1; i++) {
      final segment_length = vertices[i].distanceTo(vertices[i + 1]);
      _normalized_segment_lengths.add(segment_length);
      total_normalized_path_length += segment_length;
    }

    // Add closing segment length if path is closed and has vertices
    if (is_closed && num_vertices > 0) {
      final closing_segment_length = vertices[num_vertices - 1].distanceTo(vertices[0]);
      _normalized_segment_lengths.add(closing_segment_length);
      total_normalized_path_length += closing_segment_length;
    }

    if (total_normalized_path_length < 1e-6) {
      // Avoid division by zero if path has zero length
      log_warn('Total normalized path length is near zero!');
      // Fill cumulative distances with 0 to avoid errors later
      cumulative_normalized_distances.clear();
      cumulative_normalized_distances.add(0.0);
      for (var i = 0; i < _normalized_segment_lengths.length; i++) {
        cumulative_normalized_distances.add(0.0);
      }
      return;
    }

    double current_cumulative = 0;
    for (var i = 0; i < _normalized_segment_lengths.length; i++) {
      current_cumulative += _normalized_segment_lengths[i];
      cumulative_normalized_distances.add(current_cumulative / total_normalized_path_length);
    }
    cumulative_normalized_distances[cumulative_normalized_distances.length - 1] = 1.0;
  }

  // --- Path Position Calculation ---

  /// Finds the segment index and the normalized distance at the start of that segment
  /// based on the target normalized distance along the entire path.
  (int segment_index, double distance_at_start) _find_segment_index_and_start_distance(double target_distance) {
    final num_segments = _normalized_segment_lengths.length;
    int segment_index;
    double distance_at_start;

    if (target_distance <= 0.0) {
      segment_index = 0;
      distance_at_start = 0.0;
    } else if (target_distance >= 1.0) {
      // If closed, target >= 1 wraps to start of segment 0
      // If open, target >= 1 clamps to end of last segment
      segment_index = is_closed ? 0 : num_segments - 1;
      distance_at_start = is_closed ? 0.0 : cumulative_normalized_distances[segment_index];
    } else {
      // Find the segment containing the targetDistance
      segment_index = cumulative_normalized_distances.indexWhere((d) => d >= target_distance);
      // indexWhere returns the index of the *first* element >= target.
      // We want the index of the segment *before* that one.
      segment_index = (segment_index <= 0) ? 0 : segment_index - 1;
      distance_at_start = cumulative_normalized_distances[segment_index];
    }
    // Final safety clamp on index before returning
    segment_index = segment_index.clamp(0, num_segments - 1);
    return (segment_index, distance_at_start);
  }

  /// Calculates the point in normalized path space based on gridX.
  /// Handles clamping/wrapping or extrapolation.
  Vector2 _get_normalized_point_on_path(double grid_x, bool clamp_and_wrap, {Vector2? out}) {
    out ??= Vector2.zero();

    final vertices = path.vertices;
    final num_segments = _normalized_segment_lengths.length;
    assert(num_segments > 0, 'Path must have at least one segment');

    double effective_grid_x = grid_x;

    // Always wrap gridX if the path is closed, regardless of clampAndWrap flag
    if (is_closed) {
      while (effective_grid_x > 1.0) effective_grid_x -= 2.0;
      while (effective_grid_x < -1.0) effective_grid_x += 2.0;
    }

    // Only clamp gridX for open paths when requested
    if (clamp_and_wrap && !is_closed) {
      effective_grid_x = effective_grid_x.clamp(-1.0, 1.0);
    }

    // potentially outside [0, 1] for open paths if clampAndWrap is false.
    final target_distance_raw = (effective_grid_x + 1.0) / 2.0;

    // Handle wrap-around for closed paths *before* finding segment/calculating tX
    // If closed and raw distance is >= 1.0, treat it as 0.0 for segment/tX calculation.
    final double target_distance = (is_closed && target_distance_raw >= 1.0) ? 0.0 : target_distance_raw;

    // Use the helper function with the potentially adjusted targetDistance
    final (segment_index, distance_at_segment_start) = _find_segment_index_and_start_distance(target_distance);

    // Calculate interpolation factor tX (using adjusted targetDistance)
    final distance_into_segment = target_distance - distance_at_segment_start;
    // Avoid division by zero for zero-length segments
    final segment_normalized_length = _normalized_segment_lengths[segment_index] / total_normalized_path_length;
    double t_x = (segment_normalized_length < 1e-9) ? 0.0 : (distance_into_segment / segment_normalized_length);

    // Clamp tX ONLY if clamping was requested AND the path is open.
    // If path is closed (wrapped) or clampAndWrap is false (extrapolating), tX should not be clamped.
    if (clamp_and_wrap && !is_closed) {
      t_x = t_x.clamp(0.0, 1.0);
    }

    // Get vertices for the segment
    _va.setFrom(vertices[segment_index]);
    _vb.setFrom((segment_index == vertices.length - 1 && is_closed)
        ? vertices[0] // Wrap to start for closing segment
        : vertices[segment_index + 1]);

    // Interpolate/Extrapolate using tX
    out.setFrom(_vb);
    out.sub(_va);
    out.scale(t_x);
    out.add(_va);
    return out;
  }

  // --- Screen Mapping ---

  Vector2 map_grid_to_screen(
    double grid_x,
    double grid_z, {
    Vector2? out,
    bool clamp_and_wrap_x = true,
  }) {
    // 1. Get the point on the normalized path [-1..1] x/y space
    _get_normalized_point_on_path(grid_x, clamp_and_wrap_x, out: _normalized_point);
    final double x = _normalized_point.x;
    final double y = -_normalized_point.y;
    return FakeThreeDee.project(x: x, y: y, z: grid_z, out: out);
  }

  // --- Vector Calculation Methods (Moved from LevelVectorExtensions) ---

  /// Calculates the *normalized* vector pointing from the outer edge towards the deep edge
  /// at the given normalized path position `grid_x`.
  Vector2 get_depth_vector(double grid_x, {Vector2? out}) {
    out ??= Vector2.zero();
    map_grid_to_screen(grid_x, 1.0, out: _v1);
    map_grid_to_screen(grid_x, 0.0, out: _v2);
    out.setFrom(_v1);
    out.sub(_v2);
    if (out.length2 < 1e-12) {
      out.x = 0;
      out.y = 1;
    }
    assert(out.length2 > 1e-12, 'Depth vector length is zero or negative');
    out.normalize();
    return out;
  }

  /// Calculates the normalized surface normal vector on the outer path (gridZ=0)
  /// at the given normalized path position `grid_x`.
  /// The normal points "outwards" from the path curvature.
  /// NOTE: Reverted to original tangent-based calculation.
  Vector2 get_orientation_normal(double grid_x, {Vector2? out}) {
    out ??= Vector2.zero();
    out.setZero();

    // --- Original Tangent-based calculation ---
    const double epsilon = 0.01;
    // Access isClosed directly from the mixin field
    double grid_x_plus = grid_x + epsilon;
    double grid_x_minus = grid_x - epsilon;
    if (is_closed) {
      if (grid_x_plus > 1.0) grid_x_plus = -1.0 + (grid_x_plus - 1.0);
      if (grid_x_minus < -1.0) grid_x_minus = 1.0 + (grid_x_minus + 1.0);
    } else {
      grid_x_plus = grid_x_plus.clamp(-1.0, 1.0);
      grid_x_minus = grid_x_minus.clamp(-1.0, 1.0);
    }
    map_grid_to_screen(grid_x_plus, 0.0, out: _v1);
    map_grid_to_screen(grid_x_minus, 0.0, out: _v2);
    _tangent.setFrom(_v1);
    _tangent.sub(_v2);

    // assert(_tangent.length2 >= 1e-6, 'Tangent length is near zero');
    if (_tangent.length2 < 1e-6) {
      log_warn('Tangent is near zero ');
      // Fallback: Use depth vector rotated -90 deg if tangent is zero
      get_depth_vector(grid_x, out: _v1);
      out.x = _v1.y;
      out.y = -_v1.x;
      out.normalize();
      return out;
    }
    // Calculate normal by rotating tangent -90 degrees (Clockwise) -> Screen Up
    out.x = _tangent.y;
    out.y = -_tangent.x;
    out.normalize();
    return out;
  }

  /// Calculates the shortest delta GridX needed to move from [from_grid_x]
  /// to [to_grid_x], accounting for path wrapping if [is_closed].
  /// Result is in the range [-1.0, 1.0].
  double shortest_grid_x_delta(double from_grid_x, double to_grid_x) {
    if (!is_closed) {
      // No wrapping, just return the direct difference
      return (to_grid_x - from_grid_x).clamp(-1.0, 1.0);
    }

    // Handle wrapping for closed paths
    double delta = to_grid_x - from_grid_x;

    // Check wrap-around distances
    // Path range is 2.0 (-1.0 to 1.0)
    double delta_wrap_positive = delta - 2.0; // e.g., from 0.9 to -0.9, delta=-1.8, wrap=0.2
    double delta_wrap_negative = delta + 2.0; // e.g., from -0.9 to 0.9, delta=1.8, wrap=-0.2

    // Return the delta with the smallest absolute value
    if (delta.abs() <= delta_wrap_positive.abs() && delta.abs() <= delta_wrap_negative.abs()) {
      return delta;
    } else if (delta_wrap_positive.abs() < delta_wrap_negative.abs()) {
      return delta_wrap_positive;
    } else {
      return delta_wrap_negative;
    }
  }

  /// Finds the starting gridX that places the player horizontally centered on the screen.
  /// Checks gridX=0 first, otherwise finds the segment crossing the center and returns its midpoint gridX.
  double find_start_x() {
    final double target_x = center.x; // Use stored center
    const double epsilon = 1.0; // Pixel tolerance for center check

    // 1. Check default gridX = 0.0 (normalized 0.5)
    final default_pos = map_grid_to_screen(0.0, 0.0);
    if ((default_pos.x - target_x).abs() < epsilon) {
      return 0.0;
    }

    // Special case: for closed FullPipe, start at bottom center (grid_x=1.0)
    if (is_closed) {
      if (data == LevelData.heart) return -0.055;
      if (data == LevelData.star) return -0.04;
      if (data == LevelData.square) return 0.045;
      if (data == LevelData.pipe) return -0.06;
      if (data == LevelData.cross) return -0.045;
      if (data == LevelData.torx) return -0.07;
      if (data == LevelData.eight) return -0.04;
      if (data == LevelData.x) return -0.04;
    }

    return 0;
  }
}
