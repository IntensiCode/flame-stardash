import 'package:stardash/aural/audio_system.dart';
import 'package:stardash/game/base/screens.dart';
import 'package:stardash/util/auto_dispose.dart';
import 'package:stardash/util/log.dart';
import 'package:stardash/util/on_message.dart';

final music_score = MusicScore();

class MusicScore extends AutoDisposeComponent {
  String? _target_score;

  String? _current_score;

  @override
  onLoad() {
    on_message<ScreenShowing>((it) {
      final score = _target_score_for(it.screen);
      if (score == null) {
        _target_score = _current_score = null;
        return;
      }

      if (_target_score == score) return;
      _target_score = score;
      log_info('target screen: ${it.screen} => score: $_target_score');
    });
  }

  String? _target_score_for(Screen screen) => switch (screen) {
        _ => 'music/background.ogg',
      };

  @override
  void update(double dt) {
    super.update(dt);
    if (_current_score == _target_score) {
      return;
    } else if (_current_score == null && _target_score != null) {
      if (audio.fade_out_volume == null) {
        log_info('play music $_target_score');
        audio.play_music(_target_score!);
        _current_score = _target_score;
      }
    } else if (_current_score != null) {
      log_info('fade out music $_current_score');
      audio.fade_out_music();
      _current_score = null;
    }
  }
}
