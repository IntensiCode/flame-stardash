import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:stardash/game/base/has_context.dart';
import 'package:stardash/game/enemies/enemy_type.dart';
import 'package:stardash/game/enemies/spawn_event.dart';
import 'package:stardash/game/enemies/spawn_placement.dart';
import 'package:stardash/game/level/level.dart';
import 'package:stardash/game/level/level_color.dart';
import 'package:stardash/game/level/level_path.dart';
import 'package:stardash/util/log.dart';

extension HasContextExtensions on HasContext {
  Levels get levels => cache.putIfAbsent('levels', () => Levels());
}

class LevelConfig {
  LevelConfig(this.number, this.pathType, this.color);

  final int number;
  final LevelPathType pathType;
  final LevelColor color;
}

class Levels extends Component with HasContext {
  static final _pathTypes = LevelPathType.values;
  static final _colors = LevelColor.values;

  // --- Lane Management ---
  static const int _numberOfLanes = 11; // e.g., -1.0, -0.8, ..., 0.8, 1.0
  static const double _laneWidth = 2.0 / (_numberOfLanes - 1);

  // Converts gridX to a discrete lane index
  int _getLaneIndex(double gridX) {
    // Normalize gridX to [0, 2] then scale to lane range [0, _numberOfLanes - 1]
    final normalized = gridX + 1.0;
    final lane = (normalized / _laneWidth).round().clamp(0, _numberOfLanes - 1);
    return lane;
  }

  // Converts a lane index back to a representative gridX (center of the lane)
  double _getGridXForLane(int laneIndex) {
    final clampedIndex = laneIndex.clamp(0, _numberOfLanes - 1);
    // Calculate center gridX for the lane
    return -1.0 + clampedIndex * _laneWidth;
  }

  // --- End Lane Management ---

  // Renamed from 'level' to avoid conflict with HasContext getter
  LevelConfig level_config(int levelNumber) {
    assert(levelNumber >= 1, 'Level number must be 1 or greater');
    final pathIndex = (levelNumber - 1) % _pathTypes.length;
    final colorIndex = ((levelNumber - 1) ~/ _pathTypes.length) % _colors.length;
    return LevelConfig(
      levelNumber,
      _pathTypes[pathIndex],
      _colors[colorIndex],
    );
  }

  List<SpawnEvent> enemies(int levelNumber) {
    assert(levelNumber >= 1, 'Level number must be 1 or greater');

    spawn_pos_random = math.Random(levelNumber);

    final pathCycleLength = _pathTypes.length;
    final colorCycleNumber = (levelNumber - 1) ~/ pathCycleLength;

    // final possibleEnemies = EnemyType.values.where((enemy) {
    //   return colorCycleNumber >= enemy.firstCycle;
    // }).toList();
    final possibleEnemies = EnemyType.values;

    final spawnEvents = <SpawnEvent>[];
    if (possibleEnemies.isEmpty) {
      log_warn('No possible enemies for level $levelNumber (cycle $colorCycleNumber)');
      return spawnEvents;
    }

    final int targetEnemyCount = math.max(5, 3 + colorCycleNumber * 2);
    final enemiesToSpawn = <EnemyType>[];
    // possibleEnemies.sort((a, b) => a.tier.compareTo(b.tier));

    if (possibleEnemies.length == 1) {
      enemiesToSpawn.addAll(List.filled(targetEnemyCount, possibleEnemies.first));
    } else {
      enemiesToSpawn.add(possibleEnemies[0]);
      enemiesToSpawn.add(possibleEnemies[1]);
      for (int i = 2; i < targetEnemyCount; i++) {
        enemiesToSpawn.add(possibleEnemies[i % possibleEnemies.length]);
      }
    }

    log_info('Level $levelNumber (Cycle $colorCycleNumber): Spawning $targetEnemyCount enemies.');

    double baseTimeOffset = math.max(0.15, 1.2 - colorCycleNumber * 0.1);
    double initialDelay = 1.5;

    // State for Oscillate strategy
    double osc_x = -0.8;
    double osc_increment = 0.4;

    // --- Track used lanes ---
    final Set<int> usedLanes = {};
    final List<int> allLaneIndices = List.generate(_numberOfLanes, (index) => index);

    for (int i = 0; i < enemiesToSpawn.length; i++) {
      final enemyType = enemiesToSpawn[i];

      // --- Select strategy ---
      final allowedStrategies = enemyType.allowedStrategies;
      SpawnPlacementStrategy strategy;
      if (allowedStrategies.isEmpty) {
        strategy = SpawnPlacementStrategy.RandomSpread; // Fallback
      } else if (allowedStrategies.length == 1) {
        strategy = allowedStrategies.first;
      } else {
        strategy = allowedStrategies[spawn_pos_random.nextInt(allowedStrategies.length)];
      }

      // --- Calculate target gridX based on strategy ---
      double target_grid_x;
      if (strategy == SpawnPlacementStrategy.Oscillate) {
        final result = calc_oscillating_grid_x(in_x: osc_x, in_increment: osc_increment);
        target_grid_x = result.grid_x;
        // Defer state update until after lane check
      } else {
        target_grid_x = calc_spawn_grid_x(strategy: strategy, index: i, count: targetEnemyCount);
      }

      // --- Determine Final Lane and gridX ---
      int targetLane = _getLaneIndex(target_grid_x);
      int finalLane;
      double finalGridX;

      if (!usedLanes.contains(targetLane)) {
        // Target lane is free, use it
        finalLane = targetLane;
        finalGridX = target_grid_x; // Use the strategy's calculated X
      } else {
        // Target lane is used, find an alternative
        final List<int> availableLanes = allLaneIndices.where((lane) => !usedLanes.contains(lane)).toList();

        if (availableLanes.isNotEmpty) {
          // Pick a random available lane
          finalLane = availableLanes[spawn_pos_random.nextInt(availableLanes.length)];
          finalGridX = _getGridXForLane(finalLane); // Place at center of chosen lane
        } else {
          // All lanes used, clear tracking and allow overlap (use original target)
          log_warn('All lanes used, clearing and allowing overlap for index $i');
          usedLanes.clear();
          finalLane = targetLane;
          finalGridX = target_grid_x;
        }
      }

      // Mark the chosen lane as used for next time
      usedLanes.add(finalLane);

      // --- Update Oscillate state if it was the chosen strategy *and* lane was free/reset ---
      if (strategy == SpawnPlacementStrategy.Oscillate && finalLane == targetLane) {
        final result = calc_oscillating_grid_x(in_x: osc_x, in_increment: osc_increment);
        // Update state only if we actually used the calculated oscillate position
        osc_x = result.next_x;
        osc_increment = result.next_increment;
      }

      // --- Calculate timeOffset ---
      final tierTimeFactor = 1.0 + (enemyType.tier * 0.1);
      final timeOffset = (i == 0) ? initialDelay : baseTimeOffset * tierTimeFactor;

      double snappedGridX = _snapGridXToNearestVertex(finalGridX);

      spawnEvents.add(SpawnEvent(
        enemyType: enemyType,
        timeOffset: math.max(0.1, timeOffset),
        gridX: snappedGridX.clamp(-1.0, 1.0), // Use the snapped gridX
      ));
    }

    return spawnEvents;
  }

  /// Finds the gridX value corresponding to the path vertex closest to the targetGridX.
  double _snapGridXToNearestVertex(double targetGridX) {
    // Access the current level component via context (no longer conflicts with getLevelConfig)
    final currentLevelComponent = level;
    final distances = currentLevelComponent.cumulative_normalized_distances;

    if (distances.isEmpty) {
      log_warn('Cannot snap gridX: cumulative distances not available.');
      return targetGridX; // Return original if no data
    }

    double minDiff = double.infinity;
    double snappedGridX = distances.first * 2.0 - 1.0; // Default to first vertex

    for (final cumulativeDist in distances) {
      final vertexGridX = cumulativeDist * 2.0 - 1.0;
      final diff = (targetGridX - vertexGridX).abs();

      if (diff < minDiff) {
        minDiff = diff;
        snappedGridX = vertexGridX;
      }
    }
    return snappedGridX;
  }

  Component? boss(int levelNumber) {
    assert(levelNumber >= 1, 'Level number must be 1 or greater');
    final pathCycleLength = _pathTypes.length;
    final pathIndex = (levelNumber - 1) % pathCycleLength;
    if (pathIndex == pathCycleLength - 1) {
      return null;
    }
    return null;
  }
}
