import 'package:stardash/core/common.dart';

enum Screen {
  audio,
  controls,
  credits,
  game_play,
  //hiscore,
  select_game_pad,
  title,
}

class ShowScreen with Message {
  ShowScreen(this.screen);

  final Screen screen;
}

class ScreenShowing with Message {
  ScreenShowing(this.screen);

  final Screen screen;
}

enum ScreenTransition {
  cross_fade,
  fade_out_then_in,
  switch_in_place,
  remove_then_add,
}

abstract interface class ScreenNavigation {
  void popScreen();

  void pushScreen(Screen screen);

  void showScreen(
    Screen screen, {
    ScreenTransition transition = ScreenTransition.fade_out_then_in,
  });
}

void popScreen() {
  final world = game.world;
  (world as ScreenNavigation).popScreen();
}

void pushScreen(Screen it) {
  final world = game.world;
  (world as ScreenNavigation).pushScreen(it);
}

void showScreen(Screen it, {ScreenTransition transition = ScreenTransition.fade_out_then_in}) {
  (game.world as ScreenNavigation).showScreen(it, transition: transition);
}
