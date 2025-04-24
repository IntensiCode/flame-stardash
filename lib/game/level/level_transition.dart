import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flutter/animation.dart';
import 'package:stardash/game/base/game_phase.dart';
import 'package:stardash/game/level/level_tiles.dart';
import 'package:stardash/util/mutable.dart';

mixin LevelTransition on Component, HasPaint {
  static const double _min_scale = 0.1; // Start scale for entering
  static const double _max_scale = 20.0; // End scale for leaving

  final _color = MutColor(0xFFffffff);

  final vanishing_point = Vector2.zero(); // Center point for perspective scaling

  LevelTiles? level_tiles;

  GamePhase? game_phase;
  double transition_progress = 0.0;
  double _transition_scale = 1.0;
  double _transition_alpha = 1.0;

  bool get needs_lerp => game_phase == GamePhase.entering_level && transition_progress > 0.01 && transition_progress < 0.99;

  void update_transition(GamePhase phase, double progress) {
    game_phase = phase;
    transition_progress = progress;
    _transition_scale = _get_transition_scale(progress);
    _transition_alpha = _get_transition_alpha(progress);

    level_tiles?.effects_enabled = !needs_lerp;
  }

  @override
  void renderTree(Canvas canvas) {
    canvas.save();
    
    final center_x = vanishing_point.x;
    final center_y = vanishing_point.y;
    canvas.translate(center_x, center_y);
    canvas.scale(_transition_scale, _transition_scale);
    canvas.translate(-center_x, -center_y);
    
    final saved_alpha = paint.color.a;
    _color.a = saved_alpha * _transition_alpha;
    paint.color = _color;
    
    super.renderTree(canvas);
    
    _color.a = saved_alpha;
    paint.color = _color;
    
    canvas.restore();
  }

  // --- Transition Getters (Now accept progress) ---
  double _get_transition_scale(double transition_progress) {
    if (game_phase == GamePhase.entering_level) {
      // Start small (far away) and scale up to normal size
      // _minScale -> 1.0 as progress goes from 0.0 -> 1.0
      final progress = Curves.easeInCubic.transform(transition_progress);
      // final progress = _transitionProgress;
      return _min_scale + (1.0 - _min_scale) * progress;
    } else if (game_phase == GamePhase.leaving_level) {
      // Start normal size and scale up (zoom toward player/disappear)
      // 1.0 -> _maxScale as progress goes from 0.0 -> 1.0
      final progress = Curves.easeInOutCubic.transform(transition_progress);
      return 1.0 + (_max_scale - 1.0) * progress;
    }
    return 1.0; // Default/normal scale
  }

  double _get_transition_alpha(double transition_progress) {
    final progress = transition_progress;
    const start_alpha = 0.5; // Minimum alpha during entering
    if (game_phase == GamePhase.entering_level) {
      // Fade in: startAlpha -> 1.0
      return start_alpha + (1.0 - start_alpha) * progress;
    } else if (game_phase == GamePhase.leaving_level) {
      // Fade out: 1.0 -> 0.0 (or startAlpha if preferred)
      return 1.0 - progress;
    }
    return 1.0; // Default/full alpha
  }
}
