import 'package:stardash/game/enemies/enemy_type.dart';

/// Represents a single enemy spawn event within a level's sequence.
class SpawnEvent {
  SpawnEvent({
    required this.enemyType,
    required this.timeOffset, // Time since the *previous* spawn event
    required this.gridX, // Pre-determined grid line
  });

  /// The type of enemy to spawn.
  final EnemyType enemyType;

  /// The time delay (in seconds) after the previous spawn event in the sequence.
  /// For the first event, this might be the delay from the level start.
  final double timeOffset;

  /// The horizontal grid position (-1.0 to 1.0) where the enemy should spawn.
  final double gridX;

  @override
  String toString() => "SpawnEvent{enemyType: $enemyType, timeOffset: $timeOffset, gridX: $gridX}";
}
