import 'package:stardash/game/base/voxel_entity.dart';
import 'package:stardash/util/auto_dispose.dart';
import 'package:stardash/util/log.dart';

enum VideoMode {
  performance,
  balanced,
  quality,
}

void apply_video_mode() {
  switch (video) {
    case VideoMode.performance:
      VoxelEntity.render_exhaust = false;
      VoxelEntity.frame_skip = 4;

    case VideoMode.balanced:
      VoxelEntity.render_exhaust = false;
      VoxelEntity.frame_skip = 2;

    case VideoMode.quality:
      VoxelEntity.render_exhaust = true;
      VoxelEntity.frame_skip = 0;
  }
  log_info('video_mode=$video');
  log_info('render_exhaust=${VoxelEntity.render_exhaust}');
  log_info('frame_skip=${VoxelEntity.frame_skip}');
}

set skip_frames(bool value) {
  _skip_frames = value;
  _on_skip_frames_change.forEach((it) => it(value));
}

bool get skip_frames => _skip_frames;

Disposable on_skip_frames_change(Function(bool) hook) {
  _on_skip_frames_change.add(hook);
  return Disposable.wrap(() => _on_skip_frames_change.remove(hook));
}

final _on_skip_frames_change = <Function(bool)>[];

var _skip_frames = true;

set exhaust_anim(bool value) {
  _exhaust_anim = value;
  _on_exhaust_anim_change.forEach((it) => it(value));
}

bool get exhaust_anim => _exhaust_anim;

Disposable on_exhaust_anim_change(Function(bool) listener) {
  _on_exhaust_anim_change.add(listener);
  return Disposable.wrap(() => _on_exhaust_anim_change.remove(listener));
}

final _on_exhaust_anim_change = <Function(bool hook)>[];

var _exhaust_anim = true;

set video(VideoMode value) {
  _video = value;
  _on_video_change.forEach((it) => it(value));
  apply_video_mode();
}

VideoMode get video => _video;

Disposable on_video_change(Function(VideoMode) listener) {
  _on_video_change.add(listener);
  return Disposable.wrap(() => _on_video_change.remove(listener));
}

final _on_video_change = <Function(VideoMode hook)>[];

var _video = VideoMode.balanced;
