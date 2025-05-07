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

final how_to_play = [
  'Tempest is a survival and score-based game played on a segmented tube',
  'or field viewed from one end. You control a claw-shaped ship that moves',
  'along the edge, firing at enemies advancing from the far end.',
  '',
  'The Super-Zapper destroys all enemies once per level. Survive by clearing',
  'enemies and avoiding spikes while warping to the next level. Losing all',
  'ships ends the game. There are many unique level shapes, which repeat with',
  'harder enemies and new colors.',
  '',
  'Earn extra ships by reaching score thresholds (every 10,000 points).',
  '',
  'Flippers move fast and switch lanes. Damage your ship by flipping on it.',
  'Tankers move slow. Release other enemies when destroyed or at outer edge.',
  'Spikers draw dangerous spikes along the level tiles. Avoid them when leaving.',
  'Fuseballs cause high damage when close to your ship.',
  'Pulsars electrify lanes randomly.',
];

class Credits extends GameScriptComponent {
  final _keys = Keys();

  @override
  onLoad() {
    super.onLoad();
    add(_keys);
    add(shared_stars);

    textXY('Credits', game_center.x, 20, scale: 2, anchor: Anchor.topCenter);

    var start = 60;
    for (final (idx, it) in credits.indexed) {
      textXY(it, game_center.x, start + idx * 12, anchor: Anchor.center, scale: 1);
    }

    textXY('How To Play', game_center.x, 160, scale: 2, anchor: Anchor.topCenter);

    start = 200;
    for (final (idx, it) in how_to_play.indexed) {
      textXY(it, game_center.x, start + idx * 12, anchor: Anchor.center);
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
