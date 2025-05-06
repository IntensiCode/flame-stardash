import 'dart:ui';

import 'package:flame/components.dart';
import 'package:stardash/game/base/fake_three_d.dart';

mixin OnHit on Component {
  static const hit_color = Color(0xFFffffff);

  double hit_time = 0;
  double hit_3d_delta = 0.02;

  late double max_hit_points;
  late double remaining_hit_points;

  bool get is_dead => remaining_hit_points <= 0 || isRemoved;

  /// Determines if this entity can be affected by the given coordinate.
  /// Used for more specific collision filtering.
  ///
  /// [other] The component to check against.
  bool is_affected_by(FakeThreeDee other) {
    if (this case FakeThreeDee self) {
      // log_info('self: ${self.grid_x} ${self.grid_z}');
      // log_info('other: ${other.grid_x} ${other.grid_z}');
      if ((self.grid_x - other.grid_x).abs() >= hit_3d_delta) return false;
      if ((self.grid_z - other.grid_z).abs() >= hit_3d_delta) return false;
      return true;
    }
    throw UnimplementedError('either be HasFakeThreeDee or implement is_affected_by: $this');
  }

  void on_hit(double damage) {
    hit_time = 0.05;
    remaining_hit_points -= damage;
    if (remaining_hit_points < 0) remaining_hit_points = 0;
  }

  @override
  void update(double dt) {
    super.update(dt);
    hit_time = (hit_time - dt).clamp(0, 1);
  }
}

mixin Friendly on OnHit {}

mixin Hostile on OnHit {}
