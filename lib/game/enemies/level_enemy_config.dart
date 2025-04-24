import 'package:stardash/game/enemies/enemy_type.dart';

class LevelEnemyConfig {
  LevelEnemyConfig(this.enemyWeights);

  /// Weights indicating relative frequency/intensity for each enemy type.
  final Map<EnemyType, double> enemyWeights;
} 