import 'dart:math';
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/sprite.dart';
import 'package:stardash/core/common.dart';
import 'package:stardash/game/base/fake_three_d.dart';
import 'package:stardash/game/base/has_context.dart';
import 'package:stardash/util/extensions.dart';
import 'package:stardash/util/functions.dart';
import 'package:stardash/util/log.dart';
import 'package:stardash/util/random.dart';

extension HasContextExtensions on HasContext {
  Decals get decals => cache.putIfAbsent('decals', () => Decals());
}

enum Decal {
  dust(anim_time: 1.0),
  energy_ball(anim_time: 0.5, random_range: 0),
  explosion16(anim_time: 1.0),
  explosion32(anim_time: 1.0),
  mini_explosion(anim_time: 0.5, random_range: 0),
  smoke(anim_time: 1.0, random_range: 4, rotate_speed: 1),
  sparkle(anim_time: 0.5, random_range: 1, rotate_speed: 0.4),
  teleport(anim_time: 0.5, random_range: 0),
  ;

  const Decal({required this.anim_time, this.random_range = 8, this.rotate_speed});

  final double anim_time;
  final double random_range;
  final double? rotate_speed;
}

class Decals extends Component with HasContext {
  final _ready = <Decal, List<DecalObj>>{};
  final _active = <Decal, List<DecalObj>>{};
  final _anim = <Decal, SpriteSheet>{};

  DecalObj spawn3d(
    Decal decal,
    FakeThreeDee origin, {
    Vector2? pos_override,
    double? pos_range,
    double? vel_range,
  }) {
    final it = _spawn(decal, pos_override ?? origin.position, pos_range: pos_range, vel_range: vel_range);
    it.grid_x = origin.grid_x;
    it.grid_z = origin.grid_z; //  - origin.size.y * 0.01;
    if (dev) it.debugMode = debugMode;

    if (decal == Decal.teleport) {
      it.size = origin.size;
    } else {
      it.size.setAll(it.size.x * it.perspective_scale(x: it.grid_x, z: it.grid_z));
    }
    return it;
  }

  DecalObj _spawn(Decal decal, Vector2 start, {double? pos_range, double? vel_range}) {
    late final DecalObj result;

    final instances = _active[decal] ??= List.empty(growable: true);
    final pool = _ready[decal]!;
    if (pool.isEmpty) {
      if (dev) {
        log_warn('decals pool empty for $decal');
        throw 'decals pool empty for $decal';
      }
      pool.add(DecalObj(_anim[decal]!, decal));
    }
    instances.add(result = pool.removeAt(0));

    result.size.setAll(switch (decal) {
      Decal.dust => 6.0,
      Decal.smoke => 6.0,
      Decal.sparkle => 16.0,
      _ => 32.0,
    });
    result.position.setFrom(start);
    result.velocity.setZero();
    result.time = 0;
    result.angle = 0;

    pos_range = pos_range ?? decal.random_range;
    if (pos_range > 0) result.randomize_position(range: pos_range);
    if (vel_range != null) result.randomize_velocity(range: vel_range ?? 8);

    stage.add(result);
    return result;
  }

  @override
  onLoad() {
    _anim[Decal.dust] = sheetI('dust.png', 10, 1);
    _anim[Decal.energy_ball] = sheetI('energy_balls.png', 6, 3);
    _anim[Decal.explosion16] = sheetI('explosion16.png', 15, 1);
    _anim[Decal.explosion32] = sheetI('explosion32.png', 18, 1);
    _anim[Decal.mini_explosion] = sheetI('mini_explosion.png', 6, 1);
    _anim[Decal.smoke] = sheetI('smoke.png', 11, 1);
    _anim[Decal.sparkle] = sheetI('sparkle.png', 4, 1);
    _anim[Decal.teleport] = sheetI('teleport.png', 10, 1);

    _precreate_all();
  }

  void _precreate_all() {
    for (final it in Decal.values) {
      _ready[it] = List.empty(growable: true);
      _active[it] = List.empty(growable: true);
      final count = switch (it) {
        Decal.dust => 64,
        Decal.smoke => 64,
        _ => 16,
      };
      _precreate(it, count);
    }
  }

  void _precreate(Decal decal, int count) {
    for (var i = 0; i < count; i++) {
      _ready[decal]!.add(DecalObj(_anim[decal]!, decal));
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    for (final it in Decal.values) _update(it, dt);
  }

  void _update(Decal decal, double dt) {
    final decals = _active[decal];
    if (decals == null) return;

    for (final it in decals) {
      it.position.x += it.velocity.x * dt;
      it.position.y += it.velocity.y * dt;
      it.time += dt;
      if (decal.rotate_speed != null) it.angle += pi * 2 / decal.rotate_speed! * dt;
    }
    final done = decals.where((it) => it.time >= decal.anim_time).toList();
    for (final it in done) {
      _ready[decal]!.add(it);
      it.removeFromParent();
    }
    decals.removeAll(done);
  }
}

class DecalObj extends PositionComponent with HasPaint, FakeThreeDee {
  DecalObj(this.animation, this.decal) : this.velocity = Vector2.zero();

  final SpriteSheet animation;
  final Decal decal;
  final Vector2 velocity;

  int row = 0;
  double time = 0;

  void randomize_position({double range = 20}) {
    position.x += level_rng.nextDoublePM(range);
    position.y += level_rng.nextDoublePM(range);
  }

  void randomize_velocity({double range = 20}) {
    velocity.x += level_rng.nextDoublePM(range);
    velocity.y += level_rng.nextDoublePM(range);
  }

  @override
  void update(double dt) {
    super.update(dt);
    priority = 1000;
  }

  @override
  void render(Canvas canvas) {
    final it = this;
    final column = (it.time * (animation.columns - 1) / decal.anim_time).toInt();
    final f = animation.getSprite(it.row, column);
    f.render(canvas, anchor: Anchor.center, size: size);
  }
}
