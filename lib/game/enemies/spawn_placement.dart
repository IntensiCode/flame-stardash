import 'dart:math';

/// Enum defining different strategies for placing enemies horizontally (gridX).
enum SpawnPlacementStrategy {
  Oscillate, // Left -> Right -> Left ... starting left
  RandomSpread, // Random positions across the middle width (-0.8 to 0.8)
  CenterOut, // 0, -step, step, -2*step, 2*step ...
  EdgeFocus, // Randomly near the left or right edge (-1 to -0.7 or 0.7 to 1)
}

// Public, shared random instance for placement calculations.
// Should be reassigned with a new seeded instance at the start of each level.
Random spawn_pos_random = Random(0);

/// Calculates the gridX for the i-th enemy for stateless strategies.
///
/// Assumes [spawn_pos_random] has been seeded appropriately for the level.
double calc_spawn_grid_x({
  required SpawnPlacementStrategy strategy,
  required int index,
  required int count,
}) {
  assert(strategy != SpawnPlacementStrategy.Oscillate, 'Use calculateOscillatingGridX for Oscillate strategy');

  double grid_x;
  const double placement_step = 0.4;

  switch (strategy) {
    case SpawnPlacementStrategy.RandomSpread:
      grid_x = spawn_pos_random.nextDouble() * 1.6 - 0.8;
      break;

    case SpawnPlacementStrategy.CenterOut:
      if (index == 0) {
        grid_x = 0.0;
      } else {
        final magnitude = ((index + 1) ~/ 2) * placement_step;
        final sign = (index % 2 == 1) ? -1.0 : 1.0;
        grid_x = sign * magnitude;
      }
      break;

    case SpawnPlacementStrategy.EdgeFocus:
      final side = spawn_pos_random.nextBool() ? 1.0 : -1.0;
      final offset = spawn_pos_random.nextDouble() * 0.3;
      grid_x = side * (0.7 + offset);
      break;
    // Oscillate case removed
    case SpawnPlacementStrategy.Oscillate:
      // This case should not be reached due to the assert.
      // Return a default or throw an error if needed.
      return 0.0;
  }

  return grid_x.clamp(-1.0, 1.0);
}

/// Calculates the gridX for the current step of an oscillating pattern
/// and returns the state needed for the *next* step.
///
/// Returns a record: (gridX: current placement, nextX: state for next call, nextIncrement: state for next call)
({double grid_x, double next_x, double next_increment}) calc_oscillating_grid_x({
  required double in_x,
  required double in_increment,
}) {
  // The current position *is* the gridX for this step
  final double grid_x = in_x;

  // Calculate the state for the *next* step
  double next_x = in_x + in_increment;
  double next_increment = in_increment;

  // Check boundaries and reverse direction if needed
  if (next_x.abs() > 0.85) {
    next_increment *= -1;
    next_x = in_x + next_increment; // Recalculate nextX with new increment
  }

  // Clamp the *next* position firmly
  next_x = next_x.clamp(-0.8, 0.8);

  return (grid_x: grid_x, next_x: next_x, next_increment: next_increment);
}
