import 'dart:math';

import 'package:flame/components.dart';
import 'package:stardash/aural/audio_system.dart';
import 'package:stardash/background/stars.dart';
import 'package:stardash/core/common.dart';
import 'package:stardash/game/base/screens.dart';
import 'package:stardash/game/base/video_mode.dart';
import 'package:stardash/input/keys.dart';
import 'package:stardash/input/shortcuts.dart';
import 'package:stardash/title/title_entities.dart';
import 'package:stardash/title/title_text.dart';
import 'package:stardash/ui/basic_menu.dart';
import 'package:stardash/ui/fonts.dart';
import 'package:stardash/util/bitmap_text.dart';
import 'package:stardash/util/extensions.dart';
import 'package:stardash/util/game_script.dart';

enum _TitleButtons {
  audio,
  controls,
  credits,
  hiscore,
  play,
  video,
}

final _credits = [
  'Music by suno.com',
  'Voxel Shader by IntensiCode',
  'Voxel Models by maxparata.itch.io',
];

class TitleScreen extends GameScriptComponent with HasAutoDisposeShortcuts {
  static _TitleButtons? _preselected = _TitleButtons.play;

  final _keys = Keys();

  BitmapText? _video;
  BitmapText? _audio;

  @override
  onLoad() {
    title_models.clear();

    add(_keys);
    add(shared_stars);
    add(TitleText());

    for (final (idx, it) in _credits.reversed.indexed) {
      textXY(it, 784, 466 - idx * 10, anchor: Anchor.bottomRight, scale: 1);
    }

    textXY('< Video Mode >', 280, 388, anchor: Anchor.bottomCenter, scale: 1);
    _video = textXY(video.name, 280, 480 - 76 - 5, anchor: Anchor.bottomCenter, scale: 1);

    textXY('< Audio Mode >', 280, 420, anchor: Anchor.bottomCenter, scale: 1);
    _audio = textXY(audio.guess_audio_mode.label, 280, 399 + 33, anchor: Anchor.bottomCenter, scale: 1);

    final menu = added(BasicMenu<_TitleButtons>(
      keys: _keys,
      font: mini_font,
      onSelected: _selected,
      spacing: 8,
      fixed_position: Vector2(16, game_height - 8),
      fixed_anchor: Anchor.bottomLeft,
    ));

    menu.addEntry(_TitleButtons.hiscore, 'Hiscore');
    menu.addEntry(_TitleButtons.credits, 'Credits / How To Play');
    menu.addEntry(_TitleButtons.controls, 'Controls');
    menu.addEntry(_TitleButtons.video, 'Video');
    menu.addEntry(_TitleButtons.audio, 'Audio');
    menu.addEntry(_TitleButtons.play, 'Play');
    menu.preselectEntry(_preselected ?? _TitleButtons.play);

    menu.onPreselected = (id) => _preselected = id;

    audio.play(Sound.plasma);

    for (final it in TitleEntities()) {
      it.then((it) {
        it.position.y -= 48;
        add(it);
      });
    }
  }

  void _selected(_TitleButtons id) {
    _preselected = id;
    switch (id) {
      case _TitleButtons.hiscore:
        push_screen(Screen.hiscore);
        break;
      case _TitleButtons.credits:
        show_screen(Screen.credits);
        break;
      case _TitleButtons.controls:
        push_screen(Screen.controls);
        break;
      case _TitleButtons.video:
        push_screen(Screen.video);
        break;
      case _TitleButtons.audio:
        push_screen(Screen.audio);
        break;
      case _TitleButtons.play:
        show_screen(Screen.game_play);
        break;
    }
  }

  double _anim = 0;
  final _rotation = Matrix3.zero();

  @override
  void update(double dt) {
    super.update(dt);

    if (_keys.check_and_consume(GameKey.start)) {
      push_screen(Screen.game_play);
    }
    if (_keys.check_and_consume(GameKey.left)) {
      if (_preselected == _TitleButtons.video) _change_video_mode(-1);
      if (_preselected == _TitleButtons.audio) _change_audio_mode(-1);
    }
    if (_keys.check_and_consume(GameKey.right)) {
      if (_preselected == _TitleButtons.video) _change_video_mode(1);
      if (_preselected == _TitleButtons.audio) _change_audio_mode(1);
    }

    _anim += dt * pi / 2;
    _rotation.setRotationY(_anim);

    for (final it in title_models) {
      it.orientation_matrix.setRotationX(-pi / 12);
      it.orientation_matrix.multiply(_rotation);
    }
  }

  void _change_video_mode(int add) {
    final values = VideoMode.values;
    final index = (values.indexOf(video) + add) % values.length;
    video = values[index];
    _video?.text = video.name;
    _video?.fadeInDeep();
  }

  void _change_audio_mode(int add) {
    final values = AudioMode.values;
    final index = (values.indexOf(audio.guess_audio_mode) + add) % values.length;
    audio.audio_mode = values[index];
    _audio?.text = audio.guess_audio_mode.label;
    _audio?.fadeInDeep();
  }
}
