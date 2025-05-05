import 'dart:async';

import 'package:flame_audio/flame_audio.dart';
import 'package:stardash/aural/audio_system.dart';
import 'package:stardash/core/common.dart';
import 'package:stardash/util/auto_dispose.dart';
import 'package:stardash/util/log.dart';

class PlatformAudioSystem extends AudioSystem {
  final _sounds = <Sound, AudioPlayer>{};
  final _max_sounds = <AudioPlayer>[];
  final _last_time = <Object, int>{};

  StreamSubscription? _on_end;

  @override
  double? get active_music_volume => FlameAudio.bgm.audioPlayer.volume;

  @override
  set active_music_volume(double? it) {
    final ap = FlameAudio.bgm.audioPlayer;
    if (ap.source == null || !FlameAudio.bgm.isPlaying) return;
    ap.setVolume((it ?? music) * master);
    // if (it == 0 && ap.state == PlayerState.playing) FlameAudio.bgm.pause();
    // if (it > 0 && ap.state != PlayerState.playing) FlameAudio.bgm.resume();
  }

  @override
  Future do_preload() async {
    if (_sounds.isNotEmpty) return;
    for (final it in Sound.values) {
      try {
        _sounds[it] = await _preload_player('${it.name}.wav');
      } catch (e) {
        log_error('failed loading $it: $e');
        if (e.toString().startsWith("NotAllowedError")) break;
      }
    }
  }

  Future<AudioPlayer> _preload_player(String name) async {
    final player = await FlameAudio.play('sound/$name', volume: super.sound);
    player.setReleaseMode(ReleaseMode.stop);
    player.setPlayerMode(PlayerMode.lowLatency);
    player.stop();
    return player;
  }

  @override
  void do_update_volume() {
    log_info('update volume $music');
    active_music_volume = music;
  }

  @override
  Future do_play(Sound sound, double volume_factor) async {
    final it = _sounds[sound];
    if (it == null) {
      log_error('null sound: $sound');
      preload();
      return;
    }

    final last_played_at = _last_time[sound] ?? 0;
    final now = DateTime.timestamp().millisecondsSinceEpoch;
    if (now < last_played_at + 100) return;
    _last_time[sound] = now;

    _max_sounds.removeWhere((it) => it.state != PlayerState.playing);
    if (_max_sounds.length > 10) {
      final fifo = _max_sounds.removeAt(0);
      await fifo.stop();
    }

    if (it.state != PlayerState.stopped) await it.stop();
    final volume = (volume_factor * super.sound * super.master).clamp(0.0, 1.0);
    await it.setVolume(volume);
    await it.resume();
  }

  @override
  Future do_preload_one_shot_sample(String filename) async => await FlameAudio.audioCache.load(filename);

  final _queued = <(String, double, bool, bool, Function(Disposable))>[];

  AudioPlayer? _active_one_shot;

  @override
  Future<Disposable> do_play_one_shot_sample(
    String filename, {
    required double volume_factor,
    required bool cache,
    required bool loop,
  }) async {
    if (_queued.any((it) => it.$1 == filename)) return Disposable.disposed;

    Disposable? late;
    if (_active_one_shot?.state == PlayerState.playing) {
      final it = (filename, volume_factor, cache, loop, (it) => late = it);
      _queued.add(it);
      return Disposable.wrap(() {
        late?.dispose();
        _queued.remove(it);
      });
    }

    final last_played_at = _last_time[filename] ?? 0;
    final now = DateTime.timestamp().millisecondsSinceEpoch;
    if (now < last_played_at + 100) return Disposable.disposed;
    _last_time[filename] = now;

    await FlameAudio.audioCache.load(filename);

    final volume = (volume_factor * super.sound * super.master).clamp(0.0, volume_factor * master);
    final it = await FlameAudio.play(filename, volume: volume);
    it.setReleaseMode(loop ? ReleaseMode.loop : ReleaseMode.release);

    it.onPlayerStateChanged.listen((event) async {
      if (event == PlayerState.stopped || event == PlayerState.completed || event == PlayerState.disposed) {
        if (_active_one_shot != it) return;
        _active_one_shot = null;
        if (_queued.isNotEmpty) {
          final (filename, volume_factor, cache, loop, hook) = _queued.removeAt(0);
          final it = await do_play_one_shot_sample(filename, volume_factor: volume_factor, cache: cache, loop: loop);
          hook(it);
        }
      }
    });

    return Disposable.wrap(() {
      it.setReleaseMode(ReleaseMode.release);
      it.stop();
    });
  }

  @override
  Future do_play_music(String filename, {bool loop = true, Hook? on_end}) async {
    do_stop_active_music();

    log_info('playing music via audio_players');
    final volume = (super.music * super.master).clamp(0.0, 1.0);
    await FlameAudio.bgm.play(filename, volume: volume);

    FlameAudio.bgm.audioPlayer.setReleaseMode(loop ? ReleaseMode.loop : ReleaseMode.release);

    if (on_end != null || !loop) {
      if (_on_end != null) throw 'ensure do_stop_active_music has been called';
      _on_end = FlameAudio.bgm.audioPlayer.onPlayerComplete.listen((_) {
        log_info('bgm complete');
        if (!loop) do_stop_active_music();
        if (on_end != null) on_end();
      });
    }
  }

  @override
  void do_stop_active_music() async {
    _on_end?.cancel();
    _on_end = null;

    if (!FlameAudio.bgm.isPlaying) return;

    log_info('stopping active bgm');
    await FlameAudio.bgm.stop();
  }
}
