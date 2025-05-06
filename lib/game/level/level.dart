import 'dart:math';
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:stardash/core/common.dart';
import 'package:stardash/game/base/fake_three_d.dart';
import 'package:stardash/game/base/has_context.dart';
import 'package:stardash/game/level/level_color.dart';
import 'package:stardash/game/level/level_data.dart';
import 'package:stardash/game/level/level_geometry.dart';
import 'package:stardash/game/level/level_tile.dart';
import 'package:stardash/game/level/level_tiles.dart';
import 'package:stardash/game/level/level_transition.dart';
import 'package:stardash/game/levels.dart';
import 'package:stardash/util/log.dart';

extension HasContextExtensions on HasContext {
  Level get level => cache.putIfAbsent('level', () => Level());
}

class Level extends PositionComponent with HasPaint, LevelGeometry {
  static const List<double> path_grid_z_levels = [
    0.0,
    1.0 / 8.0,
    2.0 / 8.0,
    3.0 / 8.0,
    4.0 / 8.0,
    5.0 / 8.0,
    6.0 / 8.0,
    7.0 / 8.0,
    1.0
  ];

  late LevelConfig config;

  int get number => config.number;

  int get cycle => config.cycle;

  LevelColor get color => config.color;

  @override
  LevelData get data => config.data;

  LevelTiles? level_tiles;

  Level() : super(size: game_size);

  void load_level(LevelConfig config) {
    if (level_tiles != null) parent?.remove(level_tiles!);

    this.config = config;

    level_rng = Random(number);
    log_verbose('Activating ${data.camera}');
    FakeThreeDee.camera = data.camera;

    init_geometry();

    log_debug('Loaded level $number: $data');

    parent?.add(level_tiles = LevelTiles(level: this, color: color)..effects_enabled = false);
  }

  (bool, int, double) is_close_to_z_level(double grid_z, {double delta = 0.01}) {
    for (int i = 0; i < path_grid_z_levels.length; i++) {
      final z_level = path_grid_z_levels[i];
      if ((grid_z - z_level).abs() < delta) {
        return (true, i, z_level);
      }
    }
    return (false, -1, 0.0);
  }

  /// Returns the LevelTile at the given grid_x, grid_z, or null if not found.
  (LevelTile?, int?, int?) tile_at_grid(double grid_x, double grid_z) {
    final tiles = level_tiles;
    if (tiles == null) return (null, null, null);
    return tiles.tile_at_grid(grid_x, grid_z);
  }

  bool is_electrified(double grid_x) {
    final (idx, _) = find_snap_index(grid_x);
    return level_tiles?.is_electrified(idx) == true;
  }

  void electrify(double grid_x, double duration) {
    final x = find_snap_index(grid_x).$1;
    level_tiles?.electrify(x, duration);
  }

  bool is_tile_spiked(double grid_x, double grid_z) {
    final (tile, _, _) = tile_at_grid(grid_x, grid_z - LevelTransition.translation_z);
    return tile != null && tile.spikedness > 0;
  }

  /// Spikes the tile at the given grid_x, grid_z by setting spikedness (0..1) based on how deep grid_z is in the tile.
  void spike_tile(double grid_x, double grid_z) {
    final (tile, x_idx, z_idx) = tile_at_grid(grid_x, grid_z);
    if (tile == null) return;
    if (x_idx == null) return;
    if (z_idx == null) return;

    final z_levels = Level.path_grid_z_levels;
    final start = z_levels[z_idx];
    final end = z_levels[z_idx + 1];
    final t = 1 - ((grid_z - start) / (end - start)).clamp(0.0, 1.0);
    if (t <= tile.spikedness) return;

    tile.spikedness = t;
    tile.is_spike_tip = true;

    tile.previous?.spikedness = 1.0;
    tile.previous?.is_spike_tip = false;
  }

  /// Updates spike tip when a spike is hit and reduced
  void handle_spike_hit(int x_idx, int z_idx) {
    if (level_tiles == null) return;

    final z_levels = Level.path_grid_z_levels;
    var current_tile = level_tiles?.tile_at(x_idx, z_idx);

    if (current_tile == null || !current_tile.is_spike_tip) return;

    // If spikedness is now zero or reduced significantly
    if (current_tile.spikedness <= 0.0) {
      // Remove spike tip status from current tile
      current_tile.is_spike_tip = false;

      // Move the tip to the previous tile (closer to the player) if it exists
      if (z_idx < z_levels.length - 2) {
        // Check against the tile levels
        var previous_tile = level_tiles?.tile_at(x_idx, z_idx + 1);
        if (previous_tile != null) {
          previous_tile.is_spike_tip = true;
          previous_tile.spikedness = 1.0; // Make sure it's properly spiked

          // Ensure the next tile (further from the player) is not a tip
          if (z_idx > 0) {
            var next_tile = level_tiles?.tile_at(x_idx, z_idx - 1);
            if (next_tile != null) {
              next_tile.is_spike_tip = false;
            }
          }
        }
      }
    }
  }

  /// Finds the index of the snap point closest to the given grid_x.
  int find_closest_snap_index(double grid_x) {
    // Find current lane index
    int result = 0;
    double min_dist = double.infinity;
    for (int i = 0; i < snap_points.length; i++) {
      final d = (snap_points[i] - grid_x).abs();
      if (d < min_dist) {
        min_dist = d;
        result = i;
      }
    }
    return result;
  }

  /// Calculates a target snap index by applying delta_steps to the index
  /// closest to grid_x, handling wrapping or clamping based on level type.
  /// Returns -1 if snap_points is empty.
  (int, double) find_snap_index(double grid_x, {int delta = 0, bool clamp = true}) {
    final sp = snap_points;
    final it = find_closest_snap_index(grid_x) + delta;
    if (is_closed) {
      final idx = (it + sp.length) % sp.length;
      return (idx, sp[idx]);
    } else if (clamp) {
      final idx = it.clamp(0, sp.length - 1);
      return (idx, sp[idx]);
    } else if (it >= 0 && it < sp.length) {
      return (it, sp[it]);
    } else {
      return (-1, 0.0);
    }
  }

  /// Checks if a lane at the given index has any spikes
  bool is_lane_spiked(int lane_idx) {
    if (lane_idx < 0 || lane_idx >= snap_points.length) return false;

    final grid_x = snap_points[lane_idx];
    const grid_z = 0.15; // Same z-level used by VoxelSpiker in approaching state

    final (tile, _, _) = tile_at_grid(grid_x, grid_z);
    return tile != null && tile.spikedness > 0;
  }

  /// Finds non-spiked lanes around the current position
  /// Returns a tuple with (left_free, right_free, current_idx)
  (bool, bool, int) find_free_lanes_around(double grid_x) {
    final current_idx = find_snap_index(grid_x).$1;

    final left_idx = is_closed
        ? (current_idx - 1 + snap_points.length) % snap_points.length
        : (current_idx - 1).clamp(0, snap_points.length - 1);

    final right_idx =
        is_closed ? (current_idx + 1) % snap_points.length : (current_idx + 1).clamp(0, snap_points.length - 1);

    final left_free = !is_lane_spiked(left_idx);
    final right_free = !is_lane_spiked(right_idx);

    return (left_free, right_free, current_idx);
  }

  double snap_to_grid(double grid_x, {bool snap_points_too = true}) {
    double min_dist = double.infinity;
    double result = grid_x;

    if (snap_points_too) {
      for (final x in snap_points) {
        final d = (x - grid_x).abs();
        if (d < min_dist) {
          min_dist = d;
          result = x;
        }
      }
    }

    for (final v in grid_points) {
      final d = (v - grid_x).abs();
      if (d < min_dist) {
        min_dist = d;
        result = v;
      }
    }

    return result;
  }

  /// Normalizes a grid_x value to the [-1, 1] range, wrapping if the level is closed.
  /// Assumes the level's path spans the range [-1, 1] (total width 2.0).
  double normalize_grid_x(double grid_x) {
    if (!is_closed) {
      return grid_x.clamp(-1.0, 1.0); // Clamp for open levels
    }

    // Wrap for closed levels
    const double range_span = 2.0;
    if (grid_x > 1.0) {
      // Example: 1.1 -> 1.1 - 2.0 = -0.9
      return grid_x - range_span * ((grid_x - 1.0) / range_span).ceil();
    } else if (grid_x < -1.0) {
      // Example: -1.2 -> -1.2 + 2.0 = 0.8
      return grid_x + range_span * ((-1.0 - grid_x) / range_span).ceil();
    } else {
      return grid_x; // Already within range
    }
  }

  /// Interpolates between two grid_x values, handling wrapping for closed levels.
  /// The interpolation time 't' should be in the range [0.0, 1.0].
  double interpolate_grid_x(double start_x, double target_x, double t) {
    if (!is_closed) {
      // Simple linear interpolation for open levels
      return lerpDouble(start_x, target_x, t)!;
    }

    // For closed levels, interpolate along the shortest path
    final delta_x = shortest_grid_x_delta(start_x, target_x);
    final effective_target_x = start_x + delta_x;

    // Interpolate towards the potentially wrapped target
    final interpolated_x = lerpDouble(start_x, effective_target_x, t)!;

    // Normalize the result back into the [-1, 1] range
    return normalize_grid_x(interpolated_x);
  }
}
