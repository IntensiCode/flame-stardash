import 'dart:math';

import 'package:dart_extensions_methods/dart_extension_methods.dart';
import 'package:flame/extensions.dart';

enum LevelPathType {
  Flat(scaleXY: 1.0, translateX: 0.0, translateY: 0.0),
  HalfPipe(scaleXY: 1.5, translateX: 0.0, translateY: -0.25),
  HalfEight(scaleXY: 1.5, translateX: 0.0, translateY: -0.20),
  V(scaleXY: 1.75, translateX: 0.0, translateY: -0.35),
  FullPipe(scaleXY: 1.0, translateX: 0.0, translateY: 0.0, closed: true),
  Eight(scaleXY: 1.0, translateX: 0.0, translateY: 0.2, closed: true),
  DownSquare(scaleXY: 1.0, translateX: 0.0, translateY: 0.2, closed: true),
  DownPipe(scaleXY: 1.0, translateX: 0.0, translateY: 0.2, closed: true),
  DownCross(scaleXY: 1.0, translateX: 0.0, translateY: 0.2, closed: true),
  DownStar(scaleXY: 1.0, translateX: 0.0, translateY: 0.15, closed: true),
  ;

  final double scaleXY;
  final double translateX;
  final double translateY;
  final bool closed;

  const LevelPathType({
    required this.scaleXY,
    required this.translateX,
    required this.translateY,
    this.closed = false,
  });

  Vector2 get scale => Vector2(scaleXY, scaleXY);

  Vector2 get translate => Vector2(translateX, translateY);
}

class LevelPath {
  final List<Vector2> vertices;

  LevelPath(this.vertices);

  static final Map<LevelPathType, LevelPath> definitions = {
    LevelPathType.DownCross: _createDownCross(),
    LevelPathType.DownPipe: _createDownPipe(),
    LevelPathType.DownSquare: _createDownSquare(),
    LevelPathType.DownStar: _createDownStar(),
    LevelPathType.Eight: _createEight(),
    LevelPathType.Flat: _createFlat(),
    LevelPathType.FullPipe: _createFullCircle(),
    LevelPathType.HalfEight: _createHalfEight(),
    LevelPathType.HalfPipe: _createHalfPipe(),
    LevelPathType.V: _createV(),
  };

  static LevelPath _createHalfPipe() {
    // Replaced trigonometric calculation with hardcoded vertices
    final vertices = <Vector2>[
      Vector2(-1.0, 0.0), // Left, top
      Vector2(-0.92, 0.38), // approx -cos(70deg), sin(70deg)
      Vector2(-0.71, 0.71), // approx -cos(45deg), sin(45deg)
      Vector2(-0.38, 0.92), // approx -cos(20deg), sin(20deg)
      Vector2(0.0, 1.0), // Center, bottom
      Vector2(0.38, 0.92), // approx cos(20deg), sin(20deg)
      Vector2(0.71, 0.71), // approx cos(45deg), sin(45deg)
      Vector2(0.92, 0.38), // approx cos(70deg), sin(70deg)
      Vector2(1.0, 0.0), // Right, top
    ];
    // Note: Original calculation used -sin(angle) for y, mapping to screen coords later.
    // These hardcoded values assume y=0 is the top flat line and y=1 is the bottom point.
    // The Level component's _scaleVertices handles the inversion for screen rendering.
    return LevelPath(vertices);
  }

  static LevelPath _createFullCircle() {
    // Define vertices starting at top-center (0, -1)
    // and proceeding CLOCKWISE.
    final vertices = <Vector2>[
      // Start at 270 degrees and go clockwise
      Vector2(0.0, -1.0), // 1: Top Center (270 deg)
      Vector2(-0.38, -0.92), // 2: (247.5 deg)
      Vector2(-0.71, -0.71), // 3: (225 deg)
      Vector2(-0.92, -0.38), // 4: (202.5 deg)
      Vector2(-1.0, 0.0), // 5: Left Center (180 deg)
      Vector2(-0.92, 0.38), // 6: (157.5 deg)
      Vector2(-0.71, 0.71), // 7: (135 deg)
      Vector2(-0.38, 0.92), // 8: (112.5 deg)
      Vector2(0.0, 1.0), // 9: Bottom Center (90 deg)
      Vector2(0.38, 0.92), // 10: (67.5 deg)
      Vector2(0.71, 0.71), // 11: (45 deg)
      Vector2(0.92, 0.38), // 12: (22.5 deg)
      Vector2(1.0, 0.0), // 13: Right Center (0 deg)
      Vector2(0.92, -0.38), // 14: (337.5 deg)
      Vector2(0.71, -0.71), // 15: (315 deg)
      Vector2(0.38, -0.92), // 16: (292.5 deg)
    ];
    return LevelPath(vertices);
  }

  static LevelPath _createHalfEight() {
    // Vertices for the bottom half of a figure-eight shape with central dent
    // 14 vertices, normalized coords: x (-1 to 1), y (0 to 1)
    final vertices = <Vector2>[
      Vector2(-1.0, 0.0), // 1: Start Left
      Vector2(-0.95, 0.3), // 2: Left curve down
      Vector2(-0.8, 0.6), // 3
      Vector2(-0.6, 0.8), // 4
      Vector2(-0.3, 0.8), // 5: Corner before dent
      Vector2(-0.1, 0.7), // 6: Top dent left
      Vector2(0.1, 0.7), // 9: Top dent right
      Vector2(0.3, 0.8), // 10: Corner after dent
      Vector2(0.6, 0.8), // 11: Right curve up
      Vector2(0.8, 0.6), // 12
      Vector2(0.95, 0.3), // 13
      Vector2(1.0, 0.0), // 14: End Right
    ];
    return LevelPath(vertices);
  }

  static LevelPath _createV() {
    // V-shape with 15 vertices (7 per arm + 1 bottom)
    // Normalized coords: x (-1 to 1), y (0 to 1)
    final vertices = <Vector2>[
      // Left Arm (7 vertices)
      Vector2(-1.0, 0.0), // 1: Top Left
      Vector2(-0.857, 0.143), // 2
      Vector2(-0.714, 0.286), // 3
      Vector2(-0.571, 0.429), // 4
      Vector2(-0.429, 0.571), // 5
      Vector2(-0.286, 0.714), // 6
      Vector2(-0.143, 0.857), // 7
      // Bottom Point (1 vertex)
      Vector2(0.0, 1.0), // 8: Bottom Center
      // Right Arm (7 vertices, starting from bottom)
      Vector2(0.143, 0.857), // 9
      Vector2(0.286, 0.714), // 10
      Vector2(0.429, 0.571), // 11
      Vector2(0.571, 0.429), // 12
      Vector2(0.714, 0.286), // 13
      Vector2(0.857, 0.143), // 14
      Vector2(1.0, 0.0), // 15: Top Right
    ];
    return LevelPath(vertices);
  }

  static LevelPath _createDownPipe() {
    // 12-sided ellipse, normalized coords: x (-1 to 1), y (-1 to 1), shifted down
    const int sides = 12;
    const double scaleX = 0.8;
    const double scaleY = 0.9;
    const double translateY = -0.3;
    final double step = 2 * pi / sides;
    final vertices = List<Vector2>.generate(sides, (i) {
      final angle = -pi / 2 - i * step; // Start at top (270 deg)
      return Vector2(
        cos(angle) * scaleX,
        sin(angle) * scaleY + translateY,
      );
    });
    return LevelPath(vertices);
  }

  static LevelPath _createDownSquare() {
    // Scale/Translate constants defined locally as requested
    const double scaleX = 0.8;
    const double scaleY = 0.9;
    const double translateY = -0.3;

    // Base vertices, rotated to start at Top-Center (0.0, 1.0)
    // This aligns gridX=0 with the Bottom-Center
    final baseVertices = <Vector2>[
      Vector2(0.0, -1.0),
      Vector2(-0.5, -1.0),
      Vector2(-1.0, -1.0),
      Vector2(-1.0, -0.5),
      Vector2(-1.0, 0.0),
      Vector2(-1.0, 0.5),
      Vector2(-1.0, 1.0),
      Vector2(-0.5, 1.0),
      Vector2(0.0, 1.0),
      Vector2(0.5, 1.0),
      Vector2(1.0, 1.0),
      Vector2(1.0, 0.5),
      Vector2(1.0, 0.0),
      Vector2(1.0, -0.5),
      Vector2(1.0, -1.0),
      Vector2(0.5, -1.0),
    ];

    // Apply local scale and translation
    final transformedVertices = baseVertices.map((v) {
      return Vector2(
        v.x * scaleX,
        v.y * scaleY + translateY,
      );
    }).toList(); // Convert the Iterable back to a List

    // Path is closed. Consider restoring the 'closed' property handling.
    return LevelPath(transformedVertices);
  }

  static LevelPath _createDownStar() {
    // Scale/Translate constants defined locally as requested
    const double scaleX = 1.2;
    const double scaleY = 0.9;
    const double translateY = -0.2;

    // Base vertices for the cross shape (12 points, CCW from top-center-left)
    final topLeft = <Vector2>[
      // Vector2(0, -1.0),
      Vector2(-0.2, -1.0),
      Vector2(-0.3, -0.6),
      Vector2(-0.5, -0.5),
      Vector2(-0.6, -0.3),
      Vector2(-1.0, -0.2),
      // Vector2(-1.0, 0.0),
    ];

    final bottomLeft = topLeft.map((v) => Vector2(v.x, -v.y)).toList()..reverse();
    final bottomRight = bottomLeft.map((v) => Vector2(-v.x, v.y)).toList()..reverse();
    final topRight = bottomRight.map((v) => Vector2(v.x, -v.y)).toList()..reverse();
    final vertices = (topLeft + bottomLeft + bottomRight + topRight).distinctBy((v) => v.toString());

    // Apply local scale and translation
    final transformed = vertices
        .map((v) {
          return Vector2(
            v.x * scaleX,
            v.y * scaleY + translateY,
          );
        })
        .toList()
        .distinctBy((v) => v.toString());

    // Path is closed. Consider restoring the 'closed' property handling.
    return LevelPath(transformed);
  }

  static LevelPath _createDownCross() {
    // Scale/Translate constants defined locally as requested
    const double scaleX = 0.8;
    const double scaleY = 0.9;
    const double translateY = -0.3;

    // Base vertices for the cross shape (12 points, CCW from top-center-left)
    final baseVertices = <Vector2>[
      Vector2(0, -1.0),
      Vector2(-0.6, -1.0),
      Vector2(-0.6, -0.6),
      Vector2(-1.0, -0.6),
      Vector2(-1.0, 0.0),
      Vector2(-1.0, 0.6),
      Vector2(-0.7, 0.6),
      Vector2(-0.6, 1.0),
      Vector2(-0.0, 1.0),
      Vector2(0.6, 1.0),
      Vector2(0.6, 0.6),
      Vector2(1.0, 0.6),
      Vector2(1.0, 0.0),
      Vector2(1.0, -0.6),
      Vector2(0.6, -0.6),
      Vector2(0.6, -1.0),
    ];

    // Apply local scale and translation
    final transformedVertices = baseVertices.map((v) {
      return Vector2(
        v.x * scaleX,
        v.y * scaleY + translateY,
      );
    }).toList();

    // Path is closed. Consider restoring the 'closed' property handling.
    return LevelPath(transformedVertices);
  }

  static LevelPath _createFlat() {
    const double scaleX = 1.5;
    const double scaleY = 1.2;
    const double translateY = -0.25;
    // Flat horizontal line with 11 vertices, normalized coords: x (-1 to 1), y (0)
    final vertices = <Vector2>[
      Vector2(-1.0, 0.8), // Leftmost point
      Vector2(-0.8, 0.8),
      Vector2(-0.6, 0.8),
      Vector2(-0.4, 0.8),
      Vector2(-0.2, 0.8),
      Vector2(0.0, 0.8), // Center point
      Vector2(0.2, 0.8),
      Vector2(0.4, 0.8),
      Vector2(0.6, 0.8),
      Vector2(0.8, 0.8),
      Vector2(1.0, 0.8), // Rightmost point
    ];
    // Apply local scale and translation
    final transformedVertices = vertices.map((v) {
      return Vector2(
        v.x * scaleX,
        v.y * scaleY + translateY,
      );
    }).toList();
    return LevelPath(transformedVertices);
  }

  static LevelPath _createEight() {
    // Internal Scale/Translate constants matching DownCross/DownSquare etc.
    const double scaleX = 1.2;
    const double scaleY = 1.2;
    const double translateY = -0.25;

    // Hardcoded vertices based on user sketch (20 points)
    // Starts at Bottom-Center (0.0, 1.0) and proceeds clockwise
    final upper = <Vector2>[
      Vector2(0.0, -0.6), // 11: Top Center
      Vector2(-0.3, -0.6), // 12: Top flat left
      Vector2(-0.6, -0.7), // 13: Start left curve down
      Vector2(-1.0, -0.7), // 14
      Vector2(-1.2, -0.5), // 15
      Vector2(-1.3, 0.0), // 16: Leftmost point
      Vector2(-1.2, 0.5), // 17
      Vector2(-1.0, 0.7), // 18
      Vector2(-0.6, 0.7), // 19: End left curve up
      Vector2(-0.3, 0.6), // 20: Bottom flat left
      Vector2(0.0, 0.6), // 11: Top Center
    ];

    final lower = upper.reversed.map((v) => Vector2(-v.x, v.y)).toList();
    final vertices = (upper + lower).distinctBy((v) => v.toString());

    // Apply internal scale and translation
    final transformedVertices = vertices.map((v) {
      return Vector2(
        v.x * scaleX,
        v.y * scaleY + translateY,
      );
    }).toList();

    // Path is closed.
    return LevelPath(transformedVertices);
  }
}

// Basic math functions might be needed if dart:math isn't imported
// Assuming they are available or we'll add imports later if needed.
// Standard dart:math functions are likely available via flame/flutter.
// import 'dart:math' show cos hide sin; // Use dart:math cos
// import 'dart:math' as math show sin; // Use dart:math sin as math.sin to avoid clash

// double _cos(double radians) => math.cos(radians);
// double _sin(double radians) => math.sin(radians);
