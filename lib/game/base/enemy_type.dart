enum SpawnType {
  random,
}

enum EnemyType {
  /// Jumps rapidly between different grid depths or adjacent lanes. Fires basic energy spikes.
  Flipper(
    first_level: 1,
    spawn_type: SpawnType.random,
  ),

  /// Moves forward until z zero. Fires basic energy spikes. Releases two flippers when destroyed or at z zero.
  Tanker(
    first_level: 3,
    spawn_type: SpawnType.random,
  ),

  /// Extends hazardous energy spikes across grid segments.
  Spiker(
    first_level: 4,
    spawn_type: SpawnType.random,
  ),
  ;

  const EnemyType({
    required this.first_level,
    required this.spawn_type,
  });

  final int first_level;
  final SpawnType spawn_type;
}
