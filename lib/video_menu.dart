import 'package:flame/components.dart';
import 'package:stardash/background/stars.dart';
import 'package:stardash/core/atlas.dart';
import 'package:stardash/core/common.dart';
import 'package:stardash/game/base/screens.dart';
import 'package:stardash/game/base/video_mode.dart';
import 'package:stardash/input/keys.dart';
import 'package:stardash/ui/basic_menu.dart';
import 'package:stardash/ui/basic_menu_button.dart';
import 'package:stardash/ui/flow_text.dart';
import 'package:stardash/ui/fonts.dart';
import 'package:stardash/util/extensions.dart';
import 'package:stardash/util/game_script.dart';

enum _VideoEntry {
  performance('Performance'),
  balanced('Balanced'),
  quality('Quality'),
  skip_frames('Skip Frames'),
  exhaust_anim('Exhaust Animation'),
  back('Back'),
  ;

  final String label;

  const _VideoEntry(this.label);
}

final _hint = {
  _VideoEntry.performance: '''
      Fastest rendering, but less smooth:
      \n\n
      - Skips most animation frames
      - Disables exhaust animation
      ''',
  _VideoEntry.balanced: '''
      Balanced rendering speed and smoothness:
      \n\n
      - Skips some animation frames
      - Disables exhaust animation
      ''',
  _VideoEntry.quality: '''
      Full rendering quality:
      \n\n
      - Does not skip animation frames
      - Enables exhaust animation
      ''',
  _VideoEntry.skip_frames: '''
      Skip animation frames:
      \n\n
      - Improves rendering performance
      - Animations will be less smooth
      - Overrides performance mode
      ''',
  _VideoEntry.exhaust_anim: '''
      Enable exhaust animation:
      \n\n
      - Voxel models will not be animated if disabled
      - Rendering performance reduced if enabled
      ''',
};

class VideoMenu extends GameScriptComponent {
  final _keys = Keys();

  late final BasicMenu<_VideoEntry> _menu;

  BasicMenuButton? _skip_button;
  BasicMenuButton? _anim_button;

  FlowText? _hint_text;

  static _VideoEntry? _preselected;

  @override
  onLoad() {
    add(_keys);
    add(shared_stars);

    fontSelect(tiny_font, scale: 2);
    textXY('Video Mode', game_center.x, 20, scale: 2, anchor: Anchor.topCenter);

    _preselected ??= switch (video) {
      VideoMode.performance => _VideoEntry.performance,
      VideoMode.balanced => _VideoEntry.balanced,
      VideoMode.quality => _VideoEntry.quality,
    };

    _menu = added(BasicMenu<_VideoEntry>(
      keys: _keys,
      font: mini_font,
      onSelected: _selected,
      spacing: 10,
    )
      ..addEntry(_VideoEntry.performance, 'Performance')
      ..addEntry(_VideoEntry.balanced, 'Balanced')
      ..addEntry(_VideoEntry.quality, 'Quality'));

    _skip_button = _menu.addEntry(_VideoEntry.skip_frames, 'Skip Frames', text_anchor: Anchor.centerLeft);
    _skip_button?.checked = skip_frames;
    _anim_button = _menu.addEntry(_VideoEntry.exhaust_anim, 'Exhaust Animation', text_anchor: Anchor.centerLeft);
    _anim_button?.checked = exhaust_anim;

    _menu.position.setValues(game_center.x, 64);
    _menu.anchor = Anchor.topCenter;
    _menu.onPreselected = _preselect;

    add(_menu.addEntry(_VideoEntry.back, 'Back', size: Vector2(80, 24))
      ..auto_position = false
      ..position.setValues(8, game_size.y - 8)
      ..anchor = Anchor.bottomLeft);

    _menu.preselectEntry(_preselected ?? _VideoEntry.balanced);
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (_keys.check_and_consume(GameKey.soft1)) pop_screen();
  }

  void _selected(_VideoEntry it) {
    final sf = skip_frames;
    final ba = exhaust_anim;
    switch (it) {
      case _VideoEntry.performance:
        video = VideoMode.performance;
        skip_frames = true;
        exhaust_anim = false;
      case _VideoEntry.balanced:
        video = VideoMode.balanced;
        skip_frames = true;
        exhaust_anim = true;
      case _VideoEntry.quality:
        video = VideoMode.quality;
        skip_frames = false;
        exhaust_anim = true;
      case _VideoEntry.skip_frames:
        skip_frames = !skip_frames;
      case _VideoEntry.exhaust_anim:
        exhaust_anim = !exhaust_anim;
      case _VideoEntry.back:
        pop_screen();
    }
    if (sf != skip_frames) {
      _skip_button?.checked = skip_frames;
      _skip_button?.fadeInDeep();
    }
    if (ba != exhaust_anim) {
      _anim_button?.checked = exhaust_anim;
      _anim_button?.fadeInDeep();
    }
  }

  void _preselect(_VideoEntry? it) {
    _preselected = it;
    _hint_text?.removeFromParent();
    _hint_text = null;

    if (it == null || _hint[it] == null) return;

    _hint_text = added(FlowText(
      background: atlas.sprite('button_plain.png'),
      text: _hint[it]!,
      font: mini_font,
      anchor: Anchor.topLeft,
      size: Vector2(240, 128),
      position: Vector2(32, 63),
    ));
  }
}
