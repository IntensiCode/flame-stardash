import 'dart:math';
import 'dart:ui';

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flame/extensions.dart';
import 'package:stardash/aural/audio_system.dart';
import 'package:stardash/core/atlas.dart';
import 'package:stardash/core/common.dart';
import 'package:stardash/game/base/fake_three_d.dart';
import 'package:stardash/game/base/game_phase.dart';
import 'package:stardash/game/base/has_context.dart';
import 'package:stardash/game/base/kinds.dart';
import 'package:stardash/game/base/messages.dart';
import 'package:stardash/game/base/voxel_entity.dart';
import 'package:stardash/game/level/level.dart';
import 'package:stardash/game/player/player_bullet.dart';
import 'package:stardash/input/keys.dart';
import 'package:stardash/util/auto_dispose.dart';
import 'package:stardash/util/log.dart';
import 'package:stardash/util/on_message.dart';

part 'player_firing.dart';
part 'player_movement.dart';

extension HasContextExtensions on HasContext {
  Player get player => cache.putIfAbsent('player', () => Player());
}

class Player extends PositionComponent
    with AutoDispose, HasContext, HasFakeThreeDee, _PlayerMovement, _PlayerFiring, OnHit, Friendly {
  //

  bool _active = false;

  Player() : super() {
    anchor = Anchor.center;
    size.setAll(80);
    priority = 1000;
    add(CircleHitbox(radius: size.x * 0.25, anchor: Anchor.center, position: size / 2));
  }

  void update_transition(GamePhase phase, double progress) {
    _can_fire = phase == GamePhase.playing_level;
    _auto_pilot = phase == GamePhase.entering_level || phase == GamePhase.leaving_level;
  }

  @override
  void on_hit(double damage) {
    super.on_hit(damage);
    log_warn('Player hit for $damage');
  }

  @override
  double get grid_y => 0.0; // Player moves along the Z=0 plane

  @override
  double get grid_z => 0.0; // Player is always at Z=0

  @override
  Future onLoad() async {
    final voxel_image = atlas.sprite('voxel/manta19');
    _voxel = VoxelEntity(
      voxel_image: voxel_image,
      height_frames: 19,
      exhaust_color: Color(0xFFff0037),
      parent_size: size,
    );
    _voxel.model_scale.setValues(0.8, 0.2, 0.8);
    _voxel.exhaust_length = 2;
    await add(_voxel);
    _voxel.set_exhaust_color(0, const Color(0xFF80ffff));
    _voxel.set_exhaust_color(1, const Color(0xF000ffff));
    _voxel.set_exhaust_color(2, const Color(0xE00080ff));
    _voxel.set_exhaust_color(3, const Color(0xD00000ff));
    _voxel.set_exhaust_color(4, const Color(0xC0000080));
  }

  @override
  void onMount() {
    on_message<EnteringLevel>((it) {
      log_info('Entering level ${it.number}');
      if (it.number == 1) _on_enter_level(); // initial positioning
    });
  }

  void _on_enter_level() {
    // Get the calculated starting gridX from the level logic
    grid_x = level.find_start_x();
    log_info('Player mounting with gridX: $grid_x');

    _current_grid_speed = 0.0;
    position.setFrom(level.map_grid_to_screen(grid_x, 0.0));

    // Initialize smoothed vectors using the final gridX
    level.get_orientation_normal(grid_x, out: _smoothed_normal);
    level.get_depth_vector(grid_x, out: _smoothed_depth);
    _wobble_anim = 0;
    _update_orientation();

    _active = true;
  }

  @override
  void update(double dt) {
    if (!_active) return;
    super.update(dt);
    _voxel.render_mode = hit_time > 0 ? 1 : 0;
  }
}
