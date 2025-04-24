import 'dart:math';

import 'package:flame/components.dart';

class Camera {
  static final distorted = Camera(
    name: 'distorted',
    position: Vector3(0, 1.1, -0.9),
    scale: Vector3(1.0, 1.0, 2.0),
    translate: Vector3(0.0, 0.0, -0.5),
    offset: Vector2(0.0, -150.0),
    pitch: pi / 12.0,
    fov_y_rad: pi / 2.0,
  );

  static final standard = Camera(
    name: 'standard',
    position: Vector3(0, 0.1, -0.85),
    scale: Vector3(1.0, 1.0, 2.0),
    translate: Vector3(0.0, 0.0, -0.00),
    offset: Vector2(0.0, 0.0),
    pitch: -pi / 12.0,
    fov_y_rad: pi / 2.0,
  );

  static final tilted = Camera(
    name: 'tilted',
    position: Vector3(0, 0.2, -1.3),
    scale: Vector3(1.0, 1.0, 2.0),
    translate: Vector3(0.0, -0.5, -0.5),
    offset: Vector2(0.0, 0.0),
    pitch: pi / 12.0,
    fov_y_rad: pi / 2.0,
  );

  static final frontal = Camera(
    name: 'frontal',
    position: Vector3(0, 0.05, -1.1),
    scale: Vector3(1.0, 1.0, 2.0),
    translate: Vector3(0.0, 0.0, 0.0),
    offset: Vector2(0.0, 0.0),
    pitch: 0.0,
    fov_y_rad: pi / 2.0,
  );

  String name;
  final Vector3 position;
  final Vector3 scale;
  final Vector3 translate;
  final Vector2 offset;
  double pitch;
  double fov_y_rad;

  final focal_length = 300.0;

  Camera({
    required this.name,
    required this.position,
    required this.scale,
    required this.translate,
    required this.offset,
    required this.pitch,
    required this.fov_y_rad,
  });

  @override
  String toString() => 'Camera{$name}';
}
