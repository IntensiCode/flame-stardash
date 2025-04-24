import 'dart:math';

import 'package:dart_extensions_methods/dart_extension_methods.dart';
import 'package:flame/extensions.dart';
import 'package:stardash/util/extensions.dart';

class LevelPath {
  final List<Vector2> vertices;

  LevelPath(this.vertices);

  static List<Vector2> _transformed(
    List<Vector2> vertices, {
    double scale_x = 1.0,
    double scale_y = 1.0,
    double translate_x = 0.0,
    double translate_y = 0.0,
  }) =>
      vertices
          .map((v) => Vector2(v.x * scale_x + translate_x, v.y * scale_y + translate_y))
          .toList()
          .distinctBy((it) => it.toString());

  static LevelPath flat() {
    const int count = 14;
    final List<Vector2> vertices = List.generate(count, (i) => Vector2(-1.0 + i * (2.0 / (count - 1)), 0.0));
    return LevelPath(_transformed(vertices)); // , scale_x: 1.5, scale_y: 1.2));
  }

  static LevelPath half_pipe() {
    const int count = 14;

    final List<Vector2> vertices = List.generate(
      count,
          (i) {
        // Angle from pi (180°) to 0 (0°)
        final angle = pi - (pi * i / (count - 1));
        final x = cos(angle); // from -1 to 1
        final y = sin(angle); // from 0 (top) to 1 (bottom) and back to 0
        return Vector2(x, y);
      },
    );

    vertices.insert(0, Vector2(-1.0, -0.25));
    vertices.insert(0, Vector2(-1.0, -0.5));
    vertices.add(Vector2(1.0, -0.25));
    vertices.add(Vector2(1.0, -0.5));

    return LevelPath(_transformed(vertices, translate_y: -0.75));
  }

  static LevelPath half_eight() {
    final left = <Vector2>[
      Vector2(-1.2, -1.1),
      Vector2(-1.1, -0.7),
      Vector2(-1.0, -0.4),
      Vector2(-0.9, -0.2),
      Vector2(-0.7, -0.0),
      Vector2(-0.5, 0.1),
      Vector2(-0.3, 0.1),
      Vector2(-0.1, 0.0),
    ];
    final List<Vector2> right = left.reversed.map((v) => Vector2(-v.x, v.y)).toList();
    final vertices = [...left, ...right];
    return LevelPath(_transformed(vertices, translate_y: 0.2));
  }

  static LevelPath v() {
    const int side_count = 7;
    final List<Vector2> left = [];
    for (int i = 0; i < side_count; i++) {
      final t = i / (side_count - 1);
      final x = -1.25 * (1 - t) + -0.1 * t; // -0.1 is the x of the lowest point
      final y = 0.0 * (1 - t) + 1.0 * t - 0.75;
      left.add(Vector2(x, y));
    }
    final List<Vector2> right = left.reversed.map((v) => Vector2(-v.x, v.y)).toList();
    final vertices = [...left, ...right];
    return LevelPath(vertices);
  }

  static LevelPath stairs() {
    final left = <Vector2>[
      Vector2(-1.1, -0.9),
      Vector2(-1.1, -0.6),
      Vector2(-0.8, -0.6),
      Vector2(-0.8, -0.3),
      Vector2(-0.5, -0.3),
      Vector2(-0.5, 0.0),
      Vector2(-0.2, 0.0),
      Vector2(-0.2, 0.3),
    ];
    final List<Vector2> right = left.reversed.map((v) => Vector2(-v.x, v.y)).toList();
    final vertices = [...left, ...right];
    return LevelPath(_transformed(vertices));
  }

  static LevelPath heart() {
    final left = <Vector2>[
      Vector2(-0.15, -0.6),
      Vector2(-0.4, -0.7),
      Vector2(-0.7, -0.7),
      Vector2(-0.9, -0.5),
      Vector2(-0.9, -0.2),
      Vector2(-0.8, 0.1),
      Vector2(-0.6, 0.4),
      Vector2(-0.4, 0.7),
      Vector2(-0.15, 0.9),
    ];

    final right = left.reversed.map((v) => Vector2(-v.x, v.y)).toList();
    final vertices = (left + right).distinctBy((v) => v.toString());
    return LevelPath(_transformed(vertices, scale_y: 0.8, translate_y: -0.5));
  }

  static LevelPath star() {
    final left = <Vector2>[
      Vector2(-0.1, -0.6),
      Vector2(-0.3, -0.8),
      Vector2(-0.4, -0.5),
      Vector2(-0.7, -0.4),
      Vector2(-0.6, -0.1),
      Vector2(-0.7, 0.2),
      Vector2(-0.4, 0.3),
      Vector2(-0.3, 0.6),
      Vector2(-0.1, 0.5),
    ];

    final right = left.reversed.map((v) => Vector2(-v.x, v.y)).toList();
    final vertices = (left + right).distinctBy((v) => v.toString());
    return LevelPath(_transformed(vertices, scale_x: 1.0, scale_y: 1.0, translate_y: -0.3));
  }

  static LevelPath triangle() {
    final left = <Vector2>[
      Vector2(-0.0, -0.6),
      Vector2(-0.15, -0.3),
      Vector2(-0.3, -0.0),
      Vector2(-0.45, 0.3),
      Vector2(-0.6, 0.6),
      Vector2(-0.75, 0.9),
      Vector2(-0.45, 0.9),
      Vector2(-0.15, 0.9),
    ];

    final right = left.reversed.map((v) => Vector2(-v.x, v.y)).toList();
    final vertices = (left + right).distinctBy((v) => v.toString());
    return LevelPath(_transformed(vertices, scale_y: 0.9, translate_y: -0.55));
  }

  static LevelPath square() {
    final baseVertices = <Vector2>[
      Vector2(-0.2, -1.0),
      Vector2(-0.6, -1.0),
      Vector2(-1.0, -1.0),
      Vector2(-1.0, -0.6),
      Vector2(-1.0, -0.2),
      Vector2(-1.0, 0.2),
      Vector2(-1.0, 0.6),
      Vector2(-1.0, 1.0),
      Vector2(-0.6, 1.0),
      Vector2(-0.2, 1.0),
      Vector2(0.2, 1.0),
      Vector2(0.6, 1.0),
      Vector2(1.0, 1.0),
      Vector2(1.0, 0.6),
      Vector2(1.0, 0.2),
      Vector2(1.0, -0.2),
      Vector2(1.0, -0.6),
      Vector2(1.0, -1.0),
      Vector2(0.6, -1.0),
      Vector2(0.2, -1.0),
    ];

    final result = _transformed(baseVertices, scale_x: 0.7, scale_y: 0.6, translate_y: -0.35);
    result.rotateRight();
    return LevelPath(result);
  }

  static LevelPath pipe() {
    const int sides = 16;
    const double scale_x = 0.8;
    const double scale_y = 0.9;
    const double translate_y = -0.3;
    final double step = 2 * pi / sides;
    final vertices = List<Vector2>.generate(sides, (i) {
      final angle = -pi / 2 - i * step - step / 2;
      return Vector2(cos(angle) * scale_x, sin(angle) * scale_y + translate_y);
    });
    return LevelPath(_transformed(vertices, scale_y: 0.7, translate_y: -0.15));
  }

  static LevelPath cross() {
    final vertices = <Vector2>[
      Vector2(-0.2, -1.0),
      Vector2(-0.6, -1.0),
      Vector2(-0.6, -0.6),
      Vector2(-1.0, -0.6),
      Vector2(-1.0, -0.2),
      Vector2(-1.0, 0.2),
      Vector2(-1.0, 0.6),
      Vector2(-0.6, 0.6),
      Vector2(-0.6, 1.0),
      Vector2(-0.2, 1.0),
      Vector2(0.2, 1.0),
      Vector2(0.6, 1.0),
      Vector2(0.6, 0.6),
      Vector2(1.0, 0.6),
      Vector2(1.0, 0.2),
      Vector2(1.0, -0.2),
      Vector2(1.0, -0.6),
      Vector2(0.6, -0.6),
      Vector2(0.6, -1.0),
      Vector2(0.2, -1.0),
    ];
    return LevelPath(_transformed(vertices, scale_x: 0.7, scale_y: 0.7, translate_y: -0.4));
  }

  static LevelPath torx() {
    final left = <Vector2>[
      Vector2(-0.2, -0.8),
      Vector2(-0.3, -0.4),
      Vector2(-0.5, -0.3),
      Vector2(-0.6, -0.1),
      Vector2(-1.0, 0.0),
      Vector2(-1.0, 0.3),
      Vector2(-0.6, 0.5),
      Vector2(-0.5, 0.7),
      Vector2(-0.3, 0.8),
      Vector2(-0.2, 1.1),
    ];

    final right = left.map((v) => Vector2(-v.x, v.y)).toList()..reverse();
    return LevelPath(_transformed(left + right, scale_x: 0.8, scale_y: 0.6, translate_y: -0.4));
  }

  static LevelPath eight() {
    final upper = <Vector2>[
      Vector2(-0.15, -0.6),
      Vector2(-0.4, -0.6),
      Vector2(-0.7, -0.7),
      Vector2(-1.0, -0.7),
      Vector2(-1.2, -0.5),
      Vector2(-1.3, -0.18),
      Vector2(-1.3, 0.18),
      Vector2(-1.2, 0.5),
      Vector2(-1.0, 0.7),
      Vector2(-0.7, 0.7),
      Vector2(-0.4, 0.6),
      Vector2(-0.15, 0.6),
    ];

    final lower = upper.reversed.map((v) => Vector2(-v.x, v.y)).toList();
    final vertices = (upper + lower).distinctBy((v) => v.toString());
    return LevelPath(_transformed(vertices, scale_x: 0.8, scale_y: 1.0, translate_y: -0.4));
  }

  static LevelPath x() {
    final topLeft = <Vector2>[
      Vector2(-0.2, -0.6),
      Vector2(-0.4, -0.9),
      Vector2(-0.9, -0.9),
      Vector2(-0.9, -0.4),
      Vector2(-0.6, -0.2),
    ];

    final bottomLeft = topLeft.map((v) => Vector2(v.x, -v.y)).toList()..reverse();
    final bottomRight = bottomLeft.map((v) => Vector2(-v.x, v.y)).toList()..reverse();
    final topRight = bottomRight.map((v) => Vector2(v.x, -v.y)).toList()..reverse();
    final vertices = (topLeft + bottomLeft + bottomRight + topRight).distinctBy((v) => v.toString());
    return LevelPath(_transformed(vertices));
  }
}
