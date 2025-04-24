import 'package:stardash/aural/audio_system.dart';
import 'package:stardash/background/stars.dart';
import 'package:stardash/core/common.dart';
import 'package:stardash/game/base/decals.dart';
import 'package:stardash/game/base/game_phase.dart';
import 'package:stardash/game/base/has_context.dart';
import 'package:stardash/game/base/kinds.dart';
import 'package:stardash/game/base/messages.dart';
import 'package:stardash/game/base/screens.dart';
import 'package:stardash/game/enemies/enemies.dart';
import 'package:stardash/game/enemies/enemy_spawner.dart';
import 'package:stardash/game/game_screen.dart';
import 'package:stardash/game/hud.dart';
import 'package:stardash/game/info_overlay.dart';
import 'package:stardash/game/level/level.dart';
import 'package:stardash/game/level/level_transition.dart';
import 'package:stardash/game/levels.dart';
import 'package:stardash/game/player/player.dart';
import 'package:stardash/util/game_data.dart';
import 'package:stardash/util/log.dart';
import 'package:stardash/util/storage.dart';

class GamePlayScreen extends GameScreen with HasContext, HasGameData, _GamePhaseTransition {
  @override
  void load_state(GameData data) {
    log_info('load game: $data');
    current_level = data['currentLevel'] ?? current_level;
    // TODO: Player.load_state
  }

  @override
  GameData save_state(GameData data) {
    data['currentLevel'] = current_level;
    // TODO: Player.save_state
    log_info('save game: $data');
    return data;
  }

  @override
  Future onLoad() async {
    await add(stars..center_offset.setFrom(game_center));

    await load_from_storage('game_state', this);
    await audio.preload();

    await addAll([levels, level, player]);
    await addAll([enemies, spawner]);
    await add(decals);

    await addAll([Hud(), InfoOverlay(() => 1.0)]);
  }

  @override
  void onMount() {
    super.onMount();
    if (dev) {
      onKey('<A-c>', () => level_complete());
      onKey('<A-l>', () => leave_level());
      onKey('<A-n>', () => change_level(1));
      onKey('<A-p>', () => change_level(-1));
    }
    player.mounted.then((_) => enter_level());
  }

  void change_level(int step) {
    current_level += step;
    if (current_level < 1) current_level = 1;
    enter_level();
  }
}

mixin _GamePhaseTransition on GameScreen, HasContext {
  static const double entering_duration = 1.5;
  static const double game_over_duration = 3.0;
  static const double completed_duration = 1.5;
  static const double leaving_duration = 3.0;

  int current_level = dev ? 4 : 1;
  double _transition_progress = 0.0;

  void enter_level() {
    log_verbose('Enter level $current_level');

    removeWhere((it) => it is Hostile);

    phase = GamePhase.entering_level;
    _transition_progress = 0.0;

    final level = levels.level_config(current_level);
    _setup_level(level);
    send_message(EnteringLevel(current_level));
    audio.play(Sound.incoming);
  }

  void play_level() {
    _transition_progress = 1.0;
    phase = GamePhase.playing_level;
    send_message(PlayingLevel(current_level));
  }

  void game_over() {
    phase = GamePhase.game_over;
    _transition_progress = 0.0;

    show_info('Manta destroyed!', title: 'GAME OVER', longer: true);
    audio.play(Sound.game_over);
  }

  void level_complete() {
    phase = GamePhase.level_completed;
    _transition_progress = 0.0;

    show_info('Level Complete!', title: 'Level $current_level', longer: true);
    send_message(LevelComplete());
    audio.play(Sound.bonus1);
  }

  void leave_level() {
    log_info('Leave level');

    removeWhere((it) => it is Hostile);

    phase = GamePhase.leaving_level;
    _transition_progress = 0.0;

    current_level++;
    send_message(LeavingLevel(current_level));
    audio.play(Sound.incoming);

    stars.burst();
  }

  void _setup_level(LevelConfig config) {
    level.load_level(config);
    stars.center_offset.setFrom(level.map_grid_to_screen(0, 1000));
    stars.base_alpha = 0.33;
  }

  @override
  void update(double dt) {
    super.update(dt); // Let GameScreen handle pausing, rumble, etc.
    _update_phase_transition(dt);
  }

  void _update_phase_transition(double dt) {
    switch (phase) {
      case GamePhase.entering_level:
        _transition_progress += dt / entering_duration;
        if (_transition_progress >= 1.0) play_level();
        _notify_update_transition();

      case GamePhase.playing_level:
        if (player.is_dead) {
          game_over();
        } else if (spawner.defeated) {
          level_complete();
        }
        break;

      case GamePhase.game_over:
        _transition_progress += dt / game_over_duration;
        if (_transition_progress >= 1.0) show_screen(Screen.title);
        
      case GamePhase.level_completed:
        _transition_progress += dt / completed_duration;
        if (_transition_progress >= 1.0) leave_level();

      case GamePhase.leaving_level:
        _transition_progress += dt / leaving_duration;
        if (_transition_progress >= 1.0) enter_level();
        _notify_update_transition();
    }
  }

  void _notify_update_transition() {
    LevelTransition.update_static(phase, _transition_progress);

    final transitioning = children.whereType<LevelTransition>();
    for (final it in transitioning) {
      it.update_transition(phase, _transition_progress);
    }

    // Player update (kept separate for now, might need LevelTransition later?)
    player.update_transition(phase, _transition_progress);
  }
}
