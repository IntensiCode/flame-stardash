import 'dart:ui';

import 'package:flame/components.dart';

mixin OnHit on Component {
  static const hit_color = Color(0xFFffffff);

  double hit_time = 0;

  /// Called when this friendly entity is hit by something that deals damage.
  ///
  /// [damage] The amount of damage dealt.
  void on_hit(double damage) => hit_time += 0.2;

  @override
  void update(double dt) {
    super.update(dt);
    hit_time = (hit_time - dt).clamp(0, 1);
  }
}

/// Mixin for components considered friendly to the player.
/// Used for collision filtering.
mixin Friendly on OnHit {
  /// Called when this friendly entity is hit by something that deals damage.
  ///
  /// [damage] The amount of damage dealt.
  @override
  void on_hit(double damage);
}

/// Mixin for components considered hostile to the player.
/// Used for collision filtering and damage application.
mixin Hostile on OnHit {
  /// Called when this hostile entity is hit by something that deals damage.
  ///
  /// [damage] The amount of damage dealt.
  @override
  void on_hit(double damage);
}
