import 'package:flame/components.dart';
import 'package:stardash/core/common.dart';
import 'package:stardash/game/base/has_context.dart';
import 'package:stardash/game/base/enemy_type.dart';
import 'package:stardash/game/enemies/spawn_event.dart';
import 'package:stardash/game/level/level.dart';

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

    // Level 1 and 2 have flippers only. Will start flipping early in level 2.
    if (level_number <= 2) {
      return [for (int i = 0; i < 4; i++) _flipper(i * 0.5)];
    }

    // Level 3 introduces tankers. But only two flippers at start.
    if (level_number == 3) {
      return [_flipper(0.0), _flipper(0.5), _tanker(1.0), _tanker(1.5)];
    }

    return [_flipper(0.0), _flipper(0.25), _spiker(0.5), _tanker(0.75), _tanker(1.0)];
  }
}
