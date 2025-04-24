import 'dart:math';
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:stardash/game/base/has_context.dart';
import 'package:stardash/game/player/player.dart';
import 'package:stardash/util/vector_font.dart';

class Hud extends Component with HasContext {
  static const Color _hudColor = Color(0xFF50FF50); // Greenish
  static const double _score_increase_rate = 250.0; // Points per second

  late final VectorFont _font;
  late final Paint _score_paint;
  late final Paint _hiscore_paint;

  double _display_score = 0;

  @override
  Future<void> onLoad() async {
    _font = vector_font;

    final base_paint = Paint()
      ..color = _hudColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    _score_paint = base_paint;
    // Hiscore paint can be the same for now, or slightly different if needed
    _hiscore_paint = base_paint;
  }

  @override
  void update(double dt) {
    super.update(dt);
    final target_score = player.score.toDouble();
    if (_display_score < target_score) {
      _display_score = min(_display_score + _score_increase_rate * dt, target_score);
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
  }
}
