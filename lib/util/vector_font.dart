import 'dart:math';
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:stardash/core/common.dart';
import 'package:stardash/util/mutable.dart';

VectorFont? _vector_font;

VectorFont get vector_font => _vector_font ??= VectorFont._();

class _VectorChar {
  static double _find_width(List<_LineSegment> segments) {
    double it = 0.0;
    for (final segment in segments) {
      it = max(it, segment.start.x);
      it = max(it, segment.end.x);
    }
    return it + 2;
  }

  _VectorChar(this.segments, {double? width}) : this.width = width ?? _find_width(segments);

  final List<_LineSegment> segments;

  late final double width;
}

class _LineSegment {
  final Vector2 start;
  final Vector2 end;

  _LineSegment(this.start, this.end);
}

class VectorFont {
  static final Map<String, _VectorChar> _by_char = {};
  static final Map<int, _VectorChar> _by_code = {};

  static final _start = MutableOffset(0, 0);
  static final _end = MutableOffset(0, 0);
  static final _rng = Random();

  static const _char_size = 10.0; // Based on nominal 10 unit height

  bool may_glitch = true;

  VectorFont._() {
    if (_by_char.isEmpty) _init_chars();
  }

  double char_width(String char) => (_by_char[char]?.width ?? 8.0);

  double code_width(int code) => (_by_code[code]?.width ?? 8.0);

  double string_width(String text, double scale) {
    double width = 0;
    for (final char in text.runes) {
      width += char_width(String.fromCharCode(char)) * scale;
    }
    return width;
  }

  final _offset = MutableOffset(0, 0);

  void render_anchored(Canvas canvas, Paint paint, String text, Offset position, double scale, Anchor anchor) {
    _offset.dx = position.dx - string_width(text, scale) * anchor.x;
    _offset.dy = position.dy - _char_size * scale * anchor.y;
    render_string(canvas, paint, text, _offset, scale);
  }

  void render_string(Canvas canvas, Paint paint, String text, Offset position, double scale) {
    text = text.toUpperCase();

    double current_x = position.dx;

    final double char_height = _char_size * scale;

    for (final code in text.runes) {
      final it = _by_code[code];
      if (it == null) continue;

      // Calculate adjusted width with spacing factor and adjustment
      final adjusted_width = it.width * scale;

      // Adjust position Y because origin is bottom-left in definition
      final char_pos_y = position.dy - char_height;

      // Draw segments for the character
      for (final segment in it.segments) {
        _start.dx = current_x + segment.start.x * scale;
        _start.dy = char_pos_y + (_char_size - segment.start.y) * scale; // Invert Y
        _end.dx = current_x + segment.end.x * scale;
        _end.dy = char_pos_y + (_char_size - segment.end.y) * scale; // Invert Y
        _render_segment(paint, canvas);
      }

      // Move to next character position with adjusted spacing
      current_x += adjusted_width;
    }
  }

  void _render_segment(Paint paint, Canvas canvas) {
    final glitch = may_glitch && _rng.nextDouble() > 0.95;
    if (glitch) {
      final c = paint.color;
      paint.color = c.withValues(alpha: c.a * 0.5);
      canvas.drawLine(_start, _end, paint);
      paint.color = c;
    } else {
      canvas.drawLine(_start, _end, paint);
    }
  }

  void _init_chars() {
    // Define characters (simple blocky style)
    // Coordinates assume a 10-unit high character box, origin at bottom-left.

    _by_char[' '] = _VectorChar([], width: 4.0);

    // Digits
    _by_char['0'] = _VectorChar([
      _LineSegment(Vector2(1, 1), Vector2(7, 1)),
      _LineSegment(Vector2(7, 1), Vector2(7, 9)),
      _LineSegment(Vector2(7, 9), Vector2(1, 9)),
      _LineSegment(Vector2(1, 9), Vector2(1, 1)),
      _LineSegment(Vector2(1, 9), Vector2(7, 1)), // Diagonal strike
    ]);
    _by_char['1'] = _VectorChar([
      _LineSegment(Vector2(4, 1), Vector2(4, 9)),
      _LineSegment(Vector2(2, 7), Vector2(4, 9)),
    ]);
    _by_char['2'] = _VectorChar([
      _LineSegment(Vector2(1, 9), Vector2(7, 9)),
      _LineSegment(Vector2(7, 9), Vector2(7, 5)),
      _LineSegment(Vector2(7, 5), Vector2(1, 5)),
      _LineSegment(Vector2(1, 5), Vector2(1, 1)),
      _LineSegment(Vector2(1, 1), Vector2(7, 1)),
    ]);
    _by_char['3'] = _VectorChar([
      _LineSegment(Vector2(1, 9), Vector2(7, 9)),
      _LineSegment(Vector2(7, 9), Vector2(7, 1)),
      _LineSegment(Vector2(7, 5), Vector2(1, 5)),
      _LineSegment(Vector2(7, 1), Vector2(1, 1)),
    ]);
    _by_char['4'] = _VectorChar([
      _LineSegment(Vector2(1, 9), Vector2(1, 5)),
      _LineSegment(Vector2(1, 5), Vector2(7, 5)),
      _LineSegment(Vector2(7, 9), Vector2(7, 1)),
    ]);
    _by_char['5'] = _VectorChar([
      _LineSegment(Vector2(7, 9), Vector2(1, 9)),
      _LineSegment(Vector2(1, 9), Vector2(1, 5)),
      _LineSegment(Vector2(1, 5), Vector2(7, 5)),
      _LineSegment(Vector2(7, 5), Vector2(7, 1)),
      _LineSegment(Vector2(7, 1), Vector2(1, 1)),
    ]);
    _by_char['6'] = _VectorChar([
      _LineSegment(Vector2(7, 9), Vector2(1, 9)),
      _LineSegment(Vector2(1, 9), Vector2(1, 1)),
      _LineSegment(Vector2(1, 1), Vector2(7, 1)),
      _LineSegment(Vector2(7, 1), Vector2(7, 5)),
      _LineSegment(Vector2(7, 5), Vector2(1, 5)),
    ]);
    _by_char['7'] = _VectorChar([
      _LineSegment(Vector2(1, 9), Vector2(7, 9)),
      _LineSegment(Vector2(7, 9), Vector2(7, 1)),
    ]);
    _by_char['8'] = _VectorChar([
      _LineSegment(Vector2(1, 1), Vector2(7, 1)),
      _LineSegment(Vector2(7, 1), Vector2(7, 9)),
      _LineSegment(Vector2(7, 9), Vector2(1, 9)),
      _LineSegment(Vector2(1, 9), Vector2(1, 1)),
      _LineSegment(Vector2(1, 5), Vector2(7, 5)), // Mid line
    ]);
    _by_char['9'] = _VectorChar([
      _LineSegment(Vector2(1, 1), Vector2(7, 1)),
      _LineSegment(Vector2(7, 1), Vector2(7, 9)),
      _LineSegment(Vector2(7, 9), Vector2(1, 9)),
      _LineSegment(Vector2(1, 9), Vector2(1, 5)),
      _LineSegment(Vector2(1, 5), Vector2(7, 5)),
    ]);

    // Letters
    _by_char['A'] = _VectorChar([
      _LineSegment(Vector2(1, 1), Vector2(1, 7)),
      _LineSegment(Vector2(1, 7), Vector2(4, 9)),
      _LineSegment(Vector2(4, 9), Vector2(7, 7)),
      _LineSegment(Vector2(7, 7), Vector2(7, 1)),
      _LineSegment(Vector2(1, 5), Vector2(7, 5)), // Mid line
    ]);
    _by_char['B'] = _VectorChar([
      _LineSegment(Vector2(1, 1), Vector2(1, 9)),
      _LineSegment(Vector2(1, 9), Vector2(5, 9)),
      _LineSegment(Vector2(5, 9), Vector2(7, 7)),
      _LineSegment(Vector2(7, 7), Vector2(5, 5)),
      _LineSegment(Vector2(5, 5), Vector2(1, 5)),
      _LineSegment(Vector2(5, 5), Vector2(7, 3)),
      _LineSegment(Vector2(7, 3), Vector2(5, 1)),
      _LineSegment(Vector2(5, 1), Vector2(1, 1)),
    ]);
    _by_char['C'] = _VectorChar([
      _LineSegment(Vector2(7, 9), Vector2(1, 9)),
      _LineSegment(Vector2(1, 9), Vector2(1, 1)),
      _LineSegment(Vector2(1, 1), Vector2(7, 1)),
    ]);
    _by_char['D'] = _VectorChar([
      _LineSegment(Vector2(1, 1), Vector2(1, 9)),
      _LineSegment(Vector2(1, 9), Vector2(5, 9)),
      _LineSegment(Vector2(5, 9), Vector2(7, 7)),
      _LineSegment(Vector2(7, 7), Vector2(7, 3)),
      _LineSegment(Vector2(7, 3), Vector2(5, 1)),
      _LineSegment(Vector2(5, 1), Vector2(1, 1)),
    ]);
    _by_char['E'] = _VectorChar([
      _LineSegment(Vector2(7, 9), Vector2(1, 9)),
      _LineSegment(Vector2(1, 9), Vector2(1, 1)),
      _LineSegment(Vector2(1, 1), Vector2(7, 1)),
      _LineSegment(Vector2(1, 5), Vector2(5, 5)),
    ]);
    _by_char['F'] = _VectorChar([
      _LineSegment(Vector2(7, 9), Vector2(1, 9)),
      _LineSegment(Vector2(1, 9), Vector2(1, 1)),
      _LineSegment(Vector2(1, 5), Vector2(5, 5)),
    ]);
    _by_char['G'] = _VectorChar([
      _LineSegment(Vector2(7, 9), Vector2(1, 9)),
      _LineSegment(Vector2(1, 9), Vector2(1, 1)),
      _LineSegment(Vector2(1, 1), Vector2(7, 1)),
      _LineSegment(Vector2(7, 1), Vector2(7, 5)),
      _LineSegment(Vector2(7, 5), Vector2(4, 5)),
    ]);
    _by_char['H'] = _VectorChar([
      _LineSegment(Vector2(1, 1), Vector2(1, 9)), // Left vertical
      _LineSegment(Vector2(7, 1), Vector2(7, 9)), // Right vertical
      _LineSegment(Vector2(1, 5), Vector2(7, 5)), // Mid horizontal
    ]);
    _by_char['I'] = _VectorChar([
      _LineSegment(Vector2(4, 1), Vector2(4, 9)),
      _LineSegment(Vector2(2, 9), Vector2(6, 9)),
      _LineSegment(Vector2(2, 1), Vector2(6, 1)),
    ]);
    _by_char['J'] = _VectorChar([
      _LineSegment(Vector2(7, 9), Vector2(7, 1)),
      _LineSegment(Vector2(7, 1), Vector2(1, 1)),
      _LineSegment(Vector2(1, 1), Vector2(1, 3)),
    ]);
    _by_char['K'] = _VectorChar([
      _LineSegment(Vector2(1, 1), Vector2(1, 9)),
      _LineSegment(Vector2(1, 5), Vector2(6, 9)),
      _LineSegment(Vector2(1, 5), Vector2(6, 1)),
    ]);
    _by_char['L'] = _VectorChar([
      _LineSegment(Vector2(1, 9), Vector2(1, 1)),
      _LineSegment(Vector2(1, 1), Vector2(7, 1)),
    ]);
    _by_char['M'] = _VectorChar([
      _LineSegment(Vector2(1, 1), Vector2(1, 9)),
      _LineSegment(Vector2(1, 9), Vector2(4, 5)),
      _LineSegment(Vector2(4, 5), Vector2(7, 9)),
      _LineSegment(Vector2(7, 9), Vector2(7, 1)),
    ]);
    _by_char['N'] = _VectorChar([
      _LineSegment(Vector2(1, 1), Vector2(1, 9)),
      _LineSegment(Vector2(1, 9), Vector2(7, 1)),
      _LineSegment(Vector2(7, 1), Vector2(7, 9)),
    ]);
    _by_char['O'] = _VectorChar([
      _LineSegment(Vector2(1, 1), Vector2(7, 1)),
      _LineSegment(Vector2(7, 1), Vector2(7, 9)),
      _LineSegment(Vector2(7, 9), Vector2(1, 9)),
      _LineSegment(Vector2(1, 9), Vector2(1, 1)),
    ]);
    _by_char['P'] = _VectorChar([
      _LineSegment(Vector2(1, 1), Vector2(1, 9)),
      _LineSegment(Vector2(1, 9), Vector2(7, 9)),
      _LineSegment(Vector2(7, 9), Vector2(7, 5)),
      _LineSegment(Vector2(7, 5), Vector2(1, 5)),
    ]);
    _by_char['Q'] = _VectorChar([
      _LineSegment(Vector2(1, 1), Vector2(7, 1)),
      _LineSegment(Vector2(7, 1), Vector2(7, 9)),
      _LineSegment(Vector2(7, 9), Vector2(1, 9)),
      _LineSegment(Vector2(1, 9), Vector2(1, 1)),
      _LineSegment(Vector2(5, 3), Vector2(7, 1)),
    ]);
    _by_char['R'] = _VectorChar([
      _LineSegment(Vector2(1, 1), Vector2(1, 9)),
      _LineSegment(Vector2(1, 9), Vector2(5, 9)),
      _LineSegment(Vector2(5, 9), Vector2(7, 7)),
      _LineSegment(Vector2(7, 7), Vector2(5, 5)),
      _LineSegment(Vector2(5, 5), Vector2(1, 5)), // Mid horizontal
      _LineSegment(Vector2(5, 5), Vector2(7, 1)), // Diagonal leg
    ]);
    _by_char['S'] = _VectorChar([
      _LineSegment(Vector2(7, 9), Vector2(1, 9)),
      _LineSegment(Vector2(1, 9), Vector2(1, 5)),
      _LineSegment(Vector2(1, 5), Vector2(7, 5)),
      _LineSegment(Vector2(7, 5), Vector2(7, 1)),
      _LineSegment(Vector2(7, 1), Vector2(1, 1)),
    ]);
    _by_char['T'] = _VectorChar([
      _LineSegment(Vector2(1, 9), Vector2(7, 9)), // Top bar
      _LineSegment(Vector2(4, 9), Vector2(4, 1)), // Vertical stem
    ]);
    _by_char['U'] = _VectorChar([
      _LineSegment(Vector2(1, 9), Vector2(1, 1)),
      _LineSegment(Vector2(1, 1), Vector2(7, 1)),
      _LineSegment(Vector2(7, 1), Vector2(7, 9)),
    ]);
    _by_char['V'] = _VectorChar([
      _LineSegment(Vector2(1, 9), Vector2(4, 1)),
      _LineSegment(Vector2(4, 1), Vector2(7, 9)),
    ]);
    _by_char['W'] = _VectorChar([
      _LineSegment(Vector2(1, 9), Vector2(1, 1)),
      _LineSegment(Vector2(1, 1), Vector2(4, 3)),
      _LineSegment(Vector2(4, 3), Vector2(7, 1)),
      _LineSegment(Vector2(7, 1), Vector2(7, 9)),
    ]);
    _by_char['X'] = _VectorChar([
      _LineSegment(Vector2(1, 1), Vector2(7, 9)),
      _LineSegment(Vector2(1, 9), Vector2(7, 1)),
    ]);
    _by_char['Y'] = _VectorChar([
      _LineSegment(Vector2(1, 9), Vector2(4, 5)),
      _LineSegment(Vector2(4, 5), Vector2(7, 9)),
      _LineSegment(Vector2(4, 5), Vector2(4, 1)),
    ]);
    _by_char['Z'] = _VectorChar([
      _LineSegment(Vector2(1, 9), Vector2(7, 9)),
      _LineSegment(Vector2(7, 9), Vector2(1, 1)),
      _LineSegment(Vector2(1, 1), Vector2(7, 1)),
    ]);

    // Lowercase letters
    _by_char['a'] = _VectorChar([
      _LineSegment(Vector2(1, 1), Vector2(7, 1)),
      _LineSegment(Vector2(7, 1), Vector2(7, 5)),
      _LineSegment(Vector2(7, 5), Vector2(1, 5)),
      _LineSegment(Vector2(1, 5), Vector2(1, 1)),
      _LineSegment(Vector2(7, 5), Vector2(7, 3)),
    ]);
    _by_char['b'] = _VectorChar([
      _LineSegment(Vector2(1, 1), Vector2(1, 9)),
      _LineSegment(Vector2(1, 1), Vector2(6, 1)),
      _LineSegment(Vector2(6, 1), Vector2(7, 2)),
      _LineSegment(Vector2(7, 2), Vector2(7, 4)),
      _LineSegment(Vector2(7, 4), Vector2(6, 5)),
      _LineSegment(Vector2(6, 5), Vector2(1, 5)),
    ]);
    _by_char['c'] = _VectorChar([
      _LineSegment(Vector2(7, 5), Vector2(1, 5)),
      _LineSegment(Vector2(1, 5), Vector2(1, 1)),
      _LineSegment(Vector2(1, 1), Vector2(7, 1)),
    ]);
    _by_char['d'] = _VectorChar([
      _LineSegment(Vector2(7, 1), Vector2(7, 9)),
      _LineSegment(Vector2(7, 1), Vector2(1, 1)),
      _LineSegment(Vector2(1, 1), Vector2(1, 5)),
      _LineSegment(Vector2(1, 5), Vector2(7, 5)),
    ]);
    _by_char['e'] = _VectorChar([
      _LineSegment(Vector2(1, 3), Vector2(7, 3)),
      _LineSegment(Vector2(7, 3), Vector2(7, 5)),
      _LineSegment(Vector2(7, 5), Vector2(1, 5)),
      _LineSegment(Vector2(1, 5), Vector2(1, 1)),
      _LineSegment(Vector2(1, 1), Vector2(7, 1)),
    ]);
    _by_char['f'] = _VectorChar([
      _LineSegment(Vector2(3, 1), Vector2(3, 7)),
      _LineSegment(Vector2(3, 7), Vector2(5, 9)),
      _LineSegment(Vector2(1, 5), Vector2(5, 5)),
    ]);
    _by_char['g'] = _VectorChar([
      _LineSegment(Vector2(7, 5), Vector2(1, 5)),
      _LineSegment(Vector2(1, 5), Vector2(1, 1)),
      _LineSegment(Vector2(1, 1), Vector2(7, 1)),
      _LineSegment(Vector2(7, 1), Vector2(7, 5)),
      _LineSegment(Vector2(7, 0), Vector2(7, -2)),
      _LineSegment(Vector2(7, -2), Vector2(1, -2)),
    ]);
    _by_char['h'] = _VectorChar([
      _LineSegment(Vector2(1, 1), Vector2(1, 9)),
      _LineSegment(Vector2(1, 5), Vector2(5, 5)),
      _LineSegment(Vector2(5, 5), Vector2(7, 3)),
      _LineSegment(Vector2(7, 3), Vector2(7, 1)),
    ]);
    _by_char['i'] = _VectorChar([
      _LineSegment(Vector2(4, 1), Vector2(4, 5)),
      _LineSegment(Vector2(4, 7), Vector2(4, 8)),
    ]);
    _by_char['j'] = _VectorChar([
      _LineSegment(Vector2(5, 5), Vector2(5, -2)),
      _LineSegment(Vector2(5, -2), Vector2(1, -2)),
      _LineSegment(Vector2(5, 7), Vector2(5, 8)),
    ]);
    _by_char['k'] = _VectorChar([
      _LineSegment(Vector2(1, 1), Vector2(1, 9)),
      _LineSegment(Vector2(1, 3), Vector2(6, 5)),
      _LineSegment(Vector2(1, 3), Vector2(6, 1)),
    ]);
    _by_char['l'] = _VectorChar([
      _LineSegment(Vector2(4, 1), Vector2(4, 9)),
    ]);
    _by_char['m'] = _VectorChar([
      _LineSegment(Vector2(1, 1), Vector2(1, 5)),
      _LineSegment(Vector2(1, 5), Vector2(3, 5)),
      _LineSegment(Vector2(3, 5), Vector2(3, 1)),
      _LineSegment(Vector2(3, 5), Vector2(5, 5)),
      _LineSegment(Vector2(5, 5), Vector2(5, 1)),
    ]);
    _by_char['n'] = _VectorChar([
      _LineSegment(Vector2(1, 1), Vector2(1, 5)),
      _LineSegment(Vector2(1, 5), Vector2(5, 5)),
      _LineSegment(Vector2(5, 5), Vector2(7, 3)),
      _LineSegment(Vector2(7, 3), Vector2(7, 1)),
    ]);
    _by_char['o'] = _VectorChar([
      _LineSegment(Vector2(1, 1), Vector2(7, 1)),
      _LineSegment(Vector2(7, 1), Vector2(7, 5)),
      _LineSegment(Vector2(7, 5), Vector2(1, 5)),
      _LineSegment(Vector2(1, 5), Vector2(1, 1)),
    ]);
    _by_char['p'] = _VectorChar([
      _LineSegment(Vector2(1, -2), Vector2(1, 5)),
      _LineSegment(Vector2(1, 5), Vector2(7, 5)),
      _LineSegment(Vector2(7, 5), Vector2(7, 1)),
      _LineSegment(Vector2(7, 1), Vector2(1, 1)),
    ]);
    _by_char['q'] = _VectorChar([
      _LineSegment(Vector2(7, -2), Vector2(7, 5)),
      _LineSegment(Vector2(7, 5), Vector2(1, 5)),
      _LineSegment(Vector2(1, 5), Vector2(1, 1)),
      _LineSegment(Vector2(1, 1), Vector2(7, 1)),
    ]);
    _by_char['r'] = _VectorChar([
      _LineSegment(Vector2(1, 1), Vector2(1, 5)),
      _LineSegment(Vector2(1, 5), Vector2(4, 5)),
      _LineSegment(Vector2(4, 5), Vector2(7, 3)),
    ]);
    _by_char['s'] = _VectorChar([
      _LineSegment(Vector2(7, 5), Vector2(1, 5)),
      _LineSegment(Vector2(1, 5), Vector2(1, 3)),
      _LineSegment(Vector2(1, 3), Vector2(7, 3)),
      _LineSegment(Vector2(7, 3), Vector2(7, 1)),
      _LineSegment(Vector2(7, 1), Vector2(1, 1)),
    ]);
    _by_char['t'] = _VectorChar([
      _LineSegment(Vector2(4, 1), Vector2(4, 7)),
      _LineSegment(Vector2(2, 5), Vector2(6, 5)),
    ]);
    _by_char['u'] = _VectorChar([
      _LineSegment(Vector2(1, 5), Vector2(1, 1)),
      _LineSegment(Vector2(1, 1), Vector2(7, 1)),
      _LineSegment(Vector2(7, 1), Vector2(7, 5)),
    ]);
    _by_char['v'] = _VectorChar([
      _LineSegment(Vector2(1, 5), Vector2(4, 1)),
      _LineSegment(Vector2(4, 1), Vector2(7, 5)),
    ]);
    _by_char['w'] = _VectorChar([
      _LineSegment(Vector2(1, 5), Vector2(1, 1)),
      _LineSegment(Vector2(1, 1), Vector2(3, 3)),
      _LineSegment(Vector2(3, 3), Vector2(5, 1)),
      _LineSegment(Vector2(5, 1), Vector2(5, 5)),
    ]);
    _by_char['x'] = _VectorChar([
      _LineSegment(Vector2(1, 1), Vector2(7, 5)),
      _LineSegment(Vector2(1, 5), Vector2(7, 1)),
    ]);
    _by_char['y'] = _VectorChar([
      _LineSegment(Vector2(1, 5), Vector2(4, 1)),
      _LineSegment(Vector2(4, 1), Vector2(7, 5)),
      _LineSegment(Vector2(4, 1), Vector2(1, -2)),
    ]);
    _by_char['z'] = _VectorChar([
      _LineSegment(Vector2(1, 5), Vector2(7, 5)),
      _LineSegment(Vector2(7, 5), Vector2(1, 1)),
      _LineSegment(Vector2(1, 1), Vector2(7, 1)),
    ]);

    // Punctuation and symbols
    _by_char['.'] = _VectorChar([
      _LineSegment(Vector2(1, 1), Vector2(2, 1)),
    ]);
    _by_char[','] = _VectorChar([
      _LineSegment(Vector2(1, 1), Vector2(2, 0)),
    ]);
    _by_char['!'] = _VectorChar([
      _LineSegment(Vector2(1, 2), Vector2(1, 9)),
      _LineSegment(Vector2(1, 1), Vector2(1, 1.5)),
    ]);
    _by_char['?'] = _VectorChar([
      _LineSegment(Vector2(1, 7), Vector2(1, 9)),
      _LineSegment(Vector2(1, 9), Vector2(5, 9)),
      _LineSegment(Vector2(5, 9), Vector2(5, 5)),
      _LineSegment(Vector2(5, 5), Vector2(3, 5)),
      _LineSegment(Vector2(3, 5), Vector2(3, 3)),
      _LineSegment(Vector2(3, 1), Vector2(3, 2)),
    ]);
    _by_char[':'] = _VectorChar([
      _LineSegment(Vector2(1, 2), Vector2(1, 2.5)),
      _LineSegment(Vector2(1, 5), Vector2(1, 5.5)),
    ]);
    _by_char[';'] = _VectorChar([
      _LineSegment(Vector2(1, 5), Vector2(1, 5.5)),
      _LineSegment(Vector2(1, 2), Vector2(2, 1)),
    ]);
    _by_char['-'] = _VectorChar([
      _LineSegment(Vector2(1, 5), Vector2(5, 5)),
    ]);
    _by_char['_'] = _VectorChar([
      _LineSegment(Vector2(1, 1), Vector2(7, 1)),
    ]);
    _by_char['+'] = _VectorChar([
      _LineSegment(Vector2(1, 5), Vector2(7, 5)),
      _LineSegment(Vector2(4, 2), Vector2(4, 8)),
    ]);
    _by_char['='] = _VectorChar([
      _LineSegment(Vector2(1, 4), Vector2(7, 4)),
      _LineSegment(Vector2(1, 6), Vector2(7, 6)),
    ]);
    _by_char['('] = _VectorChar([
      _LineSegment(Vector2(5, 9), Vector2(3, 7)),
      _LineSegment(Vector2(3, 7), Vector2(3, 3)),
      _LineSegment(Vector2(3, 3), Vector2(5, 1)),
    ]);
    _by_char[')'] = _VectorChar([
      _LineSegment(Vector2(3, 9), Vector2(5, 7)),
      _LineSegment(Vector2(5, 7), Vector2(5, 3)),
      _LineSegment(Vector2(5, 3), Vector2(3, 1)),
    ]);
    _by_char['['] = _VectorChar([
      _LineSegment(Vector2(5, 9), Vector2(3, 9)),
      _LineSegment(Vector2(3, 9), Vector2(3, 1)),
      _LineSegment(Vector2(3, 1), Vector2(5, 1)),
    ]);
    _by_char[']'] = _VectorChar([
      _LineSegment(Vector2(3, 9), Vector2(5, 9)),
      _LineSegment(Vector2(5, 9), Vector2(5, 1)),
      _LineSegment(Vector2(5, 1), Vector2(3, 1)),
    ]);
    _by_char['{'] = _VectorChar([
      _LineSegment(Vector2(5, 9), Vector2(4, 9)),
      _LineSegment(Vector2(4, 9), Vector2(3, 8)),
      _LineSegment(Vector2(3, 8), Vector2(3, 6)),
      _LineSegment(Vector2(3, 6), Vector2(2, 5)),
      _LineSegment(Vector2(2, 5), Vector2(3, 4)),
      _LineSegment(Vector2(3, 4), Vector2(3, 2)),
      _LineSegment(Vector2(3, 2), Vector2(4, 1)),
      _LineSegment(Vector2(4, 1), Vector2(5, 1)),
    ]);
    _by_char['}'] = _VectorChar([
      _LineSegment(Vector2(3, 9), Vector2(4, 9)),
      _LineSegment(Vector2(4, 9), Vector2(5, 8)),
      _LineSegment(Vector2(5, 8), Vector2(5, 6)),
      _LineSegment(Vector2(5, 6), Vector2(6, 5)),
      _LineSegment(Vector2(6, 5), Vector2(5, 4)),
      _LineSegment(Vector2(5, 4), Vector2(5, 2)),
      _LineSegment(Vector2(5, 2), Vector2(4, 1)),
      _LineSegment(Vector2(4, 1), Vector2(3, 1)),
    ]);
    _by_char['/'] = _VectorChar([
      _LineSegment(Vector2(1, 1), Vector2(7, 9)),
    ]);
    _by_char['\\'] = _VectorChar([
      _LineSegment(Vector2(1, 9), Vector2(7, 1)),
    ]);
    _by_char['|'] = _VectorChar([
      _LineSegment(Vector2(4, 1), Vector2(4, 9)),
    ]);
    _by_char['"'] = _VectorChar([
      _LineSegment(Vector2(2, 7), Vector2(2, 9)),
      _LineSegment(Vector2(5, 7), Vector2(5, 9)),
    ]);
    _by_char['\''] = _VectorChar([
      _LineSegment(Vector2(3, 7), Vector2(3, 9)),
    ]);
    _by_char['`'] = _VectorChar([
      _LineSegment(Vector2(2, 9), Vector2(4, 7)),
    ]);
    _by_char['~'] = _VectorChar([
      _LineSegment(Vector2(1, 5), Vector2(3, 6)),
      _LineSegment(Vector2(3, 6), Vector2(5, 5)),
      _LineSegment(Vector2(5, 5), Vector2(7, 6)),
    ]);
    _by_char['^'] = _VectorChar([
      _LineSegment(Vector2(2, 7), Vector2(4, 9)),
      _LineSegment(Vector2(4, 9), Vector2(6, 7)),
    ]);
    _by_char['&'] = _VectorChar([
      _LineSegment(Vector2(7, 1), Vector2(5, 3)),
      _LineSegment(Vector2(5, 3), Vector2(3, 1)),
      _LineSegment(Vector2(3, 1), Vector2(1, 3)),
      _LineSegment(Vector2(1, 3), Vector2(1, 4)),
      _LineSegment(Vector2(1, 4), Vector2(3, 6)),
      _LineSegment(Vector2(3, 6), Vector2(1, 9)),
      _LineSegment(Vector2(1, 9), Vector2(3, 9)),
      _LineSegment(Vector2(3, 9), Vector2(7, 5)),
    ]);
    _by_char['*'] = _VectorChar([
      _LineSegment(Vector2(4, 3), Vector2(4, 7)),
      _LineSegment(Vector2(2, 4), Vector2(6, 6)),
      _LineSegment(Vector2(2, 6), Vector2(6, 4)),
    ]);
    _by_char['#'] = _VectorChar([
      _LineSegment(Vector2(2, 1), Vector2(2, 9)),
      _LineSegment(Vector2(6, 1), Vector2(6, 9)),
      _LineSegment(Vector2(1, 3), Vector2(7, 3)),
      _LineSegment(Vector2(1, 7), Vector2(7, 7)),
    ]);
    _by_char['\$'] = _VectorChar([
      _LineSegment(Vector2(7, 7), Vector2(1, 7)),
      _LineSegment(Vector2(1, 7), Vector2(1, 5)),
      _LineSegment(Vector2(1, 5), Vector2(7, 5)),
      _LineSegment(Vector2(7, 5), Vector2(7, 3)),
      _LineSegment(Vector2(7, 3), Vector2(1, 3)),
      _LineSegment(Vector2(4, 2), Vector2(4, 8)),
    ]);
    _by_char['%'] = _VectorChar([
      _LineSegment(Vector2(1, 1), Vector2(7, 9)),
      _LineSegment(Vector2(2, 7), Vector2(2, 9)),
      _LineSegment(Vector2(2, 9), Vector2(4, 9)),
      _LineSegment(Vector2(4, 9), Vector2(4, 7)),
      _LineSegment(Vector2(4, 7), Vector2(2, 7)),
      _LineSegment(Vector2(4, 1), Vector2(6, 1)),
      _LineSegment(Vector2(6, 1), Vector2(6, 3)),
      _LineSegment(Vector2(6, 3), Vector2(4, 3)),
      _LineSegment(Vector2(4, 3), Vector2(4, 1)),
    ]);
    _by_char['@'] = _VectorChar([
      _LineSegment(Vector2(5, 5), Vector2(5, 3)),
      _LineSegment(Vector2(5, 3), Vector2(3, 3)),
      _LineSegment(Vector2(3, 3), Vector2(3, 5)),
      _LineSegment(Vector2(3, 5), Vector2(5, 5)),
      _LineSegment(Vector2(5, 5), Vector2(7, 5)),
      _LineSegment(Vector2(7, 5), Vector2(7, 1)),
      _LineSegment(Vector2(7, 1), Vector2(1, 1)),
      _LineSegment(Vector2(1, 1), Vector2(1, 9)),
      _LineSegment(Vector2(1, 9), Vector2(7, 9)),
      _LineSegment(Vector2(7, 9), Vector2(7, 7)),
    ]);

    for (var it in _by_char.entries) {
      _by_code[it.key.codeUnitAt(0)] = it.value;
    }
  }
}
