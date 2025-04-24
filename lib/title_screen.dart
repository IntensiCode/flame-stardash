import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:stardash/aural/audio_system.dart';
import 'package:stardash/background/stars.dart';
import 'package:stardash/core/common.dart';
import 'package:stardash/game/base/screens.dart';
import 'package:stardash/util/vector_font.dart';
import 'package:stardash/input/keys.dart';
import 'package:stardash/input/shortcuts.dart';
import 'package:stardash/ui/basic_menu.dart';
import 'package:stardash/ui/fonts.dart';
import 'package:stardash/util/bitmap_text.dart';
import 'package:stardash/util/extensions.dart';
import 'package:stardash/util/game_script.dart';
import 'package:stardash/util/mutable.dart';

enum _TitleButtons {
  credits,
  audio,
  controls,
  play,
}

final _credits = [
  'Music by suno.com',
  'Voxel Models by maxparata.itch.io',
  'Voxel Shader by IntensiCode',
];

class TitleScreen extends GameScriptComponent with HasAutoDisposeShortcuts {
  static _TitleButtons? _preselected = _TitleButtons.play;

  final _keys = Keys();

  BitmapText? _audio;

  @override
  void onLoad() {
    add(_keys);
    add(sharedStars);
    add(_TitleText());

    for (final (idx, it) in _credits.reversed.indexed) {
      textXY(it, 784, 466 - idx * 10, anchor: Anchor.bottomRight, scale: 1);
    }

    textXY('< Audio Mode >', 280, 356, anchor: Anchor.bottomCenter, scale: 1);
    _audio = textXY(audio.guess_audio_mode.label, 280, 368, anchor: Anchor.bottomCenter, scale: 1);

    final menu = added(BasicMenu<_TitleButtons>(
      keys: _keys,
      font: mini_font,
      onSelected: _selected,
      spacing: 8,
      fixed_position: Vector2(16, game_height - 8),
      fixed_anchor: Anchor.bottomLeft,
    ));

    menu.addEntry(_TitleButtons.credits, 'Credits');
    menu.addEntry(_TitleButtons.audio, 'Audio');
    menu.addEntry(_TitleButtons.controls, 'Controls');
    menu.addEntry(_TitleButtons.play, 'Play');
    menu.preselectEntry(_preselected ?? _TitleButtons.play);

    menu.onPreselected = (id) => _preselected = id;
  }

  void _selected(_TitleButtons id) {
    _preselected = id;
    switch (id) {
      case _TitleButtons.credits:
        showScreen(Screen.credits);
        break;
      case _TitleButtons.audio:
        pushScreen(Screen.audio);
        break;
      case _TitleButtons.controls:
        pushScreen(Screen.controls);
        break;
      case _TitleButtons.play:
        showScreen(Screen.game_play);
        break;
    }
  }

  @override
  void update(double dt) {
    super.update(dt);

    if (_keys.check_and_consume(GameKey.start)) {
      pushScreen(Screen.game_play);
    }
    if (_keys.check_and_consume(GameKey.left)) {
      if (_preselected == _TitleButtons.audio) _change_audio_mode(-1);
    }
    if (_keys.check_and_consume(GameKey.right)) {
      if (_preselected == _TitleButtons.audio) _change_audio_mode(1);
    }
  }

  void _change_audio_mode(int add) {
    final values = AudioMode.values;
    final index = (values.indexOf(audio.guess_audio_mode) + add) % values.length;
    audio.audio_mode = values[index];
    _audio?.text = audio.guess_audio_mode.label;
    _audio?.fadeInDeep();
  }
}

class _TitleHistoryEntry {
  final double scale;
  final double startY;

  _TitleHistoryEntry(this.scale, this.startY);
}

class _TitleText extends Component with HasPaint {
  static final _offset = MutableOffset(0, 0);
  static const _text = 'STARDASH';
  static const double _titleAnimDuration = 1.0;
  static const double _strokeWidth = 2.5;
  static const int _historyLength = 30;
  static const _blur = MaskFilter.blur(BlurStyle.normal, 1.0);
  static late Color _saved;

  final _font = VectorFont();
  final _history = <_TitleHistoryEntry>[];
  double _titleAnimTime = 0.0;

  _TitleText() {
    paint.color = Colors.yellow;
    paint.style = PaintingStyle.stroke;
    paint.strokeWidth = _strokeWidth;
  }

  @override
  void update(double dt) {
    super.update(dt);

    _titleAnimTime += dt;
    if (_titleAnimTime >= _titleAnimDuration) _titleAnimTime = _titleAnimDuration;

    final double t = (_titleAnimTime / _titleAnimDuration).clamp(0.0, 1.0);
    final scaleCurve = Curves.easeInCubic.transform(t);
    final double currentScale = lerpDouble(0.5, 8.0, scaleCurve)!;

    final translateCurve = Curves.decelerate.transform(t);
    final double translate = lerpDouble(0.0, 100.0, translateCurve)!;
    final double currentStartY = 200 - translate;

    if (currentScale > 0.01) {
      if (currentScale < 8.0) {
        _history.add(_TitleHistoryEntry(currentScale, currentStartY));
        if (_history.length > _historyLength) {
          _history.removeAt(0);
        }
      } else if (_history.isNotEmpty) {
        _history.removeAt(0);
      }
    }
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    _saved = paint.color;
    _renderHistory(canvas);
    _renderTitle(canvas);
    paint.color = _saved;
  }

  void _renderTitle(Canvas canvas) {
    final double tCurrent = (_titleAnimTime / _titleAnimDuration).clamp(0.0, 1.0);
    final scaleCurveCurrent = Curves.easeInCubic.transform(tCurrent);
    final double currentScale = lerpDouble(0.5, 8.0, scaleCurveCurrent)!;
    final translateCurveCurrent = Curves.decelerate.transform(tCurrent);
    final double translateCurrent = lerpDouble(0.0, 100.0, translateCurveCurrent)!;
    final double currentStartY = 200 - translateCurrent;

    paint.maskFilter = null;
    _setColor(alpha: 1.0);
    _drawVectorText(canvas, currentScale, currentStartY);
    paint.maskFilter = _blur;
  }

  void _setColor({double alpha = 1.0}) {
    if (_saved.a < 1.0 || alpha < 1.0) {
      paint.color = Colors.yellow.withValues(alpha: _saved.a * alpha);
    } else {
      paint.color = Colors.yellow;
    }
  }

  void _renderHistory(Canvas canvas) {
    paint.maskFilter = _blur;

    final int historyCount = _history.length;
    for (int i = 0; i < historyCount; i += 1) {
      final entry = _history[i];
      final double alphaFraction = (i + 1) / (_historyLength + 1);
      final double ghostAlpha = alphaFraction * 0.5;
      _setColor(alpha: ghostAlpha);
      _drawVectorText(canvas, entry.scale, entry.startY);
    }

    paint.maskFilter = null;
  }

  void _drawVectorText(Canvas canvas, double scale, double startY) {
    if (scale < 0.01) return;
    _offset.dx = game_width / 2;
    _offset.dy = startY;
    _font.render_anchored(canvas, paint, _text, _offset, scale, Anchor.topCenter);
  }
}
