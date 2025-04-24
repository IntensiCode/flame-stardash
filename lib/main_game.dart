import 'dart:async';
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/foundation.dart';
import 'package:stardash/aural/audio_system.dart';
import 'package:stardash/aural/music_score.dart';
import 'package:stardash/core/atlas.dart';
import 'package:stardash/core/common.dart';
import 'package:stardash/game/debug_overlay.dart';
import 'package:stardash/input/shortcuts.dart';
import 'package:stardash/main_controller.dart';
import 'package:stardash/ui/fonts.dart';
import 'package:stardash/util/log.dart';
import 'package:stardash/util/messaging.dart';
import 'package:stardash/util/performance.dart';

class MainGame extends FlameGame<MainController>
    with HasKeyboardHandlerComponents, Messaging, Shortcuts, HasPerformanceTracker {
  //
  final _ticker = Ticker(ticks: tps);

  MainGame() : super(world: MainController()) {
    game = this;
    images = this.images;
    pauseWhenBackgrounded = true;
  }

  @override
  onGameResize(Vector2 size) {
    super.onGameResize(size);
    camera = CameraComponent.withFixedResolution(
      width: game_width,
      height: game_height,
      hudComponents: [
        if (!kReleaseMode) _ticks(),
        if (!kReleaseMode) _frames(),
        if (!kReleaseMode) DebugOverlay(),
      ],
    );
    camera.viewfinder.anchor = Anchor.center;
    camera.viewfinder.position = Vector2(game_width / 2, game_height / 2);
    // camera.viewport.add(hud);
  }

  _ticks() => RenderTps(
        scale: Vector2(0.25, 0.25),
        position: Vector2(0, 0),
        anchor: Anchor.topLeft,
      );

  _frames() => RenderFps(
        scale: Vector2(0.25, 0.25),
        position: Vector2(0, 8),
        anchor: Anchor.topLeft,
      );

  @override
  Future onLoad() async {
    super.onLoad();

    atlas = await game.loadTextureAtlas();

    await add(audio);
    await add(music_score);
    await loadFonts(assets);

    if (!kReleaseMode) {
      log_verbose('force preload audio');
      await audio.preload();
    }
  }

  @override
  void update(double dt) {
    _ticker.generateTicksFor(dt, (it) => super.update(it));
    game_post_process?.update(dt);
  }

  @override
  void renderTree(Canvas canvas) {
    if (game_post_process != null) {
      game_post_process?.post_process(canvas, super.renderTree);
    } else {
      super.renderTree(canvas);
    }
  }
}
