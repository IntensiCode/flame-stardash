import 'package:stardash/game/enemies/spawn_placement.dart';

/*

Potential enemy behaviors when reaching z zero:

- Damages/Destroys Player: If it makes contact with the player's current
  position on that line, it deals damage or destroys the player ship. This is
  classic Tempest behavior.
- Becomes a Stationary Obstacle: It could stop at the rim, blocking that
  specific line for movement and shots until destroyed. Less immediately
  lethal, but adds pressure.
- Is Destroyed/Despawns: The simplest option, it just disappears harmlessly.
  Less threatening for an enemy.

*/

enum EnemyType {
  /// Basic enemy moving predictably along grid lines. Simple threat.
  Crawler(
    tier: 0,
    firstCycle: 0,
    allowedStrategies: [SpawnPlacementStrategy.Oscillate, SpawnPlacementStrategy.CenterOut],
  ),

  /// Stationary or slow enemy firing energy pulses down grid paths.
  PulseSentry(
    tier: 1,
    firstCycle: 1,
    allowedStrategies: [SpawnPlacementStrategy.CenterOut, SpawnPlacementStrategy.EdgeFocus],
  ),
  /// Quickly zips along grid segments, demanding fast reactions.
  Skimmer(
    tier: 1,
    firstCycle: 1,
    allowedStrategies: [SpawnPlacementStrategy.RandomSpread, SpawnPlacementStrategy.Oscillate, SpawnPlacementStrategy.EdgeFocus],
  ),
  /// Jumps rapidly between different grid depths or adjacent lanes.
  Flipper(
    tier: 1,
    firstCycle: 2,
    allowedStrategies: [SpawnPlacementStrategy.RandomSpread, SpawnPlacementStrategy.EdgeFocus],
  ),

  /// Aggressively rushes the player along the grid, exploding on contact.
  Fuse(
    tier: 2,
    firstCycle: 2,
    allowedStrategies: [SpawnPlacementStrategy.CenterOut, SpawnPlacementStrategy.RandomSpread],
  ),
  /// Defended from the front, requiring flanking maneuvers.
  Phalanx(
    tier: 2,
    firstCycle: 3,
    allowedStrategies: [SpawnPlacementStrategy.CenterOut, SpawnPlacementStrategy.Oscillate],
  ),
  /// Extends hazardous energy spikes across grid segments or fires projectiles.
  Spiker(
    tier: 2,
    firstCycle: 3,
    allowedStrategies: [SpawnPlacementStrategy.EdgeFocus, SpawnPlacementStrategy.CenterOut],
  ),

  /// Fires precise, long-range energy beams down grid channels.
  BeamEmitter(
    tier: 3,
    firstCycle: 4,
    allowedStrategies: [SpawnPlacementStrategy.EdgeFocus, SpawnPlacementStrategy.CenterOut],
  ),
  /// Moves erratically, potentially phasing or distorting view/controls.
  WarpDrone(
    tier: 3,
    firstCycle: 4,
    allowedStrategies: [SpawnPlacementStrategy.RandomSpread],
  ),
  /// Moves laterally across the grid's width, firing rapidly or clearing paths.
  GridSweeper(
    tier: 3,
    firstCycle: 5,
    allowedStrategies: [SpawnPlacementStrategy.Oscillate], // Only really makes sense
  ),

  /// Slow, heavily armored enemy absorbing significant damage.
  Bulwark(
    tier: 4,
    firstCycle: 5,
    allowedStrategies: [SpawnPlacementStrategy.CenterOut, SpawnPlacementStrategy.Oscillate],
  ),
  /// Geometric entity, possibly rotating or firing from multiple faces.
  Tetra(
    tier: 4,
    firstCycle: 6,
    allowedStrategies: [SpawnPlacementStrategy.CenterOut, SpawnPlacementStrategy.RandomSpread],
  ),
  /// Temporarily becomes invisible or translucent, difficult to track.
  Phantom(
    tier: 4,
    firstCycle: 6,
    allowedStrategies: [SpawnPlacementStrategy.RandomSpread, SpawnPlacementStrategy.EdgeFocus],
  );

  const EnemyType({
    required this.tier,
    required this.firstCycle,
    required this.allowedStrategies,
  });

  final int tier;
  final int firstCycle;
  final List<SpawnPlacementStrategy> allowedStrategies;
}