import 'package:flame/components.dart';
import 'package:stardash/core/common.dart';
import 'package:stardash/game/base/enemy_type.dart';
import 'package:stardash/game/base/has_context.dart';
import 'package:stardash/game/enemies/spawn_event.dart';
import 'package:stardash/game/level/level.dart';
import 'package:stardash/util/log.dart';

extension HasContextExtensions on HasContext {
  Enemies get enemies => cache.putIfAbsent('enemies', () => Enemies());
}

class Enemies extends Component with HasContext {
  List<SpawnEvent> enemies(int level_number) {
    final first = [...level.snap_points];
    final second = [...level.snap_points];
    first.shuffle(level_rng);
    first.shuffle(level_rng);
    second.shuffle(level_rng);
    final free = first + second;

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

    SpawnEvent _fuseball(double time) => SpawnEvent(
          enemy_type: EnemyType.Fuseball,
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
    // Level 11 introduces fuseballs.
    // Level 14 introduces pulsars.

    final flippers = level_number <= 2 ? 4 : 2;
    final tankers = (level_number - 2).clamp(0, 4);
    final spikers = (level_number - 3).clamp(0, 4);
    final fuseballs = ((level_number - 11 + 2) ~/ 2).clamp(0, 2);
    final pulsars = ((level_number - 14 + 2) ~/ 2).clamp(0, 2);
    final count = flippers + tankers + spikers + fuseballs + pulsars;

    var delta = (3.0 / count).clamp(0.25, 0.5);
    delta += level_number * 0.01;
    delta = delta.clamp(0.25, 1.0);
    log_info('delta: $delta count: $count raw: ${3 / count}');

    return [
      for (int i = 0; i < flippers; i++) _flipper((i - 1).clamp(0, 2) * delta),
      for (int i = 0; i < tankers; i++) _tanker(i * delta),
      for (int i = 0; i < spikers; i++) _spiker(i * delta * 0.71),
      for (int i = 0; i < fuseballs; i++) _fuseball(i * delta * 0.83),
      for (int i = 0; i < pulsars; i++) _pulsar(i * delta * 0.37),
    ];
  }
}
