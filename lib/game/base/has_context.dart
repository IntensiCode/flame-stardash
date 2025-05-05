import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:stardash/core/common.dart';
import 'package:stardash/game/game_screen.dart';
import 'package:stardash/game/base/messages.dart';
import 'package:stardash/game/base/stage_cache.dart';
import 'package:stardash/input/keys.dart';
import 'package:stardash/util/messaging.dart';

/// Mixin to provide cross-component-hierarchy access to other, shared components. The [stage] is always required as
/// the root. The [cache] is used to lookup everything only once. Many components need shared components like for
/// example [Decals]. To not have all this references explicitly everywhere, this mixin is used instead.
mixin HasContext on Component {
  GameScreen? _stage;
  CollisionDetection<ShapeHitbox, Sweep<ShapeHitbox>>? _collision;
  Messaging? _messaging;

  GameScreen get stage => _stage ??= findParent<GameScreen>(includeSelf: true)!;

  Messaging get messaging => _messaging ??= stage.messaging;

  void send_message<T extends Message>(T message) => messaging.send(message);

  StageCache get cache => stage.stage_cache;

  Keys get keys => stage.stage_keys;

  CollisionDetection<ShapeHitbox, Sweep<ShapeHitbox>> get collisionDetection => _collision ??= stage
      .ancestors(includeSelf: true)
      .whereType<HasCollisionDetection<Sweep<ShapeHitbox>>>()
      .first
      .collisionDetection;

  void info(String message, {String? title, bool blink = true, bool hud = false, Function? done}) =>
      send_message(ShowInfoText(
        title: title,
        text: message,
        blink_text: blink,
        hud_align: hud,
        when_done: done,
      ));
}
