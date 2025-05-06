import 'dart:ui';

import 'package:flame/components.dart';
import 'package:stardash/game/base/fake_three_d.dart';
import 'package:stardash/game/base/game_phase.dart';
import 'package:stardash/game/base/has_context.dart';
import 'package:stardash/game/level/level.dart';
import 'package:stardash/game/level/level_color.dart';
import 'package:stardash/game/level/level_geometry.dart';
import 'package:stardash/game/level/level_tile.dart';
import 'package:stardash/game/level/level_tiles_zap.dart';
import 'package:stardash/game/level/level_transition.dart';
import 'package:stardash/game/player/player.dart';

class LevelTiles extends PositionComponent with HasContext, FakeThreeDee, LevelTransition, LevelTilesZap {
  final LevelGeometry _level;
  final LevelColor _color;

  // Store the last segment(s) the player was in
  (int, int?) _last_player_segment_indices = (-1, null);

  // Pulse timing
  double _pulse_timer = 0.0;
  static const double _pulse_interval = 1.0; // seconds

  // Flag to enable/disable flashing/pulsing effects
  bool effects_enabled = false;

  LevelTiles({required LevelGeometry level, required LevelColor color})
      : _level = level,
        _color = color;

  @override
  void update_transition(GamePhase phase, double progress) {
    super.update_transition(phase, progress);
    effects_enabled = phase == GamePhase.playing_level;
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    _generate_tiles();
    // Get initial player segment indices after tiles are generated
    _last_player_segment_indices = _get_current_player_segment_indices();
    // Initial flash is now controlled by Level setting effectsEnabled = true
  }

  @override
  void onRemove() {
    parent?.removeWhere((it) => it is LevelTile && !it.isRemoving && !it.isRemoved);
    super.onRemove();
  }

  void _generate_tiles() {
    parent?.removeWhere((it) => it is LevelTile);
    tiles.clear();

    final z_levels = Level.path_grid_z_levels;
    final num_segments = _level.is_closed ? _level.path.vertices.length : _level.path.vertices.length - 1;

    if (_level.cumulative_normalized_distances.isEmpty || z_levels.length < 2 || num_segments <= 0) {
      return;
    }

    for (int j = 0; j < z_levels.length - 1; j++) {
      final grid_z1 = z_levels[j];
      final grid_z2 = z_levels[j + 1];
      final List<LevelTile> z_level_tiles = [];

      final t = grid_z1;
      final base_color = Color.lerp(_color.start_color, _color.end_color, t)!;
      final stroke_width = lerpDouble(2.0, 1.0, t)!;

      for (int i = 0; i < num_segments; i++) {
        final dist_start = _level.cumulative_normalized_distances[i];
        final dist_end =
            (i == num_segments - 1 && _level.is_closed) ? 1.0 : _level.cumulative_normalized_distances[i + 1];

        final grid_x1 = dist_start * 2.0 - 1.0;
        final grid_x2 = dist_end * 2.0 - 1.0;
        final tile = LevelTile(
          outline_color: base_color,
          outline_stroke_width: stroke_width,
          is_bottom: j == 0,
          is_top: j == z_levels.length - 2,
          is_right: i == num_segments - 1,
          grid_left: grid_x1,
          grid_right: grid_x2,
          grid_bottom: grid_z1,
          grid_top: grid_z2,
        );

        // tile.debug_info = "$i,$j";

        parent?.add(tile);
        z_level_tiles.add(tile);
      }
      tiles.add(z_level_tiles);
    }

    for (int j = 0; j < z_levels.length - 2; j++) {
      for (int i = 0; i < num_segments; i++) {
        var prev = tile_at(i, j + 1);
        tile_at(i, j).previous = prev;
      }
    }
  }

  (int, int?) _get_current_player_segment_indices() {
    const double epsilon = 0.005;
    final player_grid_x = player.grid_x;
    final clamped_grid_x = player_grid_x.clamp(-1.0, 1.0);
    final target_dist = (clamped_grid_x + 1.0) / 2.0;

    final distances = _level.cumulative_normalized_distances;
    final num_segments = tiles.isNotEmpty ? tiles[0].length : 0;

    if (distances.isEmpty || num_segments == 0) {
      return (-1, null);
    }

    if (_level.is_closed) {
      if (target_dist < epsilon || target_dist > (1.0 - epsilon)) {
        return (num_segments - 1, 0);
      }
      for (int i = 1; i < distances.length; i++) {
        final boundary_dist = distances[i];
        if ((target_dist - boundary_dist).abs() < epsilon) {
          return (i - 1, i);
        }
      }
    } else {
      for (int i = 1; i < distances.length - 1; i++) {
        final boundary_dist = distances[i];
        if ((target_dist - boundary_dist).abs() < epsilon) {
          return (i - 1, i);
        }
      }
    }

    int primary_index = -1;
    if (_level.is_closed) {
      if (target_dist >= distances.last) {
        primary_index = num_segments - 1;
      } else {
        for (int i = 0; i < distances.length - 1; i++) {
          if (target_dist >= distances[i] && target_dist < distances[i + 1]) {
            primary_index = i;
            break;
          }
        }
        if (primary_index == -1 && target_dist < distances[0]) {
          primary_index = num_segments - 1;
        }
      }
    } else {
      if (target_dist <= distances[0] || distances.length < 2) {
        primary_index = 0;
      } else if (target_dist >= distances.last) {
        primary_index = num_segments - 1;
      } else {
        for (int i = 0; i < distances.length - 1; i++) {
          if (target_dist >= distances[i] && target_dist < distances[i + 1]) {
            primary_index = i;
            break;
          }
        }
      }
    }

    if (primary_index < 0 || primary_index >= num_segments) {
      assert(false,
          "Failed to determine primary segment index. targetDist: $target_dist, numSegments: $num_segments, isClosed: ${_level.is_closed}, distances: $distances");
      return (num_segments > 0 ? 0 : -1, null);
    }

    return (primary_index, null);
  }

  void _flash_segment_tiles(int segment_index1, int? segment_index2) {
    final num_z_levels = tiles.length;
    final num_segments = tiles.isNotEmpty ? tiles[0].length : 0;
    const double stagger_delay_per_level = 0.03;

    if (segment_index1 < 0 || segment_index1 >= num_segments) return;
    if (segment_index2 != null && (segment_index2 < 0 || segment_index2 >= num_segments)) {
      segment_index2 = null;
    }
    if (segment_index1 == segment_index2) {
      segment_index2 = null;
    }

    final flash_color = _color.start_color;

    for (int j = 0; j < num_z_levels; j++) {
      final double delay = j * stagger_delay_per_level;
      tiles[j][segment_index1].flash(flash_color, start_delay: delay);
    }
  }

  void _pulse_segment_tiles(int segment_index1, int? segment_index2) {
    final num_z_levels = tiles.length;
    final num_segments = tiles.isNotEmpty ? tiles[0].length : 0;
    const double stagger_delay_per_level = 0.03;

    if (segment_index1 < 0 || segment_index1 >= num_segments) return;
    if (segment_index2 != null && (segment_index2 < 0 || segment_index2 >= num_segments)) {
      segment_index2 = null;
    }
    if (segment_index1 == segment_index2) {
      segment_index2 = null;
    }

    final flash_color = _color.start_color;

    const pulse_fade_in = 0.1;
    const pulse_hold = 0.1;
    const pulse_fade_out = 1.0;
    const pulse_max_alpha = 0.2;

    for (int j = 0; j < num_z_levels; j++) {
      final double delay = j * stagger_delay_per_level;
      tiles[j][segment_index1].flash(
        flash_color,
        fade_in: pulse_fade_in,
        hold: pulse_hold,
        fade_out: pulse_fade_out,
        max_alpha: pulse_max_alpha,
        start_delay: delay,
      );
      if (segment_index2 != null) {
        tiles[j][segment_index2].flash(
          flash_color,
          fade_in: pulse_fade_in,
          hold: pulse_hold,
          fade_out: pulse_fade_out,
          max_alpha: pulse_max_alpha,
          start_delay: delay,
        );
      }
    }
  }

  LevelTile tile_at(int x_idx, int z_idx) => tiles[z_idx][x_idx];

  (LevelTile?, int?, int?) tile_at_grid(double grid_x, double grid_z) {
    final z_idx = find_z_segment(grid_z);
    final x_idx = find_x_segment(grid_x);
    if (z_idx < tiles.length && x_idx < tiles[z_idx].length) {
      return (tiles[z_idx][x_idx], x_idx, z_idx);
    }
    return (null, null, null);
  }

  int find_z_segment(double grid_z) {
    int z_idx = 0;
    double min_z = double.infinity;
    final z_levels = Level.path_grid_z_levels;
    for (int j = 0; j < z_levels.length - 1; j++) {
      final mid = (z_levels[j] + z_levels[j + 1]) / 2.0;
      final d = (mid - grid_z).abs();
      if (d < min_z) {
        min_z = d;
        z_idx = j;
      }
    }
    return z_idx;
  }

  int find_x_segment(double grid_x) {
    int x_idx = 0;
    double min_x = double.infinity;
    final distances = _level.cumulative_normalized_distances;
    for (int i = 0; i < distances.length - 1; i++) {
      final mid = (distances[i] + distances[i + 1]) / 2.0 * 2.0 - 1.0;
      final d = (mid - grid_x).abs();
      if (d < min_x) {
        min_x = d;
        x_idx = i;
      }
    }
    return x_idx;
  }

  @override
  void update(double dt) {
    super.update(dt);

    if (!effects_enabled) {
      _pulse_timer = 0.0;
      return;
    }

    update_electrification(dt);

    final current_segment_indices = _get_current_player_segment_indices();

    if (current_segment_indices.$1 != -1 && current_segment_indices.$1 != _last_player_segment_indices.$1) {
      _flash_segment_tiles(current_segment_indices.$1, null);
      _last_player_segment_indices = current_segment_indices;
      _pulse_timer = 0.0;
    } else if (current_segment_indices != _last_player_segment_indices) {
      _last_player_segment_indices = current_segment_indices;
      _pulse_timer = 0.0;
    }

    _pulse_timer += dt;
    if (_pulse_timer >= _pulse_interval) {
      _pulse_timer -= _pulse_interval;

      if (_last_player_segment_indices.$1 != -1) {
        _pulse_segment_tiles(_last_player_segment_indices.$1, _last_player_segment_indices.$2);
      }
    }
  }
}
