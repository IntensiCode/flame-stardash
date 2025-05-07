import 'package:flame/components.dart';
import 'package:stardash/background/stars.dart';
import 'package:stardash/core/common.dart';
import 'package:stardash/game/base/hiscore.dart';
import 'package:stardash/game/base/screens.dart';
import 'package:stardash/input/game_keys.dart';
import 'package:stardash/input/shortcuts.dart';
import 'package:stardash/ui/soft_keys.dart';
import 'package:stardash/util/effects.dart';
import 'package:stardash/util/extensions.dart';
import 'package:stardash/util/game_script.dart';
import 'package:stardash/util/vector_text.dart';

class HiscoreScreen extends GameScriptComponent with HasAutoDisposeShortcuts, KeyboardHandler, HasGameKeys {
  final _entry_size = Vector2(game_width, line_height);
  final _position = Vector2(0, line_height * 6);

  @override
  onLoad() async {
    add(shared_stars);
    vectorTextXY('Hiscore', game_center.x, line_height * 3, scale: 2.5, anchor: Anchor.topCenter);

    _add('Score', 'Level', 'Name');
    for (final entry in hiscore.entries) {
      final it = _add(entry.score.toString(), entry.level.toString(), entry.name);
      if (entry == hiscore.latest_rank) {
        it.add(BlinkEffect(on: 0.75, off: 0.25));
        // add(Particles(await AreaExplosion.covering(it))..priority = -10);
      }
    }

    softkeys('Back', null, (_) => pop_screen());
  }

  _HiscoreEntry _add(String score, String level, String name) {
    final it = added(_HiscoreEntry(
      score,
      level,
      name,
      size: _entry_size,
      position: _position,
    ));
    _position.y += line_height;
    return it;
  }
}

class _HiscoreEntry extends PositionComponent with HasVisibility {
  _HiscoreEntry(
    String score,
    String level,
    String name, {
    required Vector2 size,
    super.position,
  }) : super(size: size) {
    add(VectorText(
      text: score,
      position: Vector2(size.x * 11 / 32, 0),
      anchor: Anchor.topCenter,
    ));

    add(VectorText(
      text: level,
      position: Vector2(size.x * 15 / 32, 0),
      anchor: Anchor.topCenter,
    ));

    add(VectorText(
      text: name,
      position: Vector2(size.x * 20 / 32, 0),
      anchor: Anchor.topCenter,
    ));
  }
}
