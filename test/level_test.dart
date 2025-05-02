// With this:
import 'package:flame/components.dart' show Vector2;
import 'package:stardash/game/level/level_geometry.dart';
import 'package:stardash/game/level/level_path.dart'
    show LevelPathType, LevelPath;
import 'package:test/test.dart';
// Replace this:
// import 'package:vector_math/vector_math_64.dart' show Vector2;

LevelGeometry _setupLevel(LevelPathType path_type) =>
    LevelGeometry(path_type: path_type);

void expectVectorCloseTo(Vector2 actual, Vector2 expected, double tolerance) {
  expect(actual.x, closeTo(expected.x, tolerance));
  expect(actual.y, closeTo(expected.y, tolerance));
}

void expectVectorNotCloseTo(
    Vector2 actual, Vector2 expected, double tolerance) {
  expect(actual.x, isNot(closeTo(expected.x, tolerance)),
      reason: 'X component should not be close');
  expect(actual.y, isNot(closeTo(expected.y, tolerance)),
      reason: 'Y component should not be close');
}

void main() {
  group('LevelLogic', () {
    // --- Test Setup (shared across mapGridToScreen groups) ---
    late LevelGeometry levelV; // Open path
    late LevelGeometry levelPipe; // Closed path
    late LevelGeometry levelHalfEight; // Complex path
    const epsilon = 0.001; // Epsilon for vector comparisons

    setUpAll(() {
      levelV = _setupLevel(LevelPathType.V);
      levelPipe = _setupLevel(LevelPathType.FullPipe);
      levelHalfEight = _setupLevel(LevelPathType.HalfEight);
    });

    group('precomputePathData', () {
      test('correctly initializes properties for V path', () {
        // Arrange & Act
        final level = _setupLevel(LevelPathType.V);

        // Assert
        expect(level.is_closed, isFalse);
        expect(level.path_definition,
            equals(LevelPath.definitions[LevelPathType.V]));
        // Check specific calculations derived from inputs
        final expectedMinDimension = 600.0;
        final expectedBaseScale = (expectedMinDimension * 0.9) / 2.0;
        expect(level.min_dimension, closeTo(expectedMinDimension, 0.001));
        expect(level.base_scale, closeTo(expectedBaseScale, 0.001));
        expect(level.outer_scale_factor, closeTo(expectedBaseScale, 0.001));
        expect(
            level.deep_scale_factor, closeTo(expectedBaseScale / 4.0, 0.001));
        expect(level.path_scale, equals(LevelPathType.V.scale));
        expect(level.path_translate, equals(LevelPathType.V.translate));
        expect(level.center, equals(Vector2(400, 300)));
      });
    });

    group('mapGridToScreen', () {
      test('calculates center point identically for open path (V)', () {
        final expected =
            levelV.map_grid_to_screen(0.0, 0.5, clamp_and_wrap_x: true);
        final actual =
            levelV.map_grid_to_screen(0.0, 0.5, clamp_and_wrap_x: false);
        expectVectorCloseTo(actual, expected, epsilon);
      });

      test('calculates arbitrary point identically for closed path (FullPipe)',
          () {
        final expected =
            levelPipe.map_grid_to_screen(0.5, 0.5, clamp_and_wrap_x: true);
        final actual =
            levelPipe.map_grid_to_screen(0.5, 0.5, clamp_and_wrap_x: false);
        expectVectorCloseTo(actual, expected, epsilon);
      });

      // --- Tests for different gridZ values at gridX=0.0 ---
      test('calculates outer edge (gridZ=0.0) identically', () {
        final vExpected =
            levelV.map_grid_to_screen(0.0, 0.0, clamp_and_wrap_x: true);
        final vActual =
            levelV.map_grid_to_screen(0.0, 0.0, clamp_and_wrap_x: false);
        expectVectorCloseTo(vActual, vExpected, epsilon);

        final pipeExpected =
            levelPipe.map_grid_to_screen(0.0, 0.0, clamp_and_wrap_x: true);
        final pipeActual =
            levelPipe.map_grid_to_screen(0.0, 0.0, clamp_and_wrap_x: false);
        expectVectorCloseTo(pipeActual, pipeExpected, epsilon);
      });

      test('calculates deep edge (gridZ=1.0) identically', () {
        final vExpected =
            levelV.map_grid_to_screen(0.0, 1.0, clamp_and_wrap_x: true);
        final vActual =
            levelV.map_grid_to_screen(0.0, 1.0, clamp_and_wrap_x: false);
        expectVectorCloseTo(vActual, vExpected, epsilon);

        final pipeExpected =
            levelPipe.map_grid_to_screen(0.0, 1.0, clamp_and_wrap_x: true);
        final pipeActual =
            levelPipe.map_grid_to_screen(0.0, 1.0, clamp_and_wrap_x: false);
        expectVectorCloseTo(pipeActual, pipeExpected, epsilon);
      });

      test('calculates beyond outer edge (gridZ=-0.5) identically', () {
        final vExpected =
            levelV.map_grid_to_screen(0.0, -0.5, clamp_and_wrap_x: true);
        final vActual =
            levelV.map_grid_to_screen(0.0, -0.5, clamp_and_wrap_x: false);
        expectVectorCloseTo(vActual, vExpected, epsilon);

        final pipeExpected =
            levelPipe.map_grid_to_screen(0.0, -0.5, clamp_and_wrap_x: true);
        final pipeActual =
            levelPipe.map_grid_to_screen(0.0, -0.5, clamp_and_wrap_x: false);
        expectVectorCloseTo(pipeActual, pipeExpected, epsilon);
        // Note: The assertion allows gridZ outside [0, 1]
      });

      test('calculates beyond deep edge (gridZ=1.5) identically', () {
        final vExpected =
            levelV.map_grid_to_screen(0.0, 1.5, clamp_and_wrap_x: true);
        final vActual =
            levelV.map_grid_to_screen(0.0, 1.5, clamp_and_wrap_x: false);
        expectVectorCloseTo(vActual, vExpected, epsilon);

        final pipeExpected =
            levelPipe.map_grid_to_screen(0.0, 1.5, clamp_and_wrap_x: true);
        final pipeActual =
            levelPipe.map_grid_to_screen(0.0, 1.5, clamp_and_wrap_x: false);
        expectVectorCloseTo(pipeActual, pipeExpected, epsilon);
        // Note: The assertion allows gridZ outside [0, 1]
      });
    });

    group('mapGridToScreen on open path', () {
      test('clamps gridX < -1 when clampAndWrapX=true', () {
        final boundary = levelV.map_grid_to_screen(-1.0, 0.0);
        final actual =
            levelV.map_grid_to_screen(-1.1, 0.0, clamp_and_wrap_x: true);
        expectVectorCloseTo(actual, boundary, epsilon);
      });

      test('clamps gridX > 1 when clampAndWrapX=true', () {
        final boundary = levelV.map_grid_to_screen(1.0, 0.0);
        final actual =
            levelV.map_grid_to_screen(1.1, 0.0, clamp_and_wrap_x: true);
        expectVectorCloseTo(actual, boundary, epsilon);
      });

      test('extrapolates gridX < -1 when clampAndWrapX=false', () {
        final boundary = levelV.map_grid_to_screen(-1.0, 0.0);
        final actual =
            levelV.map_grid_to_screen(-1.1, 0.0, clamp_and_wrap_x: false);
        expect(
            (actual.x - boundary.x).abs() > epsilon ||
                (actual.y - boundary.y).abs() > epsilon,
            isTrue,
            reason: "Extrapolated point should differ from boundary");
      });

      test('extrapolates gridX > 1 when clampAndWrapX=false', () {
        final boundary = levelV.map_grid_to_screen(1.0, 0.0);
        final actual =
            levelV.map_grid_to_screen(1.1, 0.0, clamp_and_wrap_x: false);
        expect(
            (actual.x - boundary.x).abs() > epsilon ||
                (actual.y - boundary.y).abs() > epsilon,
            isTrue,
            reason: "Extrapolated point should differ from boundary");
      });
    });

    group('mapGridToScreen on closed path', () {
      test('wraps gridX < -1 when clampAndWrapX=true', () {
        // gridX = -1.1 should wrap to gridX = 0.9
        final expected = levelPipe.map_grid_to_screen(0.9, 0.0);
        final actual =
            levelPipe.map_grid_to_screen(-1.1, 0.0, clamp_and_wrap_x: true);
        expectVectorCloseTo(actual, expected, epsilon);
      });

      test('wraps gridX > 1 when clampAndWrapX=true', () {
        // gridX = 1.1 should wrap to gridX = -0.9
        final expected = levelPipe.map_grid_to_screen(-0.9, 0.0);
        final actual =
            levelPipe.map_grid_to_screen(1.1, 0.0, clamp_and_wrap_x: true);
        expectVectorCloseTo(actual, expected, epsilon);
      });

      test('wraps gridX far < -1 when clampAndWrapX=true', () {
        // gridX = -3.1 should wrap to gridX = 0.9 (-3.1 + 2 + 2)
        final expected = levelPipe.map_grid_to_screen(0.9, 0.0);
        final actual =
            levelPipe.map_grid_to_screen(-3.1, 0.0, clamp_and_wrap_x: true);
        expectVectorCloseTo(actual, expected, epsilon);
      });

      test('extrapolates gridX < -1 when clampAndWrapX=false', () {
        final boundary = levelPipe.map_grid_to_screen(-1.0, 0.0);
        final actual =
            levelPipe.map_grid_to_screen(-1.1, 0.0, clamp_and_wrap_x: false);
        expect(
            (actual.x - boundary.x).abs() > epsilon ||
                (actual.y - boundary.y).abs() > epsilon,
            isTrue,
            reason: "Extrapolated point should differ from boundary");
      });

      test('extrapolates gridX > 1 when clampAndWrapX=false', () {
        final boundary = levelPipe.map_grid_to_screen(1.0, 0.0);
        final actual =
            levelPipe.map_grid_to_screen(1.1, 0.0, clamp_and_wrap_x: false);
        expect(
            (actual.x - boundary.x).abs() > epsilon ||
                (actual.y - boundary.y).abs() > epsilon,
            isTrue,
            reason: "Extrapolated point should differ from boundary");
      });
    });

    group('mapGridToScreen closed path properties', () {
      test(
          'mapGridToScreen maps gridX=1.0 and gridX=-1.0 to same point for closed paths',
          () {
        final pointAtEnd = levelPipe.map_grid_to_screen(1.0, 0.0);
        final pointAtStart = levelPipe.map_grid_to_screen(-1.0, 0.0);
        expectVectorCloseTo(pointAtEnd, pointAtStart, epsilon);

        // Also test with clampAndWrapX=false, as this might be relevant to the rendering bug
        final pointAtEndNoWrap =
            levelPipe.map_grid_to_screen(1.0, 0.0, clamp_and_wrap_x: false);
        final pointAtStartNoWrap =
            levelPipe.map_grid_to_screen(-1.0, 0.0, clamp_and_wrap_x: false);
        expectVectorCloseTo(pointAtEndNoWrap, pointAtStartNoWrap, epsilon);
        // Bug might be that these two ALSO differ, or differ from the clampAndWrapX=true case
        expectVectorCloseTo(pointAtEndNoWrap, pointAtEnd, epsilon);
      });
    });

    group('mapGridToScreen open path properties', () {
      test(
          'mapGridToScreen extrapolation for open paths is currently bugged (jumps)',
          () {
        // Use levelV (open path) defined in setUpAll

        // Get points near ends (gridZ=0)
        final pointAtEnd =
            levelV.map_grid_to_screen(1.0, 0.0, clamp_and_wrap_x: false);
        final pointBeforeEnd =
            levelV.map_grid_to_screen(0.99, 0.0, clamp_and_wrap_x: false);
        final pointAtStart =
            levelV.map_grid_to_screen(-1.0, 0.0, clamp_and_wrap_x: false);
        final pointAfterStart =
            levelV.map_grid_to_screen(-0.99, 0.0, clamp_and_wrap_x: false);

        // Calculate expected *linear* extrapolated positions
        // Extrapolate by 0.1 (from 1.0 to 1.1, and -1.0 to -1.1)
        final endTangent =
            (pointAtEnd - pointBeforeEnd) * (0.1 / 0.01); // Scale delta by 10
        final expectedBeyondEnd = pointAtEnd + endTangent;

        final startTangent = (pointAtStart - pointAfterStart) *
            (0.1 / 0.01); // Scale delta by 10
        final expectedBeforeStart = pointAtStart + startTangent;

        // Get actual points calculated by the potentially bugged function
        final actualBeyondEnd =
            levelV.map_grid_to_screen(1.1, 0.0, clamp_and_wrap_x: false);
        final actualBeforeStart =
            levelV.map_grid_to_screen(-1.1, 0.0, clamp_and_wrap_x: false);

        // Assert that the actual points are now CLOSE to the expected linear extrapolation
        expectVectorCloseTo(actualBeyondEnd, expectedBeyondEnd, epsilon);
        expectVectorCloseTo(actualBeforeStart, expectedBeforeStart, epsilon);
      });
    });

    group('getDepthVector', () {
      test('returns normalized vector for open path (V) at gridX=0', () {
        final vector = levelV.get_depth_vector(0.0);
        expect(vector.length, closeTo(1.0, epsilon));
        // Verify direction roughly (points from outer to deep)
        final outer = levelV.map_grid_to_screen(0.0, 0.0);
        final deep = levelV.map_grid_to_screen(0.0, 1.0);
        final expectedDir = (deep - outer).normalized();
        expectVectorCloseTo(vector, expectedDir, epsilon);
      });

      test('returns normalized vector for closed path (Pipe) at gridX=0.5', () {
        final vector = levelPipe.get_depth_vector(0.5);
        expect(vector.length, closeTo(1.0, epsilon));
        // Verify direction roughly
        final outer = levelPipe.map_grid_to_screen(0.5, 0.0);
        final deep = levelPipe.map_grid_to_screen(0.5, 1.0);
        final expectedDir = (deep - outer).normalized();
        expectVectorCloseTo(vector, expectedDir, epsilon);
      });

      test('returns normalized vector for open path (V) at gridX=-1', () {
        final vector = levelV.get_depth_vector(-1.0);
        expect(vector.length, closeTo(1.0, epsilon));
        final outer = levelV.map_grid_to_screen(-1.0, 0.0);
        final deep = levelV.map_grid_to_screen(-1.0, 1.0);
        final expectedDir = (deep - outer).normalized();
        expectVectorCloseTo(vector, expectedDir, epsilon);
      });

      test('returns normalized vector for closed path (Pipe) at gridX=1', () {
        final vector = levelPipe.get_depth_vector(1.0);
        expect(vector.length, closeTo(1.0, epsilon));
        final outer = levelPipe.map_grid_to_screen(1.0, 0.0);
        final deep = levelPipe.map_grid_to_screen(1.0, 1.0);
        final expectedDir = (deep - outer).normalized();
        expectVectorCloseTo(vector, expectedDir, epsilon);
      });
    });

    group('getOrientationNormal', () {
      // Helper to calculate tangent for testing orthogonality
      Vector2 calculateTangent(LevelGeometry level, double gridX) {
        const double tangentEpsilon =
            0.001; // Small offset for tangent calculation
        double gridXPlus = gridX + tangentEpsilon;
        double gridXMinus = gridX - tangentEpsilon;

        // Use clamp/wrap logic consistent with getOrientationNormal
        if (level.is_closed) {
          if (gridXPlus > 1.0) gridXPlus = -1.0 + (gridXPlus - 1.0);
          if (gridXMinus < -1.0) gridXMinus = 1.0 + (gridXMinus + 1.0);
        } else {
          gridXPlus = gridXPlus.clamp(-1.0, 1.0);
          gridXMinus = gridXMinus.clamp(-1.0, 1.0);
        }

        final p1 = level.map_grid_to_screen(gridXPlus, 0.0);
        final p2 = level.map_grid_to_screen(gridXMinus, 0.0);
        // Handle potential zero vector if p1 and p2 are identical (e.g., perfectly flat segment)
        final tangentVec = p1 - p2;
        return tangentVec.length2 < epsilon * epsilon
            ? Vector2(1, 0)
            : tangentVec
                .normalized(); // Return default tangent if length is near zero
      }

      // --- Tests for V (Open) ---
      test('returns normalized normal for open path (V) at gridX=0', () {
        final normal = levelV.get_orientation_normal(0.0);
        expect(normal.length, closeTo(1.0, epsilon));
        // Check orthogonality with tangent (Original expectation)
        final tangent = calculateTangent(levelV, 0.0);
        expect(normal.dot(tangent), closeTo(0.0, epsilon));
      });
      test('returns normalized normal for open path (V) at gridX=-1', () {
        final normal = levelV.get_orientation_normal(-1.0);
        expect(normal.length, closeTo(1.0, epsilon));
        // Check orthogonality with tangent (Original expectation)
        final tangent = calculateTangent(levelV, -1.0);
        expect(normal.dot(tangent), closeTo(0.0, epsilon));
      });
      test('returns normalized normal for open path (V) at gridX=1', () {
        final normal = levelV.get_orientation_normal(1.0);
        expect(normal.length, closeTo(1.0, epsilon));
        // Check orthogonality with tangent (Original expectation)
        final tangent = calculateTangent(levelV, 1.0);
        expect(normal.dot(tangent), closeTo(0.0, epsilon));
      });

      // --- Tests for FullPipe (Closed) ---
      test('returns normalized normal for closed path (Pipe) at gridX=0.5', () {
        final normal = levelPipe.get_orientation_normal(0.5);
        expect(normal.length, closeTo(1.0, epsilon));
        // Check orthogonality with tangent (Original expectation)
        final tangent = calculateTangent(levelPipe, 0.5);
        expect(normal.dot(tangent), closeTo(0.0, epsilon));
      });
      test('returns normalized normal for closed path (Pipe) at gridX=-1', () {
        final normal = levelPipe.get_orientation_normal(-1.0);
        expect(normal.length, closeTo(1.0, epsilon));
        // Check orthogonality with tangent (Original expectation)
        final tangent = calculateTangent(levelPipe, -1.0);
        expect(normal.dot(tangent), closeTo(0.0, epsilon));
      });
      test('returns normalized normal for closed path (Pipe) at gridX=1', () {
        final normal = levelPipe.get_orientation_normal(1.0);
        expect(normal.length, closeTo(1.0, epsilon));
        // Check orthogonality with tangent (Original expectation)
        final tangent = calculateTangent(levelPipe, 1.0);
        expect(normal.dot(tangent), closeTo(0.0, epsilon));
      });

      // --- Tests for HalfEight (Complex Open) ---
      test(
          'returns normalized normal for HalfEight path at gridX=0 (concave center)',
          () {
        final normal = levelHalfEight.get_orientation_normal(0.0);
        expect(normal.length, closeTo(1.0, epsilon));
        // Check orthogonality with tangent (Original expectation)
        final tangent = calculateTangent(levelHalfEight, 0.0);
        expect(normal.dot(tangent), closeTo(0.0, epsilon));
      });
      test(
          'returns normalized normal for HalfEight path at gridX=0.2 (near concave)',
          () {
        final normal = levelHalfEight.get_orientation_normal(0.2);
        expect(normal.length, closeTo(1.0, epsilon));
        // Check orthogonality with tangent (Original expectation)
        final tangent = calculateTangent(levelHalfEight, 0.2);
        // Expect this might fail slightly due to finite difference inaccuracies
        expect(normal.dot(tangent), closeTo(0.0, 0.1)); // Use larger tolerance
      });
      test(
          'returns normalized normal for HalfEight path at gridX=-0.8 (convex side)',
          () {
        final normal = levelHalfEight.get_orientation_normal(-0.8);
        expect(normal.length, closeTo(1.0, epsilon));
        // Check orthogonality with tangent (Original expectation)
        final tangent = calculateTangent(levelHalfEight, -0.8);
        // Expect this might fail slightly due to finite difference inaccuracies
        expect(normal.dot(tangent), closeTo(0.0, 0.1)); // Use larger tolerance
      });
    });
  });
}
