import 'package:collection/collection.dart';
import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:stardash/aural/audio_menu.dart';
import 'package:stardash/core/atlas.dart';
import 'package:stardash/core/common.dart';
import 'package:stardash/credits.dart';
import 'package:stardash/game/base/configuration.dart';
import 'package:stardash/game/base/messages.dart';
import 'package:stardash/game/base/screens.dart';
import 'package:stardash/game/game_play_screen.dart';
import 'package:stardash/input/controls.dart';
import 'package:stardash/input/select_game_pad.dart';
import 'package:stardash/input/shortcuts.dart';
import 'package:stardash/title_screen.dart';
import 'package:stardash/ui/flow_text.dart';
import 'package:stardash/ui/fonts.dart';
import 'package:stardash/util/auto_dispose.dart';
import 'package:stardash/util/bitmap_button.dart';
import 'package:stardash/util/extensions.dart';
import 'package:stardash/util/log.dart';
import 'package:stardash/util/messaging.dart';
import 'package:stardash/util/nine_patch_image.dart';
import 'package:stardash/web_play_screen.dart';

class MainController extends World
    with AutoDispose, HasAutoDisposeShortcuts, HasCollisionDetection<Sweep<ShapeHitbox>>, TapCallbacks
    implements ScreenNavigation {
  //
  @override
  bool get is_active => children.singleOrNull?.runtimeType != SelectGamePad;

  final _stack = <Screen>[];

  @override
  onLoad() async {
    super.onLoad();
    await configuration.load();
    autoDispose("ShowScreen", messaging.listen<ShowScreen>((it) => showScreen(it.screen)));
  }

  @override
  void onMount() {
    super.onMount();

    if (dev) {
      showScreen(Screen.game_play);
      // showScreen(Screen.title);
    } else {
      add(WebPlayScreen());
    }

    if (dev) {
      onKeys(['<A-d>', '='], (_) {
        debug = !debug;
        send_message(ShowInfoText(title: 'Cheat', text: 'Hitbox Debug Mode: $debug'));
      });

      onKeys(['<A-r>', '1'], (_) => pushScreen(Screen.game_play));
      onKeys(['<A-r>', '7'], (_) => pushScreen(Screen.credits));
      onKeys(['<A-a>', '8'], (_) => pushScreen(Screen.audio));
      onKeys(['<A-c>', '9'], (_) => pushScreen(Screen.controls));
      onKeys(['<A-t>', '0'], (_) => showScreen(Screen.title));
    }
  }

  @override
  void popScreen() {
    log_info('pop screen with stack=$_stack and children=${children.map((it) => it.runtimeType)}');
    showScreen(_stack.removeLastOrNull() ?? Screen.title);
  }

  @override
  void pushScreen(Screen it) {
    log_info('push screen $it with stack=$_stack and children=${children.map((it) => it.runtimeType)}');
    log_info('triggered: $_triggered');
    if (_stack.lastOrNull == it) throw 'stack already contains $it';
    if (_triggered != null) _stack.add(_triggered!);
    showScreen(it);
  }

  Screen? _triggered;
  StackTrace? _previous;

  @override
  void showScreen(
    Screen screen, {
    ScreenTransition transition = ScreenTransition.fade_out_then_in,
  }) {
    if (_triggered == screen) {
      log_error('show $screen with stack=$_stack and children=${children.map((it) => it.runtimeType)}');
      log_error('duplicate trigger ignored: $screen', StackTrace.current);
      log_error('previous trigger', _previous);
      return;
    }
    _triggered = screen;
    _previous = StackTrace.current;

    if (children.length > 1) {
      log_warn('show $screen with stack=$_stack and more than one children=${children.map((it) => it.runtimeType)}');
    }

    void call_again() {
      // still the same? you never know.. :]
      if (_triggered == screen) {
        _triggered = null;
        showScreen(screen, transition: transition);
      } else {
        log_warn('triggered screen changed: $screen != $_triggered');
        log_warn('show $screen with stack=$_stack and children=${children.map((it) => it.runtimeType)}');
      }
    }

    const fadeDuration = 0.2;

    final out = children.lastOrNull;
    if (out != null) {
      switch (transition) {
        case ScreenTransition.cross_fade:
          out.fadeOutDeep(seconds: fadeDuration, and_remove: true);
          break;
        case ScreenTransition.fade_out_then_in:
          out.fadeOutDeep(seconds: fadeDuration, and_remove: true);
          out.removed.then((_) => call_again());
          return;
        case ScreenTransition.switch_in_place:
          out.removeFromParent();
          break;
        case ScreenTransition.remove_then_add:
          out.removeFromParent();
          out.removed.then((_) => call_again());
          return;
      }
    }

    final it = added(_makeScreen(screen));
    switch (transition) {
      case ScreenTransition.cross_fade:
        it.mounted.then((_) => it.fadeInDeep(seconds: fadeDuration));
        break;
      case ScreenTransition.fade_out_then_in:
        it.mounted.then((_) => it.fadeInDeep(seconds: fadeDuration));
        break;
      case ScreenTransition.switch_in_place:
        break;
      case ScreenTransition.remove_then_add:
        break;
    }

    messaging.send(ScreenShowing(screen));
  }

  Component _makeScreen(Screen it) => switch (it) {
        Screen.audio => AudioMenu(),
        Screen.controls => Controls(),
        Screen.credits => Credits(),
        Screen.game_play => GamePlayScreen(),
        Screen.select_game_pad => SelectGamePad(),
        Screen.title => TitleScreen(),
      };

  @override
  void onTapUp(TapUpEvent event) {
    if (!dev) return;

    game.world.children.whereType<Inspector>().forEach((it) => it.removeFromParent());

    for (final it in descendants(reversed: true).whereType<PositionComponent>()) {
      if (it is Hitbox) continue;
      if (it is Inspector) continue;
      if (it is FlowText && it.parent is Inspector) continue;
      if (it is NinePatchComponent && it.parent?.parent is Inspector) continue;
      if (it.containsPoint(event.localPosition)) {
        final t = !it.debugMode;
        for (final d in it.descendants(includeSelf: true)) {
          d.debugMode = t;
        }
        if (it is Snapshot) it.clearSnapshot();
        if (it.debugMode) game.world.add(Inspector(it)..position.setFrom(event.localPosition));
        return;
      }
    }
  }
}

class Inspector extends PositionComponent {
  Inspector(this.target) {
    add(to_parent = BitmapButton(
      bg_nine_patch: atlas.sprite('button_plain.png'),
      text: 'Go to Parent',
      position: Vector2(0, -32),
      font: mini_font,
      font_scale: 1,
      onTap: () {
        final tp = target.parent;
        if (tp != null) target = tp;
      },
    )..priority = 10);

    add(info = FlowText(
      background: atlas.sprite('button_plain.png'),
      text: target.toString(),
      font: mini_font,
      font_scale: 1,
      size: Vector2(240, 128),
    ));
  }

  Component target;

  late BitmapButton to_parent;
  late FlowText info;

  @override
  update(double dt) {
    super.update(dt);

    to_parent.isVisible = target.parent != null;

    final lines = <String>[];
    lines.add(target.runtimeType.toString());
    lines.add('\n');
    lines.add('Parent: ${target.parent?.runtimeType}');
    if (target case PositionComponent it) {
      lines.add('Position: ${it.x.round()} x ${it.y.round()}');
      lines.add('Size: ${it.x.round()} x ${it.y.round()}');
    }
    lines.add('Priority: ${target.priority}');

    final text = lines.join('\n');
    if (info.text == text) return;

    info.removeFromParent();
    add(info = FlowText(
      background: atlas.sprite('button_plain.png'),
      text: text,
      font: mini_font,
      font_scale: 1,
      size: Vector2(240, 256),
    ));
  }
}
