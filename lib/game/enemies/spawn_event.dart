import 'package:stardash/game/base/enemy_type.dart';

/// Represents a single enemy spawn event within a level's sequence.
class SpawnEvent {
  SpawnEvent({
    required this.enemy_type,
    required this.time_offset, // Time since the *previous* spawn event
    required this.grid_x,
    this.grid_z = 1.0,
  });

  final EnemyType enemy_type;

  /// The time delay (in seconds) after the previous spawn event in the sequence.
  /// For the first event, this might be the delay from the level start.
  final double time_offset;

  final double grid_x;
  final double grid_z;

  @override
  String toString() => "SpawnEvent(${[enemy_type, time_offset, grid_x, grid_z]})";
}
