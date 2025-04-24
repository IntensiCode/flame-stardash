import 'package:flame/components.dart';
import 'package:stardash/game/base/has_context.dart';
import 'package:stardash/game/level/level_color.dart';
import 'package:stardash/game/level/level_data.dart';

extension HasContextExtensions on HasContext {
  Levels get levels => cache.putIfAbsent('levels', () => Levels());
}

class LevelConfig {
  LevelConfig(this.number, this.cycle, this.data, this.color);

  final int number;
  final int cycle;
  final LevelData data;
  final LevelColor color;
}

class Levels extends Component with HasContext {
  static final _path_types = LevelData.values;
  static final _colors = LevelColor.values;

  LevelConfig level_config(int level_number) {
    assert(level_number >= 1, 'Level number must be 1 or greater');
    final path_index = (level_number - 1) % _path_types.length;
    final color_index = ((level_number - 1) ~/ _path_types.length) % _colors.length;
    return LevelConfig(
      level_number,
      (level_number - 1) ~/ _path_types.length,
      _path_types[path_index],
      _colors[color_index],
    );
  }
}
