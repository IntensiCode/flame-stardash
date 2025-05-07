import 'package:flame/components.dart';
import 'package:flame/extensions.dart';
import 'package:stardash/aural/audio_system.dart';
import 'package:stardash/core/common.dart';
import 'package:stardash/game/base/enemy_type.dart';
import 'package:stardash/game/base/fake_three_d.dart';
import 'package:stardash/game/base/game_phase.dart';
import 'package:stardash/game/base/has_context.dart';
import 'package:stardash/game/base/kinds.dart';
import 'package:stardash/game/base/messages.dart';
import 'package:stardash/game/enemies/enemies.dart';
import 'package:stardash/game/enemies/shader_fuseball.dart';
import 'package:stardash/game/enemies/shader_pulsar.dart';
import 'package:stardash/game/enemies/spawn_event.dart';
import 'package:stardash/game/enemies/voxel_flipper.dart';
import 'package:stardash/game/enemies/voxel_spiker.dart';
import 'package:stardash/game/enemies/voxel_tanker.dart';
import 'package:stardash/game/level/level.dart';
import 'package:stardash/util/auto_dispose.dart';
import 'package:stardash/util/log.dart';
import 'package:stardash/util/on_message.dart';

extension HasContextExtensions on HasContext {
  EnemySpawner get spawner => cache.putIfAbsent('spawner', () => EnemySpawner());
}

class EnemySpawner extends Component with AutoDispose, HasContext {
  static const lane_delta = 0.05;

  final _sequence = <SpawnEvent>[];
  int _current_index = 0;
  double _time_until_next_spawn = 0.0;

  final _hostiles = <Hostile>[];

  bool _active = false;

  bool get defeated => _current_index >= _sequence.length && all_defeated;

  bool get all_defeated => _hostiles.every((it) => it.is_dead);

  bool _is_blocked_by(double grid_x, double grid_z, FakeThreeDee it) {
    if (it is VoxelFlipper && it.switch_start_x != null) {
      final x = it.switch_target_x!;
      final close = ((x - grid_x).abs() < lane_delta || (it.grid_x - grid_x).abs() < lane_delta);
      if (!close) return false;
    } else {
      final close = ((it.grid_x - grid_x).abs() < lane_delta);
      if (!close) return false;
    }
    return (it.grid.z - grid_z).abs() < lane_delta;
  }

  bool is_lane_free(double grid_x, double grid_z, {Component? self}) {
    for (final it in _hostiles) {
      if (it == self || it.is_dead) continue;
      if (_is_blocked_by(grid_x, grid_z, it as FakeThreeDee)) {
        return false;
      }
    }
    return true;
  }

  int tanker_spawn_count = 0;

  void spawn_from_tanker(VoxelTanker origin) {
    log_info('Spawning flippers');
    final spawn_x = origin.grid_x;
    final spawn_z = origin.grid_z + 0.1;
    if (level.number < 11) {
      _spawn_flippers(spawn_x, spawn_z);
    } else if (level.number < 14) {
      if (tanker_spawn_count.isEven) {
        _spawn_flippers(spawn_x, spawn_z);
      } else {
        _spawn_fuseballs(spawn_x, spawn_z);
      }
    } else {
      final idx = tanker_spawn_count % 3;
      if (idx == 0) {
        _spawn_flippers(spawn_x, spawn_z);
      } else if (idx == 1) {
        _spawn_fuseballs(spawn_x, spawn_z);
      } else {
        _spawn_pulsars(spawn_x, spawn_z);
      }
    }
    audio.play(Sound.emit);
    tanker_spawn_count++;
  }

  void _spawn_flippers(double spawn_x, double spawn_z) {
    final left = VoxelFlipper(x: spawn_x, y: spawn_z)..approach();
    final right = VoxelFlipper(x: spawn_x, y: spawn_z)..approach();
    parent?.addAll([left, right]);
    _hostiles.addAll([left, right]);
  }

  void _spawn_fuseballs(double spawn_x, double spawn_z) {
    final left = ShaderFuseball(x: spawn_x - 0.02, y: spawn_z)..approach();
    final right = ShaderFuseball(x: spawn_x + 0.02, y: spawn_z)..approach();
    parent?.addAll([left, right]);
    _hostiles.addAll([left, right]);
  }

  void _spawn_pulsars(double spawn_x, double spawn_z) {
    final left = ShaderPulsar(x: spawn_x - 0.02, y: spawn_z)..approach();
    final right = ShaderPulsar(x: spawn_x + 0.02, y: spawn_z)..approach();
    parent?.addAll([left, right]);
    _hostiles.addAll([left, right]);
  }

  void convert_into_tanker(VoxelSpiker origin) {
    final it = VoxelTanker(x: origin.grid_x);
    parent?.addAll([it]);
    _hostiles.addAll([it]);
    audio.play(Sound.emit);
  }

  @override
  void onMount() {
    super.onMount();
    on_message<EnteringLevel>((it) {
      tanker_spawn_count = 0;
      _hostiles.clear();
      _sequence.clear();
    });
    on_message<PlayingLevel>((it) {
      _active = true;
      _hostiles.clear();
      _sequence.addAll(enemies.enemies(it.number));
      log_verbose('Playing level ${it.number}: ${_sequence.length} enemies');
      _current_index = 0;
      _time_until_next_spawn = _sequence[_current_index].time_offset;
    });
    on_message<LeavingLevel>((it) {
      _sequence.clear();
      _hostiles.clear();
    });
    on_message<GamePhaseUpdate>((it) => _active = it.phase == GamePhase.playing_level);
    on_message<SuperZapper>((it) => _on_zapped(it.all));
  }

  void _on_zapped(bool all) {
    if (all) {
      final all = [..._hostiles];
      for (final it in all) {
        if (it is ShaderPulsar) continue;
        it.on_hit(it.remaining_hit_points);
      }
    } else {
      var alive = _hostiles.where((it) => !it.is_dead && it is! ShaderPulsar).toList();
      if (alive.isNotEmpty) {
        final which = alive.random(level_rng);
        which.on_hit(which.remaining_hit_points);
      }
    }
  }

  @override
  void update(double dt) {
    super.update(dt);

    if (!_active || _current_index >= _sequence.length) {
      return;
    }

    _time_until_next_spawn -= dt;

    while (_time_until_next_spawn <= 0) {
      final currentEvent = _sequence[_current_index];
      _spawn_next_enemy(currentEvent);

      _current_index++;

      if (_current_index < _sequence.length) {
        final nextTimeOffset = _sequence[_current_index].time_offset;
        _time_until_next_spawn += nextTimeOffset;
      } else {
        _time_until_next_spawn = double.infinity;
        log_debug('Level enemy sequence complete.');
        break;
      }
    }
  }

  void _spawn_next_enemy(SpawnEvent event) {
    log_verbose('Spawning enemy: $event');
    final it = switch (event.enemy_type) {
      EnemyType.Flipper => VoxelFlipper(x: event.grid_x, y: event.grid_z),
      EnemyType.Tanker => VoxelTanker(x: event.grid_x, z: event.grid_z),
      EnemyType.Spiker => VoxelSpiker(x: event.grid_x, z: event.grid_z),
      EnemyType.Fuseball => ShaderFuseball(x: event.grid_x, y: event.grid_z),
      EnemyType.Pulsar => ShaderPulsar(x: event.grid_x, y: event.grid_z),
    };
    parent?.add(it);
    _hostiles.add(it);
  }
}
