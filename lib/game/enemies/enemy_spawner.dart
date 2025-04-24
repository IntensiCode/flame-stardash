import 'package:flame/components.dart';
import 'package:stardash/game/base/game_phase.dart';
import 'package:stardash/game/base/has_context.dart';
import 'package:stardash/game/base/messages.dart';
import 'package:stardash/game/enemies/crawler.dart';
import 'package:stardash/game/enemies/enemy_type.dart';
import 'package:stardash/game/enemies/flipper.dart';
import 'package:stardash/game/enemies/pulse_sentry.dart';
import 'package:stardash/game/enemies/skimmer.dart';
import 'package:stardash/game/enemies/spawn_event.dart';
import 'package:stardash/game/levels.dart';
import 'package:stardash/util/auto_dispose.dart';
import 'package:stardash/util/log.dart';
import 'package:stardash/util/on_message.dart';

class EnemySpawner extends Component with AutoDispose, HasContext {
  var _active = true;
  var _spawnSequence = <SpawnEvent>[];
  var _currentSpawnIndex = 0;
  var _timeUntilNextSpawn = double.infinity;

  @override
  void onMount() {
    super.onMount();
    on_message<PlayingLevel>((it) {
      log_debug('Entering level ${it.number}');
      _active = true;
      _spawnSequence = levels.enemies(it.number);
      log_verbose('spawn sequence: $_spawnSequence');
      _currentSpawnIndex = 0;
      _resetTimerForNextSpawn();
    });
    on_message<GamePhaseUpdate>((it) => _active = it.phase == GamePhase.playing_level);
  }

  void _resetTimerForNextSpawn() {
    if (_currentSpawnIndex < _spawnSequence.length) {
      _timeUntilNextSpawn = _spawnSequence[_currentSpawnIndex].timeOffset;
    } else {
      _timeUntilNextSpawn = double.infinity;
      if (_spawnSequence.isNotEmpty) {
        log_info('Level enemy sequence complete.');
      }
    }
  }

  @override
  void update(double dt) {
    super.update(dt);

    if (!_active || _currentSpawnIndex >= _spawnSequence.length) {
      return;
    }

    _timeUntilNextSpawn -= dt;

    while (_timeUntilNextSpawn <= 0) {
      final currentEvent = _spawnSequence[_currentSpawnIndex];
      _spawnEnemy(currentEvent);

      _currentSpawnIndex++;

      if (_currentSpawnIndex < _spawnSequence.length) {
        final nextTimeOffset = _spawnSequence[_currentSpawnIndex].timeOffset;
        _timeUntilNextSpawn += nextTimeOffset;
      } else {
        _timeUntilNextSpawn = double.infinity;
        log_debug('Level enemy sequence complete.');
        break;
      }
    }
  }

  void _spawnEnemy(SpawnEvent event) {
    final Component? enemyComponent = _createEnemyComponent(event.enemyType, event.gridX);
    assert(enemyComponent != null, 'No component implemented for enemy type ${event.enemyType}');
    log_verbose('Spawning enemy: $enemyComponent parent: $parent');
    parent?.add(enemyComponent!);
  }

  Component? _createEnemyComponent(EnemyType type, double grid_x) {
    switch (type) {
      case EnemyType.Crawler:
        return CrawlerComponent(grid_x: grid_x);
      case EnemyType.PulseSentry:
        return PulseSentryComponent(grid_x: grid_x);
      case EnemyType.Skimmer:
        return SkimmerComponent(start_grid_x: grid_x, start_grid_z: 1.0);
      case EnemyType.Flipper:
        return FlipperComponent(start_grid_x: grid_x, start_grid_z: 1.0);
      default:
        log_warn('Warning: No component implemented for enemy type $type');
        // TODO: For now only crawlers! :D
        return CrawlerComponent(grid_x: grid_x);
    }
  }
}
