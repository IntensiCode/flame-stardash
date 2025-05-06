import 'dart:math';
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:stardash/core/common.dart';
import 'package:stardash/game/base/fake_three_d.dart';
import 'package:stardash/game/base/game_phase.dart';
import 'package:stardash/game/base/has_context.dart';
import 'package:stardash/game/base/kinds.dart';
import 'package:stardash/game/level/level.dart';
import 'package:stardash/game/level/level_transition.dart';
import 'package:stardash/util/mutable.dart';
import 'package:stardash/util/random.dart';
import 'package:stardash/util/vector_font.dart';

enum _FlashState {
  idle,
  delayed,
  fading_in,
  holding,
  fading_out,
}

class LevelTile extends PositionComponent with OnHit, HasContext, FakeThreeDee, LevelTransition {
  static final shared_paint = Paint();

  late final Color outline_color_with_alpha;
  late final Color spike_color;
  final Color outline_color;
  final double outline_stroke_width;
  final bool is_bottom;
  final bool is_top;
  final bool is_right;
  final double grid_left;
  final double grid_right;
  final double grid_bottom;
  final double grid_top;

  Color _fill_color = transparent;

  _FlashState _flash_state = _FlashState.idle;

  double _flash_timer = 0.0;
  double _startDelay = 0.0;
  Color _flash_base_color = Colors.transparent;
  double _fade_in_duration = 0.05;
  double _hold_duration = 0.2;
  double _fade_out_duration = 0.5;
  double _max_flash_alpha = 0.8;

  double spikedness = 0.0;
  bool is_spike_tip = false;

  LevelTile? previous;
  String? debug_info;

  final _p0 = MutableOffset(0, 0);
  final _p1 = MutableOffset(0, 0);
  final _p2 = MutableOffset(0, 0);
  final _p3 = MutableOffset(0, 0);

  @override // TODO: OMFG!? WTF!?
  double get grid_z => switch (spikedness) {
        < 0.3 => grid_top + translation.z,
        < 0.8 => super.grid_z,
        _ => grid_bottom + translation.z,
      };

  LevelTile({
    this.outline_color = Colors.white,
    this.outline_stroke_width = 1.0,
    this.is_bottom = false,
    this.is_top = false,
    this.is_right = false,
    required this.grid_left,
    required this.grid_right,
    required this.grid_bottom,
    required this.grid_top,
  }) {
    grid_x = (grid_left + grid_right) / 2.0;
    grid_z = (grid_bottom + grid_top) / 2.0;
    outline_color_with_alpha = outline_color.withValues(alpha: outline_color.a * 0.5);
    spike_color = outline_color.withValues(
      red: (outline_color.r * 1.2).clamp(0, 1),
      green: (outline_color.g * 1.2).clamp(0, 1),
      blue: (outline_color.b * 1.2).clamp(0, 1),
    );
    remaining_hit_points = max_hit_points = 1;
  }

  @override
  bool is_affected_by(FakeThreeDee other) {
    if (spikedness == 0.0 || !is_spike_tip) return false;
    // log_info('other: ${other.grid_x} ${other.grid_z}');
    // log_info('self: $grid_x $grid_z');
    if ((grid_x - other.grid_x).abs() >= hit_3d_delta) return false;
    if ((grid_z - other.grid_z).abs() >= hit_3d_delta) return false;
    return true;
  }

  @override
  void on_hit(double damage) {
    super.on_hit(damage);

    assert(is_spike_tip);
    assert(spikedness > 0);

    spikedness -= 0.5;
    if (spikedness <= 0.0) {
      is_spike_tip = false;
      previous?.is_spike_tip = true;
      previous?.spikedness += spikedness;
    } else {
      remaining_hit_points = 1;
    }

    if (debug) flash(Colors.red, fade_in: 0.05, hold: 0.1, fade_out: 0.2, max_alpha: 0.7);
  }

  @override
  void update_transition(GamePhase phase, double progress) {
    super.update_transition(phase, progress);
    final in_transit = phase == GamePhase.entering_level || phase == GamePhase.leaving_level;
    final t = in_transit ? translation.z : 0.0;
    _p0.setFrom(level.map_grid_to_screen(grid_left, grid_bottom + t));
    _p1.setFrom(level.map_grid_to_screen(grid_right, grid_bottom + t));
    _p2.setFrom(level.map_grid_to_screen(grid_right, grid_top + t));
    _p3.setFrom(level.map_grid_to_screen(grid_left, grid_top + t));
  }

  /// Starts the flash effect.
  /// [base_color] is the target color (alpha will be animated).
  void flash(
    Color base_color, {
    double fade_in = 0.1,
    double hold = 0.2,
    double fade_out = 0.4,
    double max_alpha = 0.5,
    double start_delay = 0.0,
  }) {
    _flash_base_color = base_color;
    _fade_in_duration = fade_in;
    _hold_duration = hold;
    _fade_out_duration = fade_out;
    _max_flash_alpha = max_alpha.clamp(0.0, 1.0);
    _startDelay = start_delay;
    _flash_timer = 0.0;

    if (_startDelay > 0) {
      _flash_state = _FlashState.delayed;
    } else {
      _flash_state = _FlashState.fading_in;
    }
    _fill_color = transparent;
  }

  @override
  void update(double dt) {
    super.update(dt);

    _spike_anim += dt + level_rng.nextDoubleLimit(dt * 8);
    if (_spike_anim > 2 * pi) _spike_anim -= 2 * pi;

    if (_flash_state == _FlashState.idle) return;

    _flash_timer += dt;

    double alpha = 0.0;

    switch (_flash_state) {
      case _FlashState.delayed:
        if (_flash_timer >= _startDelay) {
          _flash_state = _FlashState.fading_in;
          _flash_timer = 0.0;
        }
        alpha = 0.0;
        break;
      case _FlashState.fading_in:
        final t = (_flash_timer / _fade_in_duration).clamp(0.0, 1.0);
        alpha = lerpDouble(0, _max_flash_alpha, t)!;
        if (_flash_timer >= _fade_in_duration) {
          _flash_state = _FlashState.holding;
          _flash_timer = 0.0;
        }
        break;
      case _FlashState.holding:
        alpha = _max_flash_alpha;
        if (_flash_timer >= _hold_duration) {
          _flash_state = _FlashState.fading_out;
          _flash_timer = 0.0;
        }
        break;
      case _FlashState.fading_out:
        final t = (_flash_timer / _fade_out_duration).clamp(0.0, 1.0);
        alpha = lerpDouble(_max_flash_alpha, 0, t)!;
        if (_flash_timer >= _fade_out_duration) {
          _flash_state = _FlashState.idle;
          _flash_timer = 0.0;
        }
        break;
      case _FlashState.idle:
        break;
    }

    if (_flash_state != _FlashState.delayed) {
      _fill_color = _flash_base_color.withValues(alpha: _flash_base_color.a * alpha);
    }
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    _render_tile(canvas);
    _render_outline(canvas);
    if (spikedness > 0.0) _render_spike(canvas);
    if (debug && debug_info != null) _render_debug(canvas);
  }

  void _render_debug(Canvas canvas) {
    shared_paint.strokeWidth = outline_stroke_width * 0.5;
    shared_paint.color = Colors.white;
    vector_font.render_anchored(
      canvas,
      shared_paint,
      debug_info!,
      (_p0 + _p1) * 0.5,
      outline_stroke_width * 0.5,
      Anchor.topCenter,
    );
  }

  void _render_tile(Canvas canvas) {
    shared_paint.color = _fill_color;
    shared_paint.strokeWidth = 1.0;
    shared_paint.style = PaintingStyle.fill;
    final vertices = Vertices(VertexMode.triangleFan, [_p0, _p1, _p2, _p3]);
    canvas.drawVertices(vertices, BlendMode.srcOver, shared_paint);
  }

  void _render_outline(Canvas canvas) {
    shared_paint.strokeWidth = outline_stroke_width;
    shared_paint.style = PaintingStyle.stroke;
    shared_paint.color = outline_color;

    if (is_right) canvas.drawLine(_p1, _p2, shared_paint);
    if (is_top) canvas.drawLine(_p2, _p3, shared_paint);
    canvas.drawLine(_p3, _p0, shared_paint);

    if (!is_bottom) shared_paint.color = outline_color_with_alpha;
    canvas.drawLine(_p0, _p1, shared_paint);
  }

  void _render_spike(Canvas canvas) {
    shared_paint.color = spike_color;
    shared_paint.strokeWidth = outline_stroke_width * 2;

    _spike_top.dx = (_p0.dx + _p1.dx) * 0.5;
    _spike_top.dy = (_p0.dy + _p1.dy) * 0.5;
    _spike_bottom.dx = (_p2.dx + _p3.dx) * 0.5;
    _spike_bottom.dy = (_p2.dy + _p3.dy) * 0.5;

    final dx = _spike_top.dx - _spike_bottom.dx;
    final dy = _spike_top.dy - _spike_bottom.dy;
    _spike_top.dx = _spike_top.dx - dx * (1 - spikedness);
    _spike_top.dy = _spike_top.dy - dy * (1 - spikedness);

    canvas.drawLine(_spike_top, _spike_bottom, shared_paint);

    if (is_spike_tip) _render_cross(canvas);
  }

  void _render_cross(Canvas canvas) {
    shared_paint.color = _lerp_cross_color();
    shared_paint.strokeWidth = 2.0;

    // Rotating cross at tip
    final cx = _spike_top.dx;
    final cy = _spike_top.dy;
    final len = perspective_scale(x: grid_x, z: grid_z) * 10 * sin(_spike_anim);
    final angle = _spike_anim;
    final cosA = cos(angle);
    final sinA = sin(angle);

    // First line
    _spike_from.dx = cx - len * cosA;
    _spike_from.dy = cy - len * sinA;
    _spike_to.dx = cx + len * cosA;
    _spike_to.dy = cy + len * sinA;
    canvas.drawLine(_spike_from, _spike_to, shared_paint);

    // Second line (perpendicular)
    _spike_from.dx = cx - len * sinA;
    _spike_from.dy = cy + len * cosA;
    _spike_to.dx = cx + len * sinA;
    _spike_to.dy = cy - len * cosA;
    canvas.drawLine(_spike_from, _spike_to, shared_paint);
  }

  Color _lerp_cross_color() {
    final color_index = (_spike_anim / (2 * pi) * _cross_colors.length).floor() % _cross_colors.length;
    final c1 = _cross_colors[color_index];
    final c2 = _cross_colors[(color_index + 1) % _cross_colors.length];
    final t = (_spike_anim / (2 * pi) * _cross_colors.length) % 1.0;
    return Color.lerp(c1, c2, t)!;
  }

  double _spike_anim = 0.0;
  final _spike_from = MutableOffset(0, 0);
  final _spike_to = MutableOffset(0, 0);
  final _spike_top = MutableOffset(0, 0);
  final _spike_bottom = MutableOffset(0, 0);

  static final _cross_colors = [
    Colors.red,
    Colors.orange,
    Colors.yellow,
    Colors.white,
    Colors.yellow,
    Colors.orange,
    Colors.red,
    Colors.black,
  ];
}
