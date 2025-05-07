import 'dart:math';
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:stardash/aural/audio_system.dart';
import 'package:stardash/game/base/has_context.dart';
import 'package:stardash/game/player/player.dart';
import 'package:stardash/util/vector_font.dart';
import 'package:stardash/game/base/hiscore.dart';

class Hud extends Component with HasContext {
  static const Color _hud_color = Color(0xFF50FF50);
  static const double _score_increase_rate = 250.0;
  static const double _flash_duration = 0.5;
  static const double _health_display_change_rate = 10.0;
  static const double _score_blink_cycle_period = 1.0;
  static const double _score_blink_off_time = 0.2;

  late final VectorFont _font;
  late final Paint _score_paint;
  late final Paint _hiscore_paint;
  late final Paint _health_dot_paint;
  late final Paint _health_dot_lost_paint;
  late final Paint _lives_paint;
  late final Paint _super_zapper_paint;

  double _display_score = 0;
  double _display_remaining_hit_points = 0;
  double _previous_player_actual_hp = -1;
  double _flash_timer = 0.0;
  bool _is_flashing_health = false;

  bool _is_player_score_a_hiscore_rank = false;
  bool _is_player_score_a_new_hiscore = false;
  double _score_blink_timer = 0.0;

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

    _super_zapper_paint = Paint() // Initialize super zapper paint
      ..color = const Color(0xFFFFD700) // Gold color for thunderbolts
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
      if (_display_score < target_score - 500) {
        _display_score += (target_score - _display_score) * 0.1;
      }
    }

    if (player.isMounted) {
      final before = _is_player_score_a_new_hiscore;
      _is_player_score_a_hiscore_rank = hiscore.is_hiscore_rank(player.score);
      _is_player_score_a_new_hiscore = hiscore.is_new_hiscore(player.score);

      if (before != _is_player_score_a_new_hiscore) {
        audio.play(Sound.hiscore);
      }

      bool should_trigger_blinking_cycle = _is_player_score_a_hiscore_rank;

      if (should_trigger_blinking_cycle) {
        _score_blink_timer += dt;
        _score_blink_timer %= _score_blink_cycle_period;
      } else {
        _score_blink_timer = 0.0;
      }

      _animate_towards_hp(dt);
      _flash_hp(dt);
    } else {
      _display_remaining_hit_points = 0;
      _previous_player_actual_hp = -1;
      _is_flashing_health = false;
      _is_player_score_a_hiscore_rank = false;
      _is_player_score_a_new_hiscore = false;
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

    bool show_current_score = true;
    if (_is_player_score_a_hiscore_rank) {
      if (_score_blink_timer < _score_blink_off_time) {
        show_current_score = false;
      }
    }

    if (show_current_score) {
      _font.render_string(
        canvas,
        _score_paint,
        _display_score.toInt().toString(),
        const Offset(30, 40),
        2.0,
      );
    }

    String hiscore_text_to_display;
    double hiscore_text_scale = 1.0;
    Offset hiscore_position = const Offset(300, 40);

    if (_is_player_score_a_new_hiscore && player.isMounted) {
      hiscore_text_to_display = player.score.toInt().toString();
      hiscore_text_scale = 2.0;
    } else if (hiscore.entries.isNotEmpty) {
      final top_entry = hiscore.entries.first;
      hiscore_text_to_display = '${top_entry.score} ${top_entry.name}';
      hiscore_text_scale = 1.0;
    } else {
      hiscore_text_to_display = '---';
      hiscore_text_scale = 1.0;
    }

    bool show_hiscore_display = true;
    if (_is_player_score_a_new_hiscore) {
      if (_score_blink_timer < _score_blink_off_time) {
        show_hiscore_display = false;
      }
    }

    if (show_hiscore_display) {
      _font.render_string(
        canvas,
        _hiscore_paint,
        hiscore_text_to_display,
        hiscore_position,
        hiscore_text_scale,
      );
    }

    _render_health_dots(canvas);
    _render_lives(canvas);
    _render_super_zappers(canvas);
  }

  void _render_health_dots(Canvas canvas) {
    if (!player.isMounted || player.max_hit_points <= 0) return;

    final double hp_to_display = _display_remaining_hit_points;
    final int max_hp_integer_dots = player.max_hit_points.ceil();

    const double dot_radius = 4.0;
    const double dot_spacing = dot_radius * 2.5;
    const double start_x = 35.0;
    const double y_pos = 80.0;

    Paint current_active_dot_paint = _health_dot_paint;
    if (_is_flashing_health) {
      const double blink_interval = 0.1;
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
        canvas.drawCircle(dot_center, dot_radius, current_active_dot_paint);
      } else if (health_value_for_this_dot_slot >= 0.5) {
        if (current_active_dot_paint == _health_dot_lost_paint) {
          canvas.drawCircle(dot_center, dot_radius, _health_dot_lost_paint);
        } else {
          canvas.drawArc(dot_rect, pi / 2, pi, true, _health_dot_paint);
        }
      } else {
        canvas.drawCircle(dot_center, dot_radius, _health_dot_lost_paint);
      }
    }
  }

  void _render_lives(Canvas canvas) {
    if (!player.isMounted || player.lives <= 0) return;

    const double triangle_height = 8.0;
    const double triangle_base_width = 8.0;
    const double triangle_spacing = triangle_base_width * 1.25;
    const double health_dots_y_end = 80.0 + 4.0 * 2;
    const double lives_y = health_dots_y_end + 8.0;
    const double start_x = 31.0;

    for (int i = 0; i < player.lives; i++) {
      final double triangle_center_x = start_x + i * triangle_spacing + triangle_base_width / 2;
      final Path path = Path();
      path.moveTo(triangle_center_x, lives_y);
      path.lineTo(triangle_center_x - triangle_base_width / 2, lives_y + triangle_height);
      path.lineTo(triangle_center_x + triangle_base_width / 2, lives_y + triangle_height);
      path.close();

      canvas.drawPath(path, _lives_paint);
    }
  }

  void _render_super_zappers(Canvas canvas) {
    if (!player.isMounted || player.super_zappers <= 0) return;

    const double thunderbolt_height = 10.0;
    const double thunderbolt_width = 7.0;
    const double thunderbolt_spacing = thunderbolt_width * 1.5;
    const double lives_triangle_height = 8.0;
    const double health_dots_y_end = 80.0 + 4.0 * 2;
    const double lives_y_end = health_dots_y_end + 8.0 + lives_triangle_height;
    const double zappers_y = lives_y_end + 18.0;
    const double start_x = 31.0;

    for (int i = 0; i < player.super_zappers; i++) {
      final double center_x = start_x + i * thunderbolt_spacing + thunderbolt_width / 2;
      canvas.drawRect(
        Rect.fromCenter(
          center: Offset(center_x, zappers_y),
          width: thunderbolt_width,
          height: thunderbolt_height,
        ),
        _super_zapper_paint,
      );
    }
  }
}
