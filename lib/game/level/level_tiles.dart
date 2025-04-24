import 'dart:ui';

import 'package:flame/components.dart';
import 'package:stardash/game/base/has_context.dart';
import 'package:stardash/game/level/level.dart';
import 'package:stardash/game/level/level_color.dart';
import 'package:stardash/game/level/level_geometry.dart';
import 'package:stardash/game/level/level_tile.dart';
import 'package:stardash/game/player/player.dart';

class LevelTiles extends Component with HasContext, HasPaint {
  // Store tiles in a 2D list: [zLevelIndex][segmentIndex]
  final List<List<LevelTile>> _tiles = [];

  final LevelGeometry _level;
  final LevelColor _color;

  // Store the last segment(s) the player was in
  (int, int?) _lastPlayerSegmentIndices = (-1, null);

  // Pulse timing
  double _pulseTimer = 0.0;
  static const double _pulseInterval = 1.0; // seconds

  // Flag to enable/disable flashing/pulsing effects
  bool effects_enabled = false;

  LevelTiles({required LevelGeometry level, required LevelColor color})
      : _level = level,
        _color = color {
    paint.style = PaintingStyle.fill;
    priority = -10000;
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    assert(parent is Level, 'LevelTiles must be added to a Level component');
    _generateTiles();
    // Get initial player segment indices after tiles are generated
    _lastPlayerSegmentIndices = _getCurrentPlayerSegmentIndices(); // Correct function name
    // Initial flash is now controlled by Level setting effectsEnabled = true
  }

  void _generateTiles() {
    removeAll(children);
    _tiles.clear();

    final zLevels = Level.path_grid_z_levels;
    final numSegments =
        _level.is_closed ? _level.path_definition.vertices.length : _level.path_definition.vertices.length - 1;

    if (_level.cumulative_normalized_distances.isEmpty || zLevels.length < 2 || numSegments <= 0) {
      return;
    }

    for (int j = 0; j < zLevels.length - 1; j++) {
      final gridZ1 = zLevels[j];
      final gridZ2 = zLevels[j + 1];
      final List<LevelTile> zLevelTiles = []; // Row for this Z level

      for (int i = 0; i < numSegments; i++) {
        final distStart = _level.cumulative_normalized_distances[i];
        final distEnd = (i == numSegments - 1 && _level.is_closed)
            ? 1.0 // Use 1.0 for distance, gridX wrapping is handled next
            : _level.cumulative_normalized_distances[i + 1];

        final gridX1 = distStart * 2.0 - 1.0;
        final gridX2 = distEnd * 2.0 - 1.0;

        // Calculate the 4 corner points using the level's mapping function
        // IMPORTANT: Force clampAndWrapX=true for tile generation to avoid gaps/overlaps at wrap point
        final p1 = _level.map_grid_to_screen(gridX1, gridZ1, clamp_and_wrap_x: true);
        final p2 = _level.map_grid_to_screen(gridX2, gridZ1, clamp_and_wrap_x: true);
        final p3 = _level.map_grid_to_screen(gridX2, gridZ2, clamp_and_wrap_x: true);
        final p4 = _level.map_grid_to_screen(gridX1, gridZ2, clamp_and_wrap_x: true);

        final tile = LevelTile(sharedPaint: paint, p1: p1, p2: p2, p3: p3, p4: p4);
        add(tile); // Add as child for rendering/updates
        zLevelTiles.add(tile); // Add to the row list
      }
      _tiles.add(zLevelTiles); // Add the completed row to the 2D list
    }
  }

  // Determines the current segment index(es) based on player position.
  // Returns a tuple: (primaryIndex, secondaryIndex).
  // secondaryIndex is non-null if the player is close to a vertex between segments.
  (int, int?) _getCurrentPlayerSegmentIndices() {
    const double epsilon = 0.005; // Increased Threshold for proximity to a vertex
    final playerGridX = player.grid_x;
    // Ensure playerGridX is within [-1, 1] range, especially for closed loops
    final clampedGridX = playerGridX.clamp(-1.0, 1.0);
    final targetDist = (clampedGridX + 1.0) / 2.0; // Normalized distance [0, 1]

    final distances = _level.cumulative_normalized_distances;
    // Use the actual number of segments generated for indexing tiles
    final numSegments = _tiles.isNotEmpty ? _tiles[0].length : 0;

    if (distances.isEmpty || numSegments == 0) {
      return (-1, null); // Indicate invalid state
    }

    // --- Proximity Check First ---
    if (_level.is_closed) {
      if (targetDist < epsilon || targetDist > (1.0 - epsilon)) {
        return (numSegments - 1, 0); // Segments adjacent to wrap-around vertex
      }
      for (int i = 1; i < distances.length; i++) {
        final boundaryDist = distances[i];
        if ((targetDist - boundaryDist).abs() < epsilon) {
          return (i - 1, i);
        }
      }
    } else {
      // Open Level
      for (int i = 1; i < distances.length - 1; i++) {
        final boundaryDist = distances[i];
        if ((targetDist - boundaryDist).abs() < epsilon) {
          return (i - 1, i);
        }
      }
    }

    // --- Determine Primary Segment if Not Near Vertex ---
    int primaryIndex = -1;
    if (_level.is_closed) {
      if (targetDist >= distances.last) {
        // After the start of the last segment
        primaryIndex = numSegments - 1;
      } else {
        for (int i = 0; i < distances.length - 1; i++) {
          if (targetDist >= distances[i] && targetDist < distances[i + 1]) {
            primaryIndex = i;
            break;
          }
        }
        if (primaryIndex == -1 && targetDist < distances[0]) {
          primaryIndex = numSegments - 1;
        }
      }
    } else {
      // Open Level
      if (targetDist <= distances[0] || distances.length < 2) {
        primaryIndex = 0;
      } else if (targetDist >= distances.last) {
        primaryIndex = numSegments - 1;
      } else {
        for (int i = 0; i < distances.length - 1; i++) {
          if (targetDist >= distances[i] && targetDist < distances[i + 1]) {
            primaryIndex = i;
            break;
          }
        }
      }
    }

    if (primaryIndex < 0 || primaryIndex >= numSegments) {
      assert(false,
          "Failed to determine primary segment index. targetDist: $targetDist, numSegments: $numSegments, isClosed: ${_level.is_closed}, distances: $distances");
      return (numSegments > 0 ? 0 : -1, null);
    }

    return (primaryIndex, null);
  }

  // Flash triggered when entering a segment
  void _flashSegmentTiles(int segmentIndex1, int? segmentIndex2) {
    final numZLevels = _tiles.length;
    final numSegments = _tiles.isNotEmpty ? _tiles[0].length : 0;
    const double staggerDelayPerLevel = 0.03;

    if (segmentIndex1 < 0 || segmentIndex1 >= numSegments) return;
    if (segmentIndex2 != null && (segmentIndex2 < 0 || segmentIndex2 >= numSegments)) {
      segmentIndex2 = null;
    }
    if (segmentIndex1 == segmentIndex2) {
      segmentIndex2 = null;
    }

    final flashColor = _color.start_color;

    for (int j = 0; j < numZLevels; j++) {
      final double delay = j * staggerDelayPerLevel;
      _tiles[j][segmentIndex1].flash(flashColor, startDelay: delay);
      // Only flash primary for this method
      // if (segmentIndex2 != null) {
      //   _tiles[j][segmentIndex2].flash(flashColor, startDelay: delay);
      // }
    }
  }

  // Pulse triggered periodically while staying in a segment
  void _pulseSegmentTiles(int segmentIndex1, int? segmentIndex2) {
    final numZLevels = _tiles.length;
    final numSegments = _tiles.isNotEmpty ? _tiles[0].length : 0;
    const double staggerDelayPerLevel = 0.03;

    // Validate indices
    if (segmentIndex1 < 0 || segmentIndex1 >= numSegments) return; // Ignore invalid primary
    if (segmentIndex2 != null && (segmentIndex2 < 0 || segmentIndex2 >= numSegments)) {
      segmentIndex2 = null; // Invalidate bad second index, but proceed with primary
    }
    // Prevent pulsing the same segment twice
    if (segmentIndex1 == segmentIndex2) {
      segmentIndex2 = null;
    }

    final flashColor = _color.start_color;

    const pulseFadeIn = 0.1;
    const pulseHold = 0.1;
    const pulseFadeOut = 1.0;
    const pulseMaxAlpha = 0.2;

    for (int j = 0; j < numZLevels; j++) {
      final double delay = j * staggerDelayPerLevel;

      // Apply pulse to the first segment
      _tiles[j][segmentIndex1].flash(
        flashColor,
        fadeIn: pulseFadeIn,
        hold: pulseHold,
        fadeOut: pulseFadeOut,
        maxAlpha: pulseMaxAlpha,
        startDelay: delay,
      );

      // Apply pulse to the second segment if it exists and is valid
      if (segmentIndex2 != null) {
        _tiles[j][segmentIndex2].flash(
          flashColor,
          fadeIn: pulseFadeIn,
          hold: pulseHold,
          fadeOut: pulseFadeOut,
          maxAlpha: pulseMaxAlpha,
          startDelay: delay,
        );
      }
    }
  }

  @override
  void update(double dt) {
    super.update(dt);

    if (!effects_enabled) {
      _pulseTimer = 0.0;
      return;
    }

    final currentSegmentIndices = _getCurrentPlayerSegmentIndices(); // Correct function name

    // --- Handle Segment Change Flash ---
    if (currentSegmentIndices.$1 != -1 && currentSegmentIndices.$1 != _lastPlayerSegmentIndices.$1) {
      _flashSegmentTiles(currentSegmentIndices.$1, null); // Flash only primary
      _lastPlayerSegmentIndices = currentSegmentIndices;
      _pulseTimer = 0.0;
    }
    // --- Handle State Update Without Flash ---
    else if (currentSegmentIndices != _lastPlayerSegmentIndices) {
      _lastPlayerSegmentIndices = currentSegmentIndices;
      _pulseTimer = 0.0;
    }

    // --- Handle Periodic Pulse ---
    _pulseTimer += dt;
    if (_pulseTimer >= _pulseInterval) {
      _pulseTimer -= _pulseInterval;

      if (_lastPlayerSegmentIndices.$1 != -1) {
        _pulseSegmentTiles(_lastPlayerSegmentIndices.$1, _lastPlayerSegmentIndices.$2); // Correct pulse call
      }
    }
  }
}
