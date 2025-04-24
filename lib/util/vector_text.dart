import 'dart:ui';

import 'package:flame/components.dart';
import 'package:stardash/util/mutable.dart';
import 'package:stardash/util/vector_font.dart';

class VectorText extends PositionComponent with HasPaint, HasVisibility {
  final _reference = Vector2.zero();

  final VectorFont font;
  final double font_scale;
  final Anchor _text_anchor;

  String _text;

  String get text => _text;

  VectorText({
    required String text,
    required Vector2 position,
    VectorFont? font,
    double scale = 1,
    Color? tint,
    Anchor anchor = Anchor.topLeft,
  })  : _text = text,
        _text_anchor = anchor,
        font = font ?? vector_font,
        font_scale = scale {
    //

    if (tint != null) this.tint(tint);

    _reference.setFrom(position);

    _update_position(text);

    paint
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = 1.5;
  }

  void _update_position(String text) {
    _text = text;

    // Calculate the size of the text
    final textSize = _calc_text_size(text);
    size.setValues(textSize.x, textSize.y);

    final x = _text_anchor.x * size.x;
    final y = _text_anchor.y * size.y;
    position.setFrom(_reference);
    position.x -= x;
    position.y -= y;
  }

  Vector2 _calc_text_size(String text) {
    if (text.isEmpty) return Vector2.zero();

    double width = 0;
    double max_width = 0;
    double height = 10 * font_scale; // Base height for a single line

    for (int i = 0; i < text.length; i++) {
      final char = text[i];
      if (char == '\n') {
        max_width = max_width > width ? max_width : width;
        width = 0;
        height += 10 * font_scale + 2; // Line height + spacing
        continue;
      }

      final char_width = font.char_width(char);
      width += char_width * font_scale;
    }

    max_width = max_width > width ? max_width : width;
    return Vector2(max_width, height);
  }

  set text(String text) => change_text_in_place(text);

  void change_text_in_place(String text) {
    _text = text;
    _update_position(text);
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    // Split text by newlines and render each line
    final lines = _text.split('\n');
    double offset_y = 0;

    for (final line in lines) {
      _offset.dx = 0;
      _offset.dy = offset_y;
      font.render_string(canvas, paint, line, _offset, font_scale);
      offset_y += 10 * font_scale + 2; // Line height + spacing
    }
  }
}

final _offset = MutableOffset(0, 0);

// Extension methods to match the BitmapText API
extension VectorTextExtensions on VectorText {
  void tint(Color color) {
    paint.colorFilter = ColorFilter.mode(color, BlendMode.srcATop);
  }
}
