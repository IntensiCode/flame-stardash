import 'package:stardash/core/common.dart';
import 'package:stardash/game/base/game_phase.dart';
import 'package:stardash/game/base/kinds.dart';

class EnemyDestroyed with Message {
  EnemyDestroyed(this.target);

  final Hostile target;
}

class EnteringLevel with Message {
  EnteringLevel(this.number);

  final int number;
}

class GamePhaseUpdate with Message {
  GamePhaseUpdate(this.phase);

  final GamePhase phase;
}

class LeavingLevel with Message {
  LeavingLevel(this.next);

  final int next;
}

class PlayerDestroyed with Message {
  PlayerDestroyed({required this.game_over});

  final bool game_over;
}

class PlayingLevel with Message {
  PlayingLevel(this.number);

  final int number;
}

class Rumble with Message {
  Rumble({this.duration = 1, this.haptic = true});

  final double duration;
  final bool haptic;
}

class ShowDebugText with Message {
  ShowDebugText({
    this.title,
    required this.text,
    this.blink_text = false,
    this.stay_longer = false,
    this.when_done,
  });

  String? title;
  final String text;
  final bool blink_text;
  final bool stay_longer;
  final Function? when_done;
}

class ShowInfoText with Message {
  ShowInfoText({
    this.title,
    required this.text,
    this.blink_text = true,
    this.hud_align = false,
    this.stay_longer = false,
    this.when_done,
  });

  String? title;
  final String text;
  final bool blink_text;
  final bool hud_align;
  final bool stay_longer;
  final Function? when_done;
}

class SuperZapper with Message {
  SuperZapper({required this.all});

  final bool all;
}
