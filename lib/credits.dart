import 'package:flame/components.dart';
import 'package:stardash/background/stars.dart';
import 'package:stardash/core/common.dart';
import 'package:stardash/game/base/screens.dart';
import 'package:stardash/input/keys.dart';
import 'package:stardash/ui/basic_menu.dart';
import 'package:stardash/ui/fonts.dart';
import 'package:stardash/util/extensions.dart';
import 'package:stardash/util/game_script.dart';

final credits = [
  'Powered by Flutter',
  'Made with Flame Engine',
  '',
  'Music by suno.com',
  // 'Voice Samples by elevenlabs.io',
  '',
  'Voxel Models by maxparata.itch.io',
  'Voxel Shader by intensicode.itch.io',
  // 'Pixel Explosion Shader by Leukbaars',
  // '',
  // '2D Art by Various Artists on itch.io',
];

class Credits extends GameScriptComponent {
  final _keys = Keys();

  @override
  onLoad() {
    super.onLoad();
    add(_keys);
    add(shared_stars);

    textXY('Credits', game_center.x, 20, scale: 2, anchor: Anchor.topCenter);

    final start = 60;
    for (final (idx, it) in credits.indexed) {
      textXY(it, game_center.x, start + idx * 10, anchor: Anchor.center, scale: 1);
    }

    final menu = added(BasicMenu(
      keys: _keys,
      font: mini_font,
      onSelected: (_) => pop_screen(),
      spacing: 10,
    ));

    menu.position.setValues(game_center.x, 64);
    menu.anchor = Anchor.topCenter;

    add(menu.addEntry('back', 'Back', size: Vector2(80, 24))
      ..auto_position = false
      ..position.setValues(8, game_size.y - 8)
      ..anchor = Anchor.bottomLeft);

    menu.preselectEntry('back');
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (_keys.check_and_consume(GameKey.soft1)) pop_screen();
  }
}
