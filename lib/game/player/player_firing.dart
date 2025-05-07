part of 'player.dart';

mixin _PlayerFiring on HasContext, FakeThreeDee {
  static const double _fire_cooldown = 0.15;
  static const double _super_zapper_cooldown = 1.0;
  static const int _max_bullets = 5;

  final _bullets = List.generate(_max_bullets, (i) => PlayerBullet(), growable: false);

  int super_zappers = 2;

  double _fire_timer = 0.0;
  double _super_zapper_fire_timer = 0.0;

  bool get _can_fire;

  @override
  void onLoad() {
    super.onLoad();
    _bullets.forEach((it) => parent?.add(it));
  }

  @override
  void onMount() {
    super.onMount();
    _bullets.forEach((it) => it.reset());
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (_fire_timer > 0) _fire_timer -= dt;
    if (_super_zapper_fire_timer > 0) _super_zapper_fire_timer -= dt;
    if (_can_fire) _handle_firing(dt);
  }

  void _handle_firing(double dt) {
    if (keys.check(GameKey.a_button)) {
      if (_fire_timer <= 0) {
        _fire_next_bullet();
      }
    }

    if (keys.check(GameKey.b_button) && super_zappers > 0) {
      if (_super_zapper_fire_timer <= 0) {
        _fire_super_zapper();
      }
    }
  }

  void _fire_super_zapper() {
    send_message(SuperZapper(all: super_zappers == 2));
    super_zappers--;
    _super_zapper_fire_timer = _super_zapper_cooldown;
    audio.play(Sound.flash);
  }

  void _fire_next_bullet() {
    for (final it in _bullets) {
      if (it.active) continue;
      _fire_bullet(it);
      _fire_timer = _fire_cooldown;
      break;
    }
  }

  void _fire_bullet(PlayerBullet it) {
    audio.play(Sound.shot1, volume_factor: 0.5);
    it.activate(grid_x);
  }
}
