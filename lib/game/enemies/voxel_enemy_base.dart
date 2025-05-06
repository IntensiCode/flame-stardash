import 'dart:math';
import 'dart:ui';

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flame/extensions.dart';
import 'package:flutter/rendering.dart';
import 'package:stardash/aural/audio_system.dart';
import 'package:stardash/core/common.dart';
import 'package:stardash/game/base/decals.dart';
import 'package:stardash/game/base/fake_three_d.dart';
import 'package:stardash/game/base/has_context.dart';
import 'package:stardash/game/base/kinds.dart';
import 'package:stardash/game/base/messages.dart';
import 'package:stardash/game/enemies/pulse_bullet.dart';
import 'package:stardash/game/level/level.dart';
import 'package:stardash/game/level/voxel_rotation.dart';
import 'package:supercharged/supercharged.dart';

enum VoxelEnemyState {
  materializing,
  approaching,
  receding,
  switching_lane,
  leaving,
  exploding,
}

class VoxelEnemyBase extends PositionComponent
    with HasContext, HasVisibility, FakeThreeDee, OnHit, Hostile, VoxelRotation {
  late final CircleHitbox _hitbox;

  VoxelEnemyState state = VoxelEnemyState.materializing;
  double state_time = 0;
  bool teleported = false;

  VoxelEnemyBase() : super() {
    anchor = Anchor.center;
    add(_hitbox = CircleHitbox(radius: 8, isSolid: true, anchor: Anchor.topLeft));
    x_tilt_rotation.setRotationX(-pi - pi / 12);
  }

  void set_exhaust_gradient_post_load() {
    voxel.set_exhaust_gradient(0, const Color(0xFFFF8000));
    voxel.set_exhaust_gradient(1, const Color(0xFFFF0000));
    voxel.set_exhaust_gradient(2, const Color(0xFFA00000));
    voxel.set_exhaust_gradient(3, const Color(0xFF800000));
    voxel.set_exhaust_gradient(4, const Color(0xFF600000));
  }

  @override
  Future onLoad() async {
    await super.onLoad();
    await add(voxel);
    set_exhaust_gradient_post_load();
  }

  @override
  void update(double dt) {
    super.update(dt);
    _hitbox.radius = size.x / 2;
    voxel.render_mode = hit_time > 0 ? 1 : 0;
    level.map_grid_to_screen(grid_x, grid_z, out: position);
  }

  @override
  bool is_affected_by(FakeThreeDee other) {
    if (is_dead) return false;
    return super.is_affected_by(other);
  }

  @override
  void on_hit(double damage) {
    if (is_dead || isRemoving || state == VoxelEnemyState.exploding) return;

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
    if (state == VoxelEnemyState.approaching) return;
    state = VoxelEnemyState.approaching;
    state_time = 0.0;
    isVisible = true;
  }

  void recede() {
    if (state == VoxelEnemyState.receding) return;
    state = VoxelEnemyState.receding;
    state_time = 0.0;
  }

  void switch_lane() {
    if (state == VoxelEnemyState.switching_lane) return;
    state = VoxelEnemyState.switching_lane;
    state_time = 0.0;
  }

  void leave() {
    if (state == VoxelEnemyState.leaving) return;
    state = VoxelEnemyState.leaving;
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
    if (state == VoxelEnemyState.exploding) return;
    state = VoxelEnemyState.exploding;
    state_time = 0.0;
    4.times(() => decals.spawn3d(Decal.smoke, this, pos_range: size.x / 3));
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
    } else {
      voxel.exploding = state_time;
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
