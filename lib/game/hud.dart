import 'dart:ui';

import 'package:flame/components.dart';
import 'package:stardash/util/vector_font.dart';

class Hud extends Component {
  late final VectorFont _font;
  late final Paint _score_paint;
  late final Paint _hiscore_paint;

  static const Color _hudColor = Color(0xFF50FF50); // Greenish

  @override
  Future<void> onLoad() async {
    _font = VectorFont();

    final base_paint = Paint()
      ..color = _hudColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    _score_paint = base_paint;
    // Hiscore paint can be the same for now, or slightly different if needed
    _hiscore_paint = base_paint;
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    // Draw Score (top-left)
    _font.render_string(
      canvas,
      _score_paint,
      '1050',
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
