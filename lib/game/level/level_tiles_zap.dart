import 'dart:ui';

import 'package:stardash/game/level/level_tile.dart';

mixin class LevelTilesZap {
  // Store tiles in a 2D list: [z_level_index][segment_index]
  final List<List<LevelTile>> tiles = [];

  final Map<int, double> _electrified_segments_remaining_duration = {};
  final Map<int, double> _electrification_flash_trackers = {};
  static const double _electrification_flash_interval = 0.05;
  static const double _electrification_stagger_delay_per_level = 0.01;
  static const Color _electrification_flash_color = Color(0xFFFFFFFF);
  static const double _electrification_fade_in = 0.02;
  static const double _electrification_hold = 0.02;
  static const double _electrification_fade_out = 0.02;
  static const double _electrification_max_alpha = 1.0;

  // Public method to start electrification
  void electrify(int segment_index, double duration) {
    _electrified_segments_remaining_duration[segment_index] = duration;
    _electrification_flash_trackers[segment_index] = 0.0; // Reset flash timer to trigger quickly
    _trigger_electrification_flash(segment_index); // Initial flash
  }

  // Public method to check electrification status
  bool is_electrified(int segment_index) {
    final num_segments = tiles.isNotEmpty ? tiles[0].length : 0;
    return _electrified_segments_remaining_duration.containsKey(segment_index);
  }

  void _trigger_electrification_flash(int segment_index) {
    final num_z_levels = tiles.length;
    for (int j = 0; j < num_z_levels; j++) {
      final double delay = j * _electrification_stagger_delay_per_level;
      tiles[j][segment_index].flash(
        _electrification_flash_color,
        fade_in: _electrification_fade_in,
        hold: _electrification_hold,
        fade_out: _electrification_fade_out,
        max_alpha: _electrification_max_alpha,
        start_delay: delay,
      );
    }
  }

  void update_electrification(double dt) {
    if (_electrified_segments_remaining_duration.isEmpty) {
      return;
    }

    final segments_to_remove = <int>[];
    final active_segments = _electrified_segments_remaining_duration.keys.toList();

    for (final segment_idx in active_segments) {
      if (!_electrified_segments_remaining_duration.containsKey(segment_idx)) {
        continue;
      }

      var remaining_duration = _electrified_segments_remaining_duration[segment_idx]!;
      remaining_duration -= dt;

      if (remaining_duration <= 0.0) {
        segments_to_remove.add(segment_idx);
      } else {
        _electrified_segments_remaining_duration[segment_idx] = remaining_duration;

        var flash_timer = _electrification_flash_trackers[segment_idx]!;
        flash_timer += dt;
        if (flash_timer >= _electrification_flash_interval) {
          _trigger_electrification_flash(segment_idx);
          flash_timer %= _electrification_flash_interval;
        }
        _electrification_flash_trackers[segment_idx] = flash_timer;
      }
    }

    for (final segment_idx in segments_to_remove) {
      _electrified_segments_remaining_duration.remove(segment_idx);
      _electrification_flash_trackers.remove(segment_idx);
    }
  }
}
