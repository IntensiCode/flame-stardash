import 'package:stardash/aural/audio_system.dart';
import 'package:stardash/background/stars.dart';
import 'package:stardash/core/common.dart';
import 'package:stardash/game/base/game_phase.dart';
import 'package:stardash/game/base/has_context.dart';
import 'package:stardash/game/base/kinds.dart';
import 'package:stardash/game/base/messages.dart';
import 'package:stardash/game/enemies/enemy_spawner.dart';
import 'package:stardash/game/game_screen.dart';
import 'package:stardash/game/hud.dart';
import 'package:stardash/game/info_overlay.dart';
import 'package:stardash/game/level/level.dart';
import 'package:stardash/game/level/level_color.dart';
import 'package:stardash/game/level/level_path.dart';
import 'package:stardash/game/levels.dart';
import 'package:stardash/game/player/player.dart';
import 'package:stardash/game/player/player_bullet.dart';
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
    await add(stars..centerOffset.setFrom(game_center));

    await load_from_storage('game_state', this);
    await audio.preload();

    await addAll([EnemySpawner()]);
    await addAll([levels, level, player]);

    await addAll([Hud(), InfoOverlay(() => 1.0)]);
  }

  @override
  void onMount() {
    super.onMount();
    onKey('<C-c>', () => level_complete());
    onKey('<C-l>', () => leave_level());
    onKey('<C-n>', () => _enterNextLevel());

    player.mounted.then((_) {
      log_warn('now');
      enter_level();
    });
  }

  void _enterNextLevel() {
    current_level++;
    enter_level();
  }
}

mixin _GamePhaseTransition on GameScreen, HasContext {
  static const double _transition_duration = 2.5; // Increased duration

  int current_level = 1;
  double _transition_progress = 0.0;

  void enter_level() {
    log_info('enter level $current_level');

    removeWhere((it) => it is PlayerBullet);
    removeWhere((it) => it is Hostile);

    phase = GamePhase.entering_level;
    _transition_progress = 0.0;

    final level = levels.level_config(current_level);
    _setup_level(level.number, level.pathType, level.color);
    send_message(EnteringLevel(current_level));
    audio.play(Sound.incoming);
  }

  void play_level() {
    _transition_progress = 1.0;
    phase = GamePhase.playing_level;
    log_info('Phase -> play_level');
    send_message(PlayingLevel(current_level));
  }

  void level_complete() {
    log_info('leave complete');

    phase = GamePhase.level_complete;
    _transition_progress = 0.0;

    show_info('Level Complete!', title: 'Level $current_level', longer: true);
    send_message(LevelComplete());
    audio.play(Sound.bonus1);
  }

  void leave_level() {
    log_info('leave level');

    removeWhere((it) => it is PlayerBullet);
    removeWhere((it) => it is Hostile);

    phase = GamePhase.leaving_level;
    _transition_progress = 0.0;

    current_level++;
    send_message(LeavingLevel(current_level));
    audio.play(Sound.incoming);

    stars.burst();
  }

  void _setup_level(int number, LevelPathType pathType, LevelColor color) {
    level.load_level(
      number: number,
      path_type: pathType,
      color: color,
    );
    // stars.centerOffset.setFrom(level.mapGridToScreen(0, 1));
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
        _transition_progress += dt / _transition_duration;
        if (_transition_progress >= 1.0) play_level();
        _notify_update_transition();

      case GamePhase.playing_level:
        // Normal gameplay updates happen via components' own update methods
        // TODO: Add logic to trigger leaving_level (e.g., level complete)
        break;

      case GamePhase.level_complete:
        _transition_progress += dt / _transition_duration;
        if (_transition_progress >= 1.0) leave_level();

      case GamePhase.leaving_level:
        _transition_progress += dt / _transition_duration;
        if (_transition_progress >= 1.0) enter_level();
        _notify_update_transition();

      case GamePhase.game_over:
        // TODO: Handle game over state
        break;
    }
  }

  void _notify_update_transition() {
    level.update_transition(phase, _transition_progress);
    player.update_transition(phase, _transition_progress);
  }
}
