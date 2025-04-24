import 'dart:async';
import 'dart:math';
import 'dart:typed_data'; // Needed for ByteData

import 'package:flutter/foundation.dart';
import 'package:mp_audio_stream/mp_audio_stream.dart';
import 'package:stardash/aural/audio_system.dart';
import 'package:stardash/core/common.dart';
import 'package:stardash/util/auto_dispose.dart';
import 'package:stardash/util/log.dart';

class _PlayState {
  _PlayState(this.sample, {this.loop = false, required this.volume}) : this.paused = false;

  Float32List sample;
  int sample_pos = 0;

  bool loop;
  bool paused;
  Hook? on_end;

  double volume;
}

class PlatformAudioSystem extends AudioSystem {
  AudioStream? _stream;
  final _samples = <Sound, Float32List>{};
  final _last_time = <Sound, int>{};
  final _one_shot_cache = <String, Future<Float32List>>{};
  final _play_state = <_PlayState>[];
  final _play_pool = <_PlayState>[];
  _PlayState? _active_music;

  @override
  double? get active_music_volume => _active_music?.volume;

  @override
  set active_music_volume(double? it) {
    _active_music?.volume = it ?? music;
    _active_music?.paused = _active_music?.volume == 0;
  }

  @override
  Future do_preload() async {
    if (_samples.isEmpty) await _make_samples();
  }

  Future _make_samples() async {
    for (final it in Sound.values) {
      _samples[it] = await _make_sample('audio/sound/${it.name}.wav');
    }
  }

  int _find_data_chunk(Uint8List bytes) {
    bool match(int i) => String.fromCharCodes(bytes.skip(i).take(4)) == 'data';
    if (match(70)) return 70;
    if (match(36)) return 36;
    log_warn('Searching for data chunk...');
    for (int i = 0; i < 70; i++) {
      int left = 70 - i;
      int right = 70 + i;
      if (match(left)) return left;
      if (match(right)) return right;
    }
    assert(false, 'no data chunk found');
    return 70;
  }

  Future<Float32List> _make_sample(String fileName) async {
    final bytes = await game.assets.readBinaryFile(fileName);
    final riff = String.fromCharCodes(bytes.take(4));
    assert(riff == 'RIFF');
    final wave = String.fromCharCodes(bytes.skip(8).take(4));
    assert(wave == 'WAVE');
    final fmtChunk = String.fromCharCodes(bytes.skip(12).take(4));
    assert(fmtChunk == 'fmt ');

    int offset = _find_data_chunk(bytes) + 8;
    final bd = ByteData.view(bytes.buffer, offset - 8);
    final a = bd.getInt32(0, Endian.little);
    final count = bd.getInt32(4, Endian.little);
    log_verbose('$fileName: $a $count ${bytes.length}');

    final data = Float32List(count);
    for (int i = 0; i < count; i++) {
      data[i] = ((bytes[offset + i] / 128) - 1);
    }
    return data;
  }

  @override
  void do_update_volume() {
    log_info('update volume $music');
    active_music_volume = music;
  }

  @override
  Future do_play(Sound sound, double volume_factor) async {
    if (_samples.isEmpty || _samples[sound] == null) await preload();

    final last_played_at = _last_time[sound] ?? 0;
    final now = DateTime.timestamp().millisecondsSinceEpoch;
    if (now < last_played_at + 100) return;
    _last_time[sound] = now;

    final volume = (volume_factor * super.sound * super.master).clamp(0.0, 1.0);
    _play_state.add(_get_play_state(_samples[sound]!, volume));
  }

  _PlayState _get_play_state(Float32List sample, volume, {loop = false}) {
    if (_play_pool.isNotEmpty) {
      final reused = _play_pool.removeLast();
      reused.sample = sample;
      reused.sample_pos = 0;
      reused.loop = loop;
      reused.paused = false;
      reused.on_end = null;
      reused.volume = volume;
      return reused;
    }
    return _PlayState(sample, volume: volume, loop: loop);
  }

  @override
  Future do_preload_one_shot_sample(String filename) async =>
      await (_one_shot_cache[filename] ??= _load_one_shot(filename));

  @override
  Future<Disposable> do_play_one_shot_sample(
    String filename, {
    required double volume_factor,
    required bool cache,
    required bool loop,
  }) async {
    final cacheKey = filename;
    var loadFilename = filename;
    if (filename.endsWith('.ogg'))
      loadFilename = filename.replaceFirst('.ogg', '.wav');
    else if (!filename.endsWith('.wav')) loadFilename = '$filename.wav';

    final dataFuture = _one_shot_cache[cacheKey] ??= _load_one_shot(loadFilename);
    if (!cache) _one_shot_cache.remove(cacheKey);

    final data = await dataFuture;
    final volume = (volume_factor * super.sound * super.master).clamp(0.0, 1.0);
    final playing = _get_play_state(data, volume, loop: loop);
    _play_state.add(playing);
    return Disposable.wrap(() {
      if (_play_state.contains(playing)) {
        _play_state.remove(playing);
        _play_pool.add(playing);
      }
    });
  }

  Future<Float32List> _load_one_shot(String filename) async {
    final loadTarget = filename.endsWith('.wav') ? filename : '$filename.wav';
    log_verbose('load sample $loadTarget');
    return _make_sample('audio/$loadTarget');
  }

  @override
  Future do_play_music(String filename, {bool loop = true, Hook? on_end}) async {
    log_info('play music via mp_audio_stream (WAV)');

    do_stop_active_music();

    var wav_name = filename;
    if (filename.endsWith('.ogg') || filename.endsWith('.mp3')) {
      wav_name = '${filename.substring(0, filename.lastIndexOf('.'))}.wav';
    } else if (!filename.endsWith('.wav')) {
      wav_name = '$filename.wav';
    }

    final data = await _make_sample('audio/$wav_name');
    final volume = (super.music * super.master).clamp(0.0, 1.0);
    _active_music = _get_play_state(data, volume, loop: loop);
    _active_music!.on_end = on_end;
    _play_state.add(_active_music!);
  }

  @override
  void do_stop_active_music() {
    final it = _active_music;

    if (it == null) return;
    _play_state.remove(it);
    _play_pool.add(it);

    _active_music = null;
  }

  bool _paused = false;

  @override
  void update_paused(bool paused) => _paused = paused;

  // Component

  @override
  Future onLoad() async {
    super.onLoad();
    _init_audio_stream();
  }

  // Implementation

  void _init_audio_stream() {
    if (_stream != null) return;
    _stream = getAudioStream();
    final result = _stream!.init(
      bufferMilliSec: 500,
      waitingBufferMilliSec: 100,
      channels: 1,
      sampleRate: 11025,
    );
    log_verbose('audio mixing stream started: $result');
    _stream!.resume();
    _mix_stream();
  }

  void _mix_stream() async {
    const hz = 25; // divides 11025 and 1000
    const rate = 11025;
    const step = rate ~/ hz;
    final mixed = Float32List(step);
    log_info('mixing at $rate Hz - frame step $step - buffer bytes ${mixed.length}');

    Timer.periodic(const Duration(milliseconds: 1000 ~/ hz), (t) {
      mixed.fillRange(0, mixed.length, 0);
      if (_play_state.isEmpty || muted || _paused) {
        _stream!.push(mixed);
        return;
      }

      for (final it in _play_state) {
        if (it.paused) continue;

        final data = it.sample;
        final start = it.sample_pos;
        final end = min(start + step, data.length);
        for (int i = start; i < end; i++) {
          final at = i - start;
          mixed[at] += data[i] * it.volume;
        }
        if (end == data.length) {
          it.on_end?.call();
          it.sample_pos = it.loop ? 0 : -1;
        } else {
          it.sample_pos = end;
        }
      }

      double? compress;
      for (int i = 0; i < mixed.length; i++) {
        final v = mixed[i];
        if (v.abs() > 1) compress = max(compress ?? 0, v.abs());
        mixed[i] = v * master;
      }

      if (compress != null) {
        for (int i = 0; i < mixed.length; i++) {
          mixed[i] /= compress;
        }
      }

      _stream!.push(mixed);

      final done = _play_state.where((e) => e.sample_pos == -1);
      for (final it in done) {
        _play_pool.add(it);
      }
      _play_state.removeWhere((e) => e.sample_pos == -1);
    });
  }
}
