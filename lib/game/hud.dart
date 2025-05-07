import 'dart:math';
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:stardash/game/base/has_context.dart';
import 'package:stardash/game/player/player.dart';
import 'package:stardash/util/vector_font.dart';

class Hud extends Component with HasContext {
  static const Color _hud_color = Color(0xFF50FF50);
  static const double _score_increase_rate = 250.0;
  static const double _flash_duration = 0.5;
  static const double _health_display_change_rate = 10.0;

  late final VectorFont _font;
  late final Paint _score_paint;
  late final Paint _hiscore_paint;
  late final Paint _health_dot_paint;
  late final Paint _health_dot_lost_paint;
  late final Paint _lives_paint;

  double _display_score = 0;
  double _display_remaining_hit_points = 0;
  double _previous_player_actual_hp = -1;
  double _flash_timer = 0.0;
  bool _is_flashing_health = false;

  @override
  Future<void> onLoad() async {
    _font = vector_font;

    final base_paint = Paint()
      ..color = _hud_color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    _score_paint = base_paint;
    // Hiscore paint can be the same for now, or slightly different if needed
    _hiscore_paint = base_paint;

    _health_dot_paint = Paint()
      ..color = _hud_color
      ..style = PaintingStyle.fill;

    _health_dot_lost_paint = Paint()
      ..color = _hud_color.withAlpha((0.25 * 255).toInt()) // Alpha 0.25
      ..style = PaintingStyle.fill;

    _lives_paint = Paint() // Initialize lives paint
      ..color = _hud_color
      ..style = PaintingStyle.fill;

    if (player.isMounted) {
      _display_remaining_hit_points = player.remaining_hit_points;
      _previous_player_actual_hp = player.remaining_hit_points;
    } else {
      _display_remaining_hit_points = 0;
      _previous_player_actual_hp = -1; // Trigger change detection on first valid HP read
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    final target_score = player.score.toDouble();
    if (_display_score < target_score) {
      _display_score = min(_display_score + _score_increase_rate * dt, target_score);
    }

    if (player.isMounted) {
      _animate_towards_hp(dt);
      _flash_hp(dt);
    } else {
      // Reset if player is not mounted (e.g. game over screen)
      _display_remaining_hit_points = 0;
      _previous_player_actual_hp = -1;
      _is_flashing_health = false;
    }
  }

  void _animate_towards_hp(double dt) {
    // Animate display health towards actual health
    final double actual_player_hp = player.remaining_hit_points;
    if (_display_remaining_hit_points == actual_player_hp) return;

    double diff = actual_player_hp - _display_remaining_hit_points;
    double change_this_frame = _health_display_change_rate * dt;

    if (diff.abs() < 0.01) {
      // Snap if very close
      _display_remaining_hit_points = actual_player_hp;
    } else if (diff > 0) {
      // Gaining health
      _display_remaining_hit_points += min(change_this_frame, diff);
    } else {
      // Losing health
      _display_remaining_hit_points -= min(change_this_frame, diff.abs());
    }
    _display_remaining_hit_points = _display_remaining_hit_points.clamp(0.0, player.max_hit_points);
  }

  void _flash_hp(double dt) {
    // Health flash logic
    final double actual_player_hp = player.remaining_hit_points;
    if (_previous_player_actual_hp != actual_player_hp && _previous_player_actual_hp != -1) {
      if (actual_player_hp != _previous_player_actual_hp) {
        // ensure it's a real change
        _is_flashing_health = true;
        _flash_timer = _flash_duration;
      }
    }
    _previous_player_actual_hp = actual_player_hp;

    if (_is_flashing_health) {
      _flash_timer -= dt;
      if (_flash_timer <= 0) {
        _is_flashing_health = false;
        _flash_timer = 0.0;
      }
    }
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    // Draw Score (top-left)
    _font.render_string(
      canvas,
      _score_paint,
      _display_score.toInt().toString(), // Display animated score
      const Offset(30, 40), // Position from top-left
      2.0, // Scale
    );

    // Draw Hiscore (top-centerish)
    // Need to estimate text width to center it roughly
    // For now, just place it approximately
    // TODO: Calculate width properly for centering
    _font.render_string(
      canvas,
      _hiscore_paint,
      '149050 DAZ',
      const Offset(300, 40), // Approximate top-center position
      1.0, // Smaller scale
    );

    _render_health_dots(canvas);
    _render_lives(canvas);
  }

  void _render_health_dots(Canvas canvas) {
    if (!player.isMounted || player.max_hit_points <= 0) return;

    final double hp_to_display = _display_remaining_hit_points;
    final int max_hp_integer_dots = player.max_hit_points.ceil();

    const double dot_radius = 4.0;
    const double dot_spacing = dot_radius * 2.5;
    const double start_x = 35.0;
    const double y_pos = 80.0; // Adjusted yPos slightly for spacing from score

    Paint current_active_dot_paint = _health_dot_paint;
    if (_is_flashing_health) {
      const double blink_interval = 0.1; // Duration of one phase of a blink (on or off)
      // True if in the "on" phase of the blink
      bool is_on_phase_of_blink = ((_flash_duration - _flash_timer) / blink_interval).floor() % 2 == 0;
      if (is_on_phase_of_blink) {
        current_active_dot_paint = _health_dot_lost_paint;
      }
    }

    for (int i = 0; i < max_hp_integer_dots; i++) {
      final double dotCenterX = start_x + i * dot_spacing;
      final Offset dot_center = Offset(dotCenterX, y_pos);
      final Rect dot_rect = Rect.fromCircle(center: dot_center, radius: dot_radius);
      final double health_value_for_this_dot_slot = hp_to_display - i;

      if (health_value_for_this_dot_slot >= 1.0) {
        // Full dot
        canvas.drawCircle(dot_center, dot_radius, current_active_dot_paint);
      } else if (health_value_for_this_dot_slot >= 0.5) {
        // Half dot
        if (current_active_dot_paint == _health_dot_lost_paint) {
          canvas.drawCircle(dot_center, dot_radius, _health_dot_lost_paint);
        } else {
          canvas.drawArc(dot_rect, pi / 2, pi, true, _health_dot_paint);
        }
      } else {
        // Lost hitpoint
        canvas.drawCircle(dot_center, dot_radius, _health_dot_lost_paint);
      }
    }
  }

  void _render_lives(Canvas canvas) {
    if (!player.isMounted || player.lives <= 0) return;

    const double triangle_height = 8.0;
    const double triangle_base_width = 8.0;
    const double triangle_spacing = triangle_base_width * 1.25; // Spacing between triangles
    const double health_dots_y = 40.0;
    const double health_dot_radius = 4.0;
    const double lives_y = health_dots_y + health_dot_radius * 2 + 8.0; // Position lives below health dots
    const double start_x = 31.0;

    for (int i = 0; i < player.lives; i++) {
      final double triangle_center_x = start_x + i * triangle_spacing + triangle_base_width / 2;
      final Path path = Path();
      // Top point of the upward triangle
      path.moveTo(triangle_center_x, lives_y);
      // Bottom-left point
      path.lineTo(triangle_center_x - triangle_base_width / 2, lives_y + triangle_height);
      // Bottom-right point
      path.lineTo(triangle_center_x + triangle_base_width / 2, lives_y + triangle_height);
      path.close(); // Close the path to form a triangle

      canvas.drawPath(path, _lives_paint);
    }
  }
}
