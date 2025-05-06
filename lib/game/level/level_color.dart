import 'dart:ui';

enum LevelColor {
  Blue(
    start_color: Color(0xFF0080FF), // Bright Blue
    end_color: Color(0xFF00008B), // Dark Blue
  ),
  Red(
    start_color: Color(0xFFFF0000), // Bright Red
    end_color: Color(0xFF8B0000), // Dark Red
  ),
  Green(
    start_color: Color(0xFF00FF00), // Bright Green
    end_color: Color(0xFF006400), // Dark Green
  ),
  Yellow(
    start_color: Color(0xFFFFFF00), // Bright Yellow
    end_color: Color(0xFFB8860B), // Dark Goldenrod (Dark Yellow)
  ),
  Cyan(
    start_color: Color(0xFF00FFFF), // Bright Cyan
    end_color: Color(0xFF008B8B), // Dark Cyan
  ),
  Magenta(
    start_color: Color(0xFFFF00FF), // Bright Magenta
    end_color: Color(0xFF8B008B), // Dark Magenta
  ),
  White(
    start_color: Color(0xFFFFFFFF), // White
    end_color: Color(0xFF696969), // Dim Gray (Darker Gray)
  ),
  ;

  final Color start_color; // Color for the outer edge
  final Color end_color; // Color for the deep edge

  const LevelColor({
    required this.start_color,
    required this.end_color,
  });
}
