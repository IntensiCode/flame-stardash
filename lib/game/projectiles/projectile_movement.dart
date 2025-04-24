import 'dart:math';

import 'package:flame/components.dart';
import 'package:stardash/game/base/decals.dart';
import 'package:stardash/game/base/fake_three_d.dart';
import 'package:stardash/game/base/has_context.dart';
import 'package:stardash/game/base/kinds.dart';
import 'package:stardash/game/level/level.dart';
import 'package:stardash/game/level/level_transition.dart';

/// Mixin to handle projectile movement along the Z-axis and raycast collision.
///
/// Requires the component to also have [FakeThreeDee] and [HasContext].
/// The using class must implement [projectile_speed], [projectile_remove_z],
/// and [projectile_damage].
mixin ProjectileMovement on PositionComponent, FakeThreeDee, HasContext, HasVisibility {
  late double projectile_speed;
  late double projectile_remove_z;
  late double projectile_damage;

  bool active = false;

  double _previous_grid_z = 0;

  bool is_target(Component c);

  void reset() {
    grid_x = 0.0;
    grid_z = 0.0;
    active = false;
    isVisible = false;
  }

  void activate(double at_x) {
    grid_x = level.snap_to_grid(at_x);
    grid_z = 0;
    level.map_grid_to_screen(grid_x, grid_z, clamp_and_wrap_x: false, out: position);
    active = true;
    isVisible = true;
  }

  @override
  void update(double dt) {
    if (!active) return;

    _previous_grid_z = grid_z;

    // Move along Z axis
    grid_z += projectile_speed * dt;
    if (grid_z >= projectile_remove_z + LevelTransition.translation_z) {
      decals.spawn3d(Decal.sparkle, this);
      active = false;
      isVisible = false;
      return;
    }

    // Perform raycast collision check for this step
    final collision_occurred = _check_raycast_collisions();
    if (collision_occurred) {
      active = false;
      isVisible = false;
      return;
    }

    // Update screen position *after* potential removal
    level.map_grid_to_screen(grid_x, grid_z, out: position, clamp_and_wrap_x: false);

    // Call super.update AFTER updating position and handling potential removal.
    // This allows other mixins/base class logic (like rendering updates) to use the final position.
    super.update(dt);
  }

  /// Checks for collisions along the path from [prev_z] to [current_z].
  /// Returns true if a collision occurred and the projectile should be removed.
  bool _check_raycast_collisions() {
    final targets = parent?.children;
    if (targets == null) return false;

    final saved_z = grid_z;

    final projectile_z_min = min(_previous_grid_z, grid_z);
    final projectile_z_max = max(_previous_grid_z, grid_z);
    final z_dist = (projectile_z_max - projectile_z_min);
    final z = projectile_z_max - z_dist;

    for (final target in targets) {
      if (target is! OnHit) continue;
      if (target is! FakeThreeDee) continue;
      if (!is_target(target)) continue;

      // Target must be FakeThreeDee to have grid coordinates
      final it = target as FakeThreeDee;

      // Check X/Y proximity using the target's hit delta
      final hit_delta = target.hit_3d_delta;
      if ((it.grid_x - grid_x).abs() >= hit_delta) continue;

      // Check if the target's Z position is within the projectile's movement segment
      if ((it.grid_z - z).abs() >= z_dist + hit_delta) continue;

      // Check if the target is specifically affected (allows target to ignore certain hits)
      // Snap projectile Z to the target's exact Z for the is_affected_by check and potential effects
      grid_z = it.grid_z;
      if (target.is_affected_by(this)) {
        target.on_hit(projectile_damage);
        return true;
      }
    }

    grid_z = saved_z;

    return false;
  }
}
