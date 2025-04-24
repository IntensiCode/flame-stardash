part of 'player.dart';

mixin _PlayerFiring on HasContext, HasFakeThreeDee {
  bool _can_fire = true;

  @override
  void update(double dt) {
    super.update(dt);
    if (_can_fire) _handle_firing(dt);
  }

  // --- Firing State ---
  static const double _fire_cooldown = 0.2; // Seconds between shots
  double _fire_timer = 0.0;
  bool _fire_left = true; // Flag to alternate sides
  static const double _bullet_spawn_offset_x = 0.01; // Small horizontal offset

  void _handle_firing(double dt) {
    if (_fire_timer > 0) {
      _fire_timer -= dt;
    }
    if (keys.check(GameKey.a_button) && _fire_timer <= 0) {
      _fire_bullet();
      _fire_timer = _fire_cooldown;
    }
  }

  void _fire_bullet() {
    audio.play(Sound.shot1, volume_factor: 0.5);

    // Calculate spawn X with alternating offset
    final spawn_offset = _fire_left ? -_bullet_spawn_offset_x : _bullet_spawn_offset_x;
    final spawn_grid_x = grid_x + spawn_offset;

    // Create bullet at the calculated grid X
    final bullet = PlayerBullet(initial_grid_x: spawn_grid_x);

    // Add to parent
    parent?.add(bullet);

    // Toggle side for next shot
    _fire_left = !_fire_left;
  }
}
