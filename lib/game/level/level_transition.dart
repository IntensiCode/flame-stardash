import 'package:flutter/animation.dart';
import 'package:stardash/game/base/fake_three_d.dart';
import 'package:stardash/game/base/game_phase.dart';

mixin LevelTransition on FakeThreeDee {
  static GamePhase? game_phase;
  static double transition_progress = 0.0;
  static double translation_z = 0.0;

  static void update_static(GamePhase phase, double progress) {
    game_phase = phase;
    transition_progress = progress;
    translation_z = _translation(phase, progress);
  }

  static double _translation(GamePhase phase, double progress) {
    if (phase == GamePhase.entering_level) {
      return 100 * Curves.easeInExpo.transform(1 - progress);
    }
    if (phase == GamePhase.leaving_level) {
      return -10 * Curves.easeInExpo.transform(progress);
    }
    return 0.0;
  }

  /// We need this to handle FakeThreeDee instances that want LevelTransition vs those that don't!
  void update_transition(GamePhase phase, double progress) {
    translation.z = translation_z;
  }
}
