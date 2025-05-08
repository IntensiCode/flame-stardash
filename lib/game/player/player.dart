import 'dart:math';

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flame/extensions.dart';
import 'package:stardash/aural/audio_system.dart';
import 'package:stardash/core/common.dart';
import 'package:stardash/game/base/decals.dart';
import 'package:stardash/game/base/fake_three_d.dart';
import 'package:stardash/game/base/game_phase.dart';
import 'package:stardash/game/base/has_context.dart';
import 'package:stardash/game/base/kinds.dart';
import 'package:stardash/game/base/messages.dart';
import 'package:stardash/game/base/voxel_entity.dart';
import 'package:stardash/game/enemies/shader_fuseball.dart';
import 'package:stardash/game/enemies/shader_pulsar.dart';
import 'package:stardash/game/enemies/voxel_flipper.dart';
import 'package:stardash/game/enemies/voxel_spiker.dart';
import 'package:stardash/game/enemies/voxel_tanker.dart';
import 'package:stardash/game/level/level.dart';
import 'package:stardash/game/level/voxel_rotation.dart';
import 'package:stardash/game/projectiles/player_bullet.dart';
import 'package:stardash/input/keys.dart';
import 'package:stardash/util/auto_dispose.dart';
import 'package:stardash/util/game_data.dart';
import 'package:stardash/util/log.dart';
import 'package:stardash/util/on_message.dart';

part 'player_firing.dart';
part 'player_movement.dart';

int enemy_score_fuseball_count = 0;

// TODO: move to EnemyType and link without runtime type?
int enemy_score(Type t) {
  if (t == VoxelFlipper) return 150;
  if (t == VoxelTanker) return 100;
  if (t == VoxelSpiker) return 50;
  if (t == ShaderPulsar) return 200;
  if (t == ShaderFuseball) return 250 * ++enemy_score_fuseball_count;
  return 0;
}

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
        HasGameData,
        FakeThreeDee,
        HasVisibility,
        VoxelRotation,
        OnHit,
        Friendly,
        _PlayerMovement,
        _PlayerFiring {
  //
  int lives = 5;
  int score = 0;

  bool _active = false;
  var state = _State.inactive;
  var _state_time = 0.0;
  var _teleporting = 0.0;

  @override
  bool get _auto_pilot => switch (state) {
        _State.teleporting_in => true,
        _State.teleporting_out => true,
        _ => false,
      };

  @override
  bool get _can_fire => state == _State.playing;

  Player() : super() {
    anchor = Anchor.center;
    x_tilt_rotation.setRotationX(-pi / 6);
    remaining_hit_points = max_hit_points = 10;
  }

  @override
  void load_state(GameData data) {
    log_info('load player: $data');

    lives = data['lives'] ?? 5;
    score = data['score'] ?? 0;
    remaining_hit_points = data['remaining_hit_points'] ?? max_hit_points;
  }

  @override
  GameData save_state(GameData data) {
    data['lives'] = lives;
    data['score'] = score;
    data['remaining_hit_points'] = remaining_hit_points;
    log_info('save player: $data');
    return data;
  }

  void update_transition(GamePhase phase, double progress) {
    if (!_active || state == _State.exploding || state == _State.destroyed) {
      return;
    }

    switch (phase) {
      case GamePhase.entering_level:
        if (progress < 0.5) {
          if (state != _State.teleporting_in) {
            decals.spawn3d(Decal.teleport, this);
          }
          state = _State.teleporting_in;
          _state_time = (progress * 2).clamp(0.0, 1.0);
          _teleporting = (progress * 2).clamp(0.0, 1.0);
        } else {
          state = _State.playing;
        }

      case GamePhase.playing_level:
        state = _State.playing;

      case GamePhase.level_completed:
        state = _State.playing;

      case GamePhase.leaving_level:
        if (progress > 0.75) {
          if (state != _State.teleporting_out) {
            decals.spawn3d(Decal.teleport, this);
          }
          state = _State.teleporting_out;
          _state_time = ((1 - progress) * 4).clamp(0.0, 1.0);
          _teleporting = ((1 - progress) * 4).clamp(0.0, 1.0);
        } else {
          state = _State.playing;
        }

      case GamePhase.game_over:
        state = _State.inactive;

      case GamePhase.live_lost:
        state = _State.inactive;
    }
  }

  @override
  void on_hit(double damage) {
    if (is_dead) return;
    super.on_hit(damage);
    if (is_dead) {
      if (lives > 0) lives--;
      log_info('Player died: lives=$lives');
      state = _State.exploding;
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

    voxel = VoxelEntity(
      voxel_image: await images.load('voxel/manta19.png'),
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
    // Delayed super.onMount after level (data) is available in _enter_level:
    on_message<EnteringLevel>((it) => _enter_level(it));
    on_message<PlayingLevel>((it) => _playing_level());
    on_message<EnemyDestroyed>((it) => _score(it));
  }

  void _enter_level(EnteringLevel it) {
    log_verbose('Entering level ${it.number}: ${level.data}');
    _active = true;
    voxel.exploding = 0.0;
    enemy_score_fuseball_count = 0;
    remaining_hit_points = max_hit_points;
    super_zappers = 2;
    super.onMount();
  }

  void _playing_level() {
    _state_time = 0.0;
    isVisible = true;
  }

  void _score(EnemyDestroyed it) {
    if (!it.score) return;

    final old_score = score;
    score += enemy_score(it.target.runtimeType);
    final lives_before = old_score ~/ 10000;
    final lives_after = score ~/ 10000;
    if (lives_after > lives_before) {
      lives++;
      audio.play(Sound.bonus);
    }
  }

  double _zap_smoke_time = 0.0;

  @override
  void update(double dt) {
    switch (state) {
      case _State.destroyed:
        return;

      case _State.exploding:
        if (hit_time > 0) {
          break;
        } else if (_state_time < 1.0) {
          _state_time += dt;
          voxel.exploding = _state_time;
        } else {
          state = lives > 0 ? _State.inactive : _State.destroyed;
          send_message(PlayerDestroyed(game_over: lives == 0));
          return;
        }

      case _State.inactive:
        return;

      case _State.playing:
        isVisible = true;

        final zapped = level.is_electrified(grid_x);
        if (zapped) _on_zapped(dt);

        final spiked = level.is_tile_spiked(grid_x, grid_z);
        if (spiked) _on_zapped(dt);

      case _State.teleporting_in:
        isVisible = _teleporting > 0.25;

      case _State.teleporting_out:
        isVisible = _teleporting > 0.75;
    }

    super.update(dt);

    voxel.render_mode = hit_time > 0 ? 1 : 0;
  }

  void _on_zapped(double dt) {
    if (_zap_smoke_time <= 0.0) {
      on_hit(0.4);
      _zap_smoke_time += 0.1;
      final it = decals.spawn3d(Decal.smoke, this, pos_range: 32, vel_range: 0);
      it.velocity.setFrom(target_depth);
      it.velocity.scale(-32);
    } else {
      _zap_smoke_time -= dt;
    }
  }
}
