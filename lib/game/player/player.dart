import 'dart:math';

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flame/extensions.dart';
import 'package:stardash/aural/audio_system.dart';
import 'package:stardash/core/atlas.dart';
import 'package:stardash/game/base/decals.dart';
import 'package:stardash/game/base/fake_three_d.dart';
import 'package:stardash/game/base/game_phase.dart';
import 'package:stardash/game/base/has_context.dart';
import 'package:stardash/game/base/kinds.dart';
import 'package:stardash/game/base/messages.dart';
import 'package:stardash/game/base/voxel_entity.dart';
import 'package:stardash/game/enemies/voxel_flipper.dart';
import 'package:stardash/game/enemies/voxel_spiker.dart';
import 'package:stardash/game/enemies/voxel_tanker.dart';
import 'package:stardash/game/level/level.dart';
import 'package:stardash/game/level/voxel_rotation.dart';
import 'package:stardash/game/projectiles/player_bullet.dart';
import 'package:stardash/input/keys.dart';
import 'package:stardash/util/auto_dispose.dart';
import 'package:stardash/util/log.dart';
import 'package:stardash/util/on_message.dart';

part 'player_firing.dart';
part 'player_movement.dart';

extension HasContextExtensions on HasContext {
  Player get player => cache.putIfAbsent('player', () => Player());
}

enum _State {
  destroyed,
  exploding,
  inactive,
  playing,
  teleporting_in,
  teleporting_out,
}

class Player extends PositionComponent
    with
        AutoDispose,
        CollisionCallbacks,
        HasContext,
        FakeThreeDee,
        HasVisibility,
        VoxelRotation,
        OnHit,
        Friendly,
        _PlayerMovement,
        _PlayerFiring {
  //
  int score = 0;

  bool _active = false;
  var _state = _State.inactive;
  var _state_time = 0.0;
  var _teleporting = 0.0;

  @override
  bool get _auto_pilot => switch (_state) {
        _State.teleporting_in => true,
        _State.teleporting_out => true,
        _ => false,
      };

  @override
  bool get _can_fire => !_auto_pilot;

  Player() : super() {
    anchor = Anchor.center;
    x_tilt_rotation.setRotationX(-pi / 6);
  }

  void update_transition(GamePhase phase, double progress) {
    if (!_active || _state == _State.exploding) {
      return;
    }

    switch (phase) {
      case GamePhase.entering_level:
        if (progress < 0.5) {
          if (_state != _State.teleporting_in) {
            decals.spawn3d(Decal.teleport, this);
          }
          _state = _State.teleporting_in;
          _state_time = (progress * 2).clamp(0.0, 1.0);
          _teleporting = (progress * 2).clamp(0.0, 1.0);
        } else {
          _state = _State.playing;
        }
      case GamePhase.playing_level:
        _state = _State.playing;
      case GamePhase.level_completed:
        _state = _State.playing;
      case GamePhase.leaving_level:
        if (progress > 0.75) {
          if (_state != _State.teleporting_out) {
            decals.spawn3d(Decal.teleport, this);
          }
          _state = _State.teleporting_out;
          _state_time = ((1 - progress) * 4).clamp(0.0, 1.0);
          _teleporting = ((1 - progress) * 4).clamp(0.0, 1.0);
        } else {
          _state = _State.playing;
        }
      case GamePhase.game_over:
        _state = _State.inactive;
    }
  }

  @override
  void on_hit(double damage) {
    if (is_dead) return;
    super.on_hit(damage);
    if (is_dead) {
      _state = _State.exploding;
      _state_time = 0.0;
      audio.play(Sound.explosion);
    } else {
      audio.play(Sound.clash);
    }
  }

  @override
  double get grid_z => 0.0;

  @override
  Future onLoad() async {
    super.onLoad();

    final voxel_image = atlas.sprite('voxel/manta19');
    voxel = VoxelEntity(
      voxel_image: voxel_image,
      height_frames: 19,
      exhaust_color: Color(0xFFff0037),
      parent_size: size,
    );
    voxel.model_scale.setValues(0.8, 0.2, 0.8);
    voxel.exhaust_length = 2;

    await add(voxel);

    voxel.set_exhaust_gradient(0, const Color(0xFF80ffff));
    voxel.set_exhaust_gradient(1, const Color(0xF000ffff));
    voxel.set_exhaust_gradient(2, const Color(0xE00080ff));
    voxel.set_exhaust_gradient(3, const Color(0xD00000ff));
    voxel.set_exhaust_gradient(4, const Color(0xC0000080));
  }

  @override
  void onMount() {
    int fuseball_count = 0;

    // Delayed super.onMount after level (data) is available:
    on_message<EnteringLevel>((it) {
      log_verbose('Entering level ${it.number}: ${level.data}');
      _active = true;
      fuseball_count = 0;
      voxel.exploding = 0.0;
      remaining_hit_points = max_hit_points = 10;
      super.onMount();
    });

    on_message<PlayingLevel>((it) {
      _state_time = 0.0;
      isVisible = true;
    });

    on_message<EnemyDestroyed>((it) {
      final t = it.target;
      if (t is VoxelFlipper) score += 150;
      if (t is VoxelTanker) score += 100;
      if (t is VoxelSpiker) score += 50;
      // if (t is VoxelPulsar) score += 200;
      // if (t is Fuseball) score += 250 * ++fuseball_count;
      log_info('Score: $score ($t)');
    });
  }

  @override
  void update(double dt) {
    if (_state == _State.destroyed || _state == _State.inactive) return;

    super.update(dt);

    voxel.render_mode = hit_time > 0 ? 1 : 0;

    final incoming = _state == _State.teleporting_in && _teleporting < 0.25;
    final outgoing = _state == _State.teleporting_out && _teleporting < 0.75;
    isVisible = !incoming && !outgoing;

    if (_state == _State.exploding) {
      if (hit_time > 0) {
        return;
      } else if (_state_time < 1.0) {
        _state_time += dt;
        voxel.exploding = _state_time;
      } else {
        _state = _State.destroyed;
      }
    }

    // if (isVisible && _phase == GamePhase.leaving_level) {
    //   // log_info('check spikes');
    //   final tiles = parent?.children.whereType<LevelTile>() ?? [];
    //   final spiked = tiles.where((it) => it.spikedness > 0);
    //   for (final it in spiked) {
    //     if (!it.is_spike_tip) continue;
    //     if ((it.center_grid_x - grid_x).abs() < 0.05) {
    //       final z = it.grid_z_bct.first;
    //       // final s_cross = 0.25 / z + 1.23;
    //       final s_cross = 0.50 / z + 0.82;
    //       final pz = z - (it.transition_scale - 1) * z * (s_cross - 1);
    //       // log_info('spike : $pz $s_cross ${it.grid_z_bct}');
    //       if ((pz - grid_z).abs() < 0.035) {
    //         log_info('player: $grid_z HIT HIT HIT');
    //       }
    //     }
    //   }
    // }
  }
}
