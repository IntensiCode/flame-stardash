import 'dart:math';
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:stardash/core/common.dart';
import 'package:stardash/game/base/game_phase.dart';
import 'package:stardash/game/base/has_context.dart';
import 'package:stardash/game/base/messages.dart';
import 'package:stardash/game/base/screens.dart';
import 'package:stardash/game/base/stage_cache.dart';
import 'package:stardash/input/keys.dart';
import 'package:stardash/input/shortcuts.dart';
import 'package:stardash/ui/fonts.dart';
import 'package:stardash/ui/soft_keys.dart';
import 'package:stardash/util/bitmap_text.dart';
import 'package:stardash/util/game_script.dart';
import 'package:stardash/util/log.dart';
import 'package:stardash/util/messaging.dart';
import 'package:stardash/util/on_message.dart';
import 'package:stardash/voxel/voxel_sprite.dart';

abstract class GameScreen extends GameScriptComponent with HasAutoDisposeShortcuts, HasTimeScale, HasVisibility {
  GameScreen() {
    add(stage_keys);
    add(stage_cache);
  }

  final stage_keys = Keys();
  final stage_cache = StageCache();

  GamePhase _phase = GamePhase.entering_level;

  GamePhase get phase => _phase;

  set phase(GamePhase value) {
    if (_phase == value) return;
    _phase = value;
    send_message(GamePhaseUpdate(_phase));
  }

  bool _paused = false;

  @override
  void onMount() {
    super.onMount();

    on_message<Rumble>((it) => _rumble(it));

    if (cheat) {
      log_info('activate cheat keys');
    }
    if (dev) {
      onKey('-', () => _change_time_scale(-0.25));
      onKey('+', () => _change_time_scale(0.25));
      onKey('<C-k>', () => voxel_cache.clear());
      onKey('<C-j>', () => log_info('cache size: ${voxel_cache.size}'));
    }

    enable_mapping = true;
  }

  double _rumble_time = 0;

  void _rumble(Rumble it) {
    final shake_time = it.duration * 2;
    if (_rumble_time > shake_time * 0.75) return;
    _rumble_time = shake_time;

    if (it.haptic) stage_keys.rumble(it.duration ~/ 0.001);
  }

  @override
  void onRemove() {
    super.onRemove();
    enable_mapping = false;
  }

  void _change_time_scale(double delta) {
    timeScale += delta;
    log_info('Time scale: ${timeScale.toStringAsFixed(2)}');
    if (timeScale < 0.25) timeScale = 0.25;
    if (timeScale > 4.0) timeScale = 4.0;
    send_message(ShowInfoText(text: 'Time scale: ${timeScale.toStringAsFixed(2)}', title: 'Cheat'));
  }

  @override
  void update(double dt) {
    if (stage_cache.has('player')) {
      // final player = stage_cache['player'] as ZaxxonPlayer;
      // if (player.is_dead_or_dying()) {
      //   _update_time_scale();
      //   timeScale *= 0.5;
      // }
    }

    super.update(dt);

    if (stage_keys.any([GameKey.start, GameKey.soft1])) {
      if (!_paused) {
        _paused = true;
        add(_pause_overlay);
      }
    }

    if (_rumble_time > 0) {
      _on_rumble(dt);
    } else {
      _rumble_off.setZero();
    }
  }

  final _rumble_off = Vector2.zero();

  void _on_rumble(double dt) {
    _rumble_time = max(0, _rumble_time - dt);

    if (_rumble_time <= 0) {
      _rumble_time = 0;
      _rumble_off.setZero();
    } else {
      _rumble_off.x = sin(_rumble_time * 913.527) * 4;
      _rumble_off.y = cos(_rumble_time * 715.182) * 4;
    }
  }

  late final _pause_overlay = _PauseOverlay(() => _paused = false);

  @override
  void updateTree(double dt) {
    if (!isVisible) return;
    if (_paused) {
      _pause_overlay.update(dt);
      stage_keys.update(dt);
      return;
    }
    super.updateTree(dt);
  }

  @override
  void renderTree(Canvas canvas) {
    cache_remove_count = 0;
    VoxelSprite.render_count = 0;
    canvas.translate(_rumble_off.x, _rumble_off.y);
    super.renderTree(canvas);
  }
}

class _PauseOverlay extends GameScriptComponent with HasContext {
  _PauseOverlay(this.on_resume) {
    // add(RectangleComponent(size: game_size)..paint.color = const Color(0x80000000));
    add(BitmapText(text: 'PAUSED', position: game_center, font: menu_font, anchor: Anchor.center));
    softkeys('Resume', 'Exit', (it) {
      if (it == SoftKey.left) _resume();
      if (it == SoftKey.right) _back_to_title();
    });
    priority = 1000000;
  }

  void _resume() {
    log_info('Resuming');
    removeFromParent();
    on_resume();
  }

  void _back_to_title() {
    log_info('Exiting to title');
    showScreen(Screen.title);
    _resume();
  }

  final Function on_resume;

  @override
  void update(double dt) {
    super.update(dt);
    if (keys.check_and_consume(GameKey.a_button)) _resume();
    if (keys.check_and_consume(GameKey.b_button)) _resume();
    if (keys.check_and_consume(GameKey.select)) _back_to_title();
    if (keys.check_and_consume(GameKey.start)) _resume();
    if (keys.check_and_consume(GameKey.soft1)) _resume();
    if (keys.check_and_consume(GameKey.soft2)) _back_to_title();
  }
}
