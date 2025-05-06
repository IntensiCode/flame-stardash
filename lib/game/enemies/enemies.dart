import 'package:flame/components.dart';
import 'package:stardash/core/common.dart';
import 'package:stardash/game/base/enemy_type.dart';
import 'package:stardash/game/base/has_context.dart';
import 'package:stardash/game/enemies/spawn_event.dart';
import 'package:stardash/game/level/level.dart';
import 'package:stardash/game/level/level_data.dart';
import 'package:stardash/util/log.dart';

extension HasContextExtensions on HasContext {
  Enemies get enemies => cache.putIfAbsent('enemies', () => Enemies());
}

class Enemies extends Component with HasContext {
  List<SpawnEvent> enemies(int level_number) {
    final free = [...level.snap_points];
    free.shuffle(level_rng);
    free.shuffle(level_rng);

    SpawnEvent _flipper(double time) => SpawnEvent(
          enemy_type: EnemyType.Flipper,
          time_offset: time,
          grid_x: free.removeLast(),
        );

    SpawnEvent _tanker(double time) => SpawnEvent(
          enemy_type: EnemyType.Tanker,
          time_offset: time,
          grid_x: free.removeLast(),
        );

    SpawnEvent _spiker(double time) => SpawnEvent(
          enemy_type: EnemyType.Spiker,
          time_offset: time,
          grid_x: free.removeLast(),
        );

    SpawnEvent _pulsar(double time) => SpawnEvent(
          enemy_type: EnemyType.Pulsar,
          time_offset: time,
          grid_x: free.removeLast(),
        );

    // Level 1 and 2 have flippers only. Will start flipping early in level 2.
    // Level 3 introduces tankers. But only two flippers from now on.
    // Level 4 introduces spikers.

    final flippers = level_number <= 2 ? 4 : 2;
    final tankers = (level_number - 2).clamp(0, 4);
    final spikers = (level_number - 3).clamp(0, 4);
    final pulsars = ((level_number - LevelData.values.length + 1) ~/ 2).clamp(0, 4);
    var count = flippers + tankers + spikers + pulsars;

    final delta = (3.0 / count).clamp(0.25, 0.5);
    log_info('delta: $delta count: $count raw: ${3 / count}');

    return [
      for (int i = 0; i < flippers; i++) _flipper(i * delta),
      for (int i = 0; i < tankers; i++) _tanker(i * delta),
      for (int i = 0; i < spikers; i++) _spiker(i * delta),
      for (int i = 0; i < pulsars; i++) _pulsar(i * delta),
    ];
  }
}
