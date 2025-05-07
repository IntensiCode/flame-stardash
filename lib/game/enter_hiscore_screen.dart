import 'package:stardash/core/common.dart';
import 'package:stardash/game/base/has_context.dart';
import 'package:stardash/game/base/hiscore.dart';
import 'package:stardash/game/base/screens.dart';
import 'package:stardash/game/level/level.dart';
import 'package:stardash/game/player/player.dart';
import 'package:stardash/input/shortcuts.dart';
import 'package:stardash/ui/soft_keys.dart';
import 'package:stardash/util/game_script.dart';
import 'package:stardash/util/grab_input.dart';

class EnterHiscoreScreen extends GameScriptComponent with HasAutoDisposeShortcuts, HasContext, GrabInput {
  @override
  onLoad() {
    vectorTextXY('You made it into the', game_center.x, line_height * 2);
    vectorTextXY('HISCORE', game_center.x, line_height * 3, scale: 1.5);

    vectorTextXY('Score', game_center.x, line_height * 5);
    vectorTextXY('$pending_score', game_center.x, line_height * 6);

    vectorTextXY('Level', game_center.x, line_height * 8);
    vectorTextXY('$pending_level', game_center.x, line_height * 9);

    vectorTextXY('Enter your name:', game_center.x, line_height * 12);

    var input = vectorTextXY('_', game_center.x, line_height * 13);

    softkeys('Cancel', 'Ok', (it) {
      if (it == SoftKey.left) {
        pop_screen(); // TODO confirm
      } else if (it == SoftKey.right && name.isNotEmpty) {
        hiscore.insert(player.score, level.number, name);
        show_screen(Screen.hiscore);
      }
    });

    snoop_key_input((it) {
      if (it.length == 1) {
        name += it;
      } else if (it == '<Space>' && name.isNotEmpty) {
        name += ' ';
      } else if (it == '<Backspace>' && name.isNotEmpty) {
        name = name.substring(0, name.length - 1);
      } else if (it == '<Enter>' && name.isNotEmpty) {
        hiscore.insert(pending_score!, pending_level!, name);
        show_screen(Screen.hiscore);
      }
      if (name.length > 10) name = name.substring(0, 10);

      input.removeFromParent();

      input = vectorTextXY('${name}_', game_center.x, line_height * 13);
    });
  }

  String name = '';
}
