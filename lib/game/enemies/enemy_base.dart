import 'dart:math';

import 'package:flame/components.dart';
import 'package:stardash/aural/audio_system.dart';
import 'package:stardash/core/common.dart';
import 'package:stardash/game/base/decals.dart';
import 'package:stardash/game/base/fake_three_d.dart';
import 'package:stardash/game/base/has_context.dart';
import 'package:stardash/game/base/kinds.dart';
import 'package:stardash/game/base/messages.dart';
import 'package:stardash/game/enemies/pulse_bullet.dart';
import 'package:stardash/game/level/level.dart';
import 'package:stardash/game/player/player.dart';
import 'package:supercharged/supercharged.dart';

enum EnemyState {
  materializing,
  approaching,
  receding,
  switching_lane,
  leaving,
  exploding,
}

class EnemyBase extends PositionComponent with HasContext, HasPaint, HasVisibility, FakeThreeDee, OnHit, Hostile {
  //

  EnemyState state = EnemyState.materializing;
  double state_time = 0;
  bool teleported = false;
  bool smoke_when_destroyed = true;

  double player_close_damage = 0.1;

  EnemyBase() : super() {
    anchor = Anchor.center;
  }

  @override
  void update(double dt) {
    super.update(dt);
    level.map_grid_to_screen(grid_x, grid_z, out: position);

    if (!is_dead && grid_z < 0.1 && player.is_affected_by(this)) {
      player.on_hit(player_close_damage);
    }
  }

  @override
  bool is_affected_by(FakeThreeDee other) {
    if (is_dead) return false;
    return super.is_affected_by(other);
  }

  @override
  void on_hit(double damage) {
    if (is_dead || isRemoving || state == EnemyState.exploding) return;

    super.on_hit(damage);
    if (remaining_hit_points > 0) return;

    explode();
  }

  void on_materialize(double dt) {
    if (!teleported) {
      teleported = true;
      decals.spawn3d(Decal.teleport, this);
      audio.play(Sound.teleport);
    }
    if (state_time >= 0.5) {
      approach();
    } else {
      isVisible = state_time > 0.25;
    }
  }

  void approach() {
    if (state == EnemyState.approaching) return;
    state = EnemyState.approaching;
    state_time = 0.0;
    isVisible = true;
  }

  void recede() {
    if (state == EnemyState.receding) return;
    state = EnemyState.receding;
    state_time = 0.0;
  }

  void switch_lane() {
    if (state == EnemyState.switching_lane) return;
    state = EnemyState.switching_lane;
    state_time = 0.0;
  }

  void leave() {
    if (state == EnemyState.leaving) return;
    state = EnemyState.leaving;
    state_time = 0.0;
    teleported = false;
  }

  void on_leaving(double dt) {
    if (!teleported) {
      teleported = true;
      decals.spawn3d(Decal.teleport, this);
      audio.play(Sound.teleport);
    }
    if (state_time >= 0.5) {
      state_time = 0.5;
      removeFromParent();
    }
    isVisible = state_time < 0.25;
  }

  void explode() {
    if (state == EnemyState.exploding) return;
    state = EnemyState.exploding;
    state_time = 0.0;
    if (smoke_when_destroyed) {
      4.times(() => decals.spawn3d(Decal.smoke, this, pos_range: size.x / 3));
    }
    on_destroyed();
  }

  void on_destroyed() {
    send_message(EnemyDestroyed(this));
    audio.play(Sound.explosion_hollow);
  }

  void on_explode(double dt) {
    if (hit_time > 0) return;
    if (state_time >= 1) {
      isVisible = false;
      if (!isRemoving) removeFromParent();
    }
  }

  double _fire_cooldown = 0.0;
  PulseBullet? _active_bullet;

  void fire_pulse_bullet_when_ready(double dt) {
    _fire_cooldown = max(0.0, _fire_cooldown - dt);
    if (_fire_cooldown > 0.0) return;
    if (_active_bullet?.isMounted ?? false) return;
    if (grid_z < 0.4 || grid_z > 0.8) return;
    if (level_rng.nextDouble() > 0.005) return;
    _fire_cooldown = 1.0 / 3;
    parent?.add(_active_bullet = PulseBullet(x: grid_x, z: grid_z));
  }
}
