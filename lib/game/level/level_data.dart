import 'package:stardash/game/base/camera.dart';
import 'package:stardash/game/level/level_path.dart';

/// LevelData defines a level by its path, whether it is closed, and camera settings.
class LevelData {
  static final cross = LevelData('down_cross', path: LevelPath.cross(), closed: true);
  static final pipe = LevelData('down_pipe', path: LevelPath.pipe(), closed: true);
  static final square = LevelData('down_square', path: LevelPath.square(), closed: true);
  static final torx = LevelData('down_star', path: LevelPath.torx(), closed: true);
  static final eight = LevelData('eight', path: LevelPath.eight(), closed: true);
  static final flat = LevelData('flat', path: LevelPath.flat(), camera: Camera.distorted);
  static final half_eight = LevelData('half_eight', path: LevelPath.half_eight());
  static final half_pipe = LevelData('half_pipe', path: LevelPath.half_pipe());
  static final heart = LevelData('heart', path: LevelPath.heart(), closed: true);
  static final stairs = LevelData('stairs', path: LevelPath.stairs(), camera: Camera.tilted);
  static final star = LevelData('star', path: LevelPath.star(), closed: true);
  static final triangle = LevelData('triangle', path: LevelPath.triangle(), closed: true);
  static final v = LevelData('v', path: LevelPath.v());
  static final x = LevelData('x', path: LevelPath.x(), closed: true, camera: Camera.frontal);

  static final values = [
    /*01*/ pipe,
    /*02*/ square,
    /*03*/ cross,
    /*04*/ eight,
    /*05*/ torx,
    /*06*/ triangle,
    /*07*/ x,
    /*08*/ v,
    /*09*/ stairs,
    /*10*/ half_pipe,
    /*11*/ flat,
    /*12*/ heart,
    /*13*/ star,
    /*14*/ half_eight,
    /*15*/ // distorted_v,
    /*16*/ // closed_eight,
  ];

  late final String name;
  late final LevelPath path;
  late final bool closed;
  late final Camera camera;

  LevelData(
    this.name, {
    required this.path,
    this.closed = false,
    Camera? camera,
  }) {
    this.camera = camera ?? Camera.standard;
  }

  @override
  String toString() => 'LevelData{$name${closed ? ' [closed]' : ''} $camera}';
}
