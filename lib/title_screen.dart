import 'dart:math';
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:stardash/aural/audio_system.dart';
import 'package:stardash/background/stars.dart';
import 'package:stardash/core/common.dart';
import 'package:stardash/game/base/screens.dart';
import 'package:stardash/game/base/voxel_entity.dart';
import 'package:stardash/game/enemies/shader_pulsar.dart';
import 'package:stardash/game/enemies/voxel_flipper.dart';
import 'package:stardash/game/enemies/voxel_spiker.dart';
import 'package:stardash/game/enemies/voxel_tanker.dart';
import 'package:stardash/game/player/player.dart';
import 'package:stardash/input/keys.dart';
import 'package:stardash/input/shortcuts.dart';
import 'package:stardash/ui/basic_menu.dart';
import 'package:stardash/ui/fonts.dart';
import 'package:stardash/util/bitmap_text.dart';
import 'package:stardash/util/extensions.dart';
import 'package:stardash/util/game_script.dart';
import 'package:stardash/util/mutable.dart';
import 'package:stardash/util/uniforms.dart';
import 'package:stardash/util/vector_font.dart';
import 'package:stardash/util/vector_text.dart';

enum _TitleButtons {
  credits,
  audio,
  controls,
  play,
}

final _credits = [
  'Music by suno.com',
  'Voxel Shader by IntensiCode',
  'Voxel Models by maxparata.itch.io',
];

class TitleScreen extends GameScriptComponent with HasAutoDisposeShortcuts {
  static _TitleButtons? _preselected = _TitleButtons.play;

  final _keys = Keys();

  BitmapText? _audio;

  @override
  onLoad() {
    add(_keys);
    add(shared_stars);
    add(_TitleText());

    for (final (idx, it) in _credits.reversed.indexed) {
      textXY(it, 784, 466 - idx * 10, anchor: Anchor.bottomRight, scale: 1);
    }

    textXY('< Audio Mode >', 280, 387 + 30, anchor: Anchor.bottomCenter, scale: 1);
    _audio = textXY(audio.guess_audio_mode.label, 280, 399 + 30, anchor: Anchor.bottomCenter, scale: 1);

    final menu = added(BasicMenu<_TitleButtons>(
      keys: _keys,
      font: mini_font,
      onSelected: _selected,
      spacing: 8,
      fixed_position: Vector2(16, game_height - 8),
      fixed_anchor: Anchor.bottomLeft,
    ));

    // menu.addEntry(_TitleButtons.credits, 'Credits');
    menu.addEntry(_TitleButtons.audio, 'Audio');
    // menu.addEntry(_TitleButtons.controls, 'Controls');
    menu.addEntry(_TitleButtons.play, 'Play');
    menu.preselectEntry(_preselected ?? _TitleButtons.play);

    menu.onPreselected = (id) => _preselected = id;

    audio.play(Sound.plasma);

    _voxel(
      image: 'voxel/flipper16.png',
      frames: 16,
      x: 100,
      scale: Vector3(0.7, 0.25, 0.7),
      name: 'Flipper',
      type: VoxelFlipper,
    ).then(add);
    _voxel(
      image: 'voxel/tanker20.png',
      frames: 20,
      x: 200,
      scale: Vector3(0.6, 0.4, 0.8),
      name: 'Tanker',
      type: VoxelTanker,
    ).then(add);
    _voxel(
      image: 'voxel/spiker50.png',
      frames: 50,
      x: 300,
      scale: Vector3(0.8, 0.8, 0.8),
      name: 'Spiker',
      type: VoxelSpiker,
    ).then(add);
    _column(
      enemy: _TitlePulsar(),
      x: 400,
      name: 'Pulsar',
      type: ShaderPulsar,
    ).then(add);
    _voxel(
      image: 'voxel/manta19.png',
      frames: 19,
      x: 700,
      scale: Vector3(0.8, 0.3, 0.8),
      name: 'Manta Zapper',
      type: Player,
    ).then(add);
  }

  final _models = <VoxelEntity>[];

  Future<Component> _column({
    required PositionComponent enemy,
    required double x,
    required String name,
    required Type type,
  }) async {
    final column = PositionComponent(
      position: Vector2(x, game_height / 2),
      size: Vector2(64, 110),
      anchor: Anchor.center,
    );

    enemy.size.setAll(64);
    column.add(enemy);

    column.add(VectorText(
      text: name,
      anchor: Anchor.center,
      position: Vector2(32, 80),
      scale: 1.0,
    ));
    if (enemy_score(type) > 0) {
      column.add(VectorText(
        text: enemy_score(type).toString(),
        anchor: Anchor.center,
        position: Vector2(32, 100),
        scale: 1.0,
      ));
    }

    return column;
  }

  Future<Component> _voxel({
    required String image,
    required int frames,
    required double x,
    required Vector3 scale,
    required String name,
    required Type type,
  }) async {
    final voxel = VoxelEntity(
      voxel_image: await images.load(image),
      height_frames: frames,
      exhaust_color: const Color(0xFF00FF80),
      exhaust_color_variance: 0.0,
      parent_size: Vector2.all(64),
    );
    voxel.orientation_matrix.setRotationX(-pi / 12);
    voxel.model_scale.setFrom(scale);
    voxel.exhaust_length = 2;
    _models.add(voxel);

    final column = PositionComponent(
      position: Vector2(x, game_height / 2),
      size: Vector2(64, 110),
      anchor: Anchor.center,
    );
    column.add(voxel);

    column.add(VectorText(
      text: name,
      anchor: Anchor.center,
      position: Vector2(32, 80),
      scale: 1.0,
    ));
    if (enemy_score(type) > 0) {
      column.add(VectorText(
        text: enemy_score(type).toString(),
        anchor: Anchor.center,
        position: Vector2(32, 100),
        scale: 1.0,
      ));
    }

    return column;
  }

  void _selected(_TitleButtons id) {
    _preselected = id;
    switch (id) {
      case _TitleButtons.credits:
        show_screen(Screen.credits);
        break;
      case _TitleButtons.audio:
        push_screen(Screen.audio);
        break;
      case _TitleButtons.controls:
        push_screen(Screen.controls);
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
      if (_preselected == _TitleButtons.audio) _change_audio_mode(-1);
    }
    if (_keys.check_and_consume(GameKey.right)) {
      if (_preselected == _TitleButtons.audio) _change_audio_mode(1);
    }

    _anim += dt * pi / 2;
    _rotation.setRotationY(_anim);

    for (final it in _models) {
      it.orientation_matrix.setRotationX(-pi / 12);
      it.orientation_matrix.multiply(_rotation);
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

  final _font = vector_font;
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

class _TitlePulsar extends PositionComponent with HasPaint {
  late FragmentShader _shader;

  double _anim_time = 0.0;

  @override
  Future onLoad() async {
    await super.onLoad();
    _shader = await load_shader('pulsar.frag');
    paint.shader = _shader;
  }

  @override
  void update(double dt) {
    super.update(dt);
    _anim_time += dt;
  }

  @override
  void render(Canvas canvas) {
    final img = pixelate(size.x.toInt(), size.y.toInt(), (canvas) {
      _shader.setFloat(0, size.x);
      _shader.setFloat(1, size.y);
      _shader.setFloat(2, _anim_time);
      _shader.setFloat(3, 3.0);
      _shader.setFloat(4, 0);
      paint.shader = _shader;
      canvas.drawRect(Rect.fromLTWH(0, 0, size.x, size.y), paint);
    });
    paint.shader = null;
    canvas.drawImage(img, Offset.zero, paint);
  }
}
