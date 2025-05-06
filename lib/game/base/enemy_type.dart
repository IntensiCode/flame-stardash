enum EnemyType {
  /// Jumps rapidly between different grid depths or adjacent lanes. Fires basic energy spikes.
  Flipper,

  /// Moves forward until z zero. Fires basic energy spikes. Releases two flippers when destroyed or at z zero.
  Tanker,

  /// Extends hazardous energy spikes across grid segments.
  Spiker,

  /// Jumps like Flipper, but will also electrify the current lane randomly.
  Pulsar(),
}
