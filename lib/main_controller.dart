import 'package:collection/collection.dart';
import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:stardash/aural/audio_menu.dart';
import 'package:stardash/core/common.dart';
import 'package:stardash/credits.dart';
import 'package:stardash/game/base/configuration.dart';
import 'package:stardash/game/base/screens.dart';
import 'package:stardash/game/debug_overlay.dart';
import 'package:stardash/game/game_play_screen.dart';
import 'package:stardash/input/controls.dart';
import 'package:stardash/input/select_game_pad.dart';
import 'package:stardash/input/shortcuts.dart';
import 'package:stardash/post/fade_screen.dart';
import 'package:stardash/title_screen.dart';
import 'package:stardash/util/auto_dispose.dart';
import 'package:stardash/util/extensions.dart';
import 'package:stardash/util/log.dart';
import 'package:stardash/util/messaging.dart';
import 'package:stardash/web_play_screen.dart';

class MainController extends World
    with AutoDispose, HasAutoDisposeShortcuts, HasCollisionDetection<Sweep<ShapeHitbox>>
    implements ScreenNavigation {
  //

  @override // IIRC this is to have the SelectGamePad screen capture all input!?
  bool get is_active => !children.any((it) => it.runtimeType == SelectGamePad);

  final _stack = <Screen>[];

  @override
  onLoad() async {
    super.onLoad();
    await configuration.load();
    auto_dispose("ShowScreen", messaging.listen<ShowScreen>((it) => show_screen(it.screen)));
  }

  @override
  void onMount() {
    super.onMount();

    if (dev) {
      // show_screen(Screen.game_play);
      show_screen(Screen.title);
    } else {
      add(WebPlayScreen());
    }

    if (dev) {
      onKeys(['<A-d>', '='], (_) {
        debug = !debug;
        show_debug("Debug Mode: $debug");
      });

      onKeys(['1'], (_) => push_screen(Screen.game_play));
      onKeys(['7'], (_) => push_screen(Screen.credits));
      onKeys(['8'], (_) => push_screen(Screen.audio));
      onKeys(['9'], (_) => push_screen(Screen.controls));
      onKeys(['0'], (_) => show_screen(Screen.title));
    }
  }

  @override
  void pop_screen() {
    log_info('pop screen with stack=$_stack and children=${children.map((it) => it.runtimeType)}');
    show_screen(_stack.removeLastOrNull() ?? Screen.title);
  }

  @override
  void push_screen(Screen it) {
    log_info('push screen $it with stack=$_stack and children=${children.map((it) => it.runtimeType)}');
    log_info('triggered: $_triggered');
    if (_stack.lastOrNull == it) throw 'stack already contains $it';
    if (_triggered != null) _stack.add(_triggered!);
    show_screen(it);
    show_debug("push screen $it");
  }

  Screen? _triggered;
  StackTrace? _previous;

  @override
  void show_screen(Screen screen, {ScreenTransition transition = ScreenTransition.fade_out_then_in}) {
    show_debug("show screen $screen");

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
        show_screen(screen, transition: transition);
      } else {
        log_warn('triggered screen changed: $screen != $_triggered');
        log_warn('show $screen with stack=$_stack and children=${children.map((it) => it.runtimeType)}');
      }
    }

    const fade_duration = 0.2;

    final out = children.lastOrNull;
    if (out != null) {
      switch (transition) {
        case ScreenTransition.cross_fade:
          game_post_process = FadeScreen.fade_out(seconds: fade_duration, and_remove: out);
          break;
        case ScreenTransition.fade_out_then_in:
          game_post_process = FadeScreen.fade_out(seconds: fade_duration, and_remove: out);
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
        it.mounted.then((_) {
          game_post_process = FadeScreen.fade_in(seconds: fade_duration);
        });
        break;
      case ScreenTransition.fade_out_then_in:
        it.mounted.then((_) {
          game_post_process = FadeScreen.fade_in(seconds: fade_duration);
        });
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
}
