import 'dart:async';

import 'package:flame/components.dart';
import 'package:flutter/foundation.dart';
import 'package:stardash/core/common.dart';
import 'package:stardash/game/base/messages.dart';
import 'package:stardash/util/effects.dart';
import 'package:stardash/util/extensions.dart';
import 'package:stardash/util/game_script.dart';
import 'package:stardash/util/messaging.dart';
import 'package:stardash/util/on_message.dart';
import 'package:stardash/util/vector_text.dart';

extension ComponentExtensions on Component {
  void show_info(
    String text, {
    String? title,
    bool blink = true,
    bool hud = false,
    bool longer = false,
    Function? done,
  }) {
    send_message(ShowInfoText(
      title: title,
      text: text,
      blink_text: blink,
      hud_align: hud,
      stay_longer: longer,
      when_done: done,
    ));
  }
}

class InfoOverlay extends GameScriptComponent {
  InfoOverlay(this._time_scale) {
    add(_info = _InfoOverlay(quick: dev));
    add(_hud = _InfoOverlay(pos_y: 480 - 32, quick: true));
    add(_cheat = _InfoOverlay(pos_y: 480 - 16, quick: true));
    priority = 9000;
  }

  final double Function() _time_scale;

  late _InfoOverlay _info;
  late _InfoOverlay _hud;
  late _InfoOverlay _cheat;

  @override
  void onMount() {
    super.onMount();
    on_message<ShowInfoText>((it) {
      if (it.title == 'Cheat') {
        _cheat.pipe.add(it..title = null);
      } else {
        final target = it.hud_align ? _hud : _info;
        target.pipe.add(it);
      }
    });
  }

  @override
  void updateTree(double dt) {
    super.updateTree(dt / _time_scale());
  }
}

class _InfoOverlay extends GameScriptComponent {
  _InfoOverlay({this.pos_y = game_height / 4, this.quick = false});

  final pipe = <ShowInfoText>[];

  final double pos_y;
  final bool quick;

  Future? _active;

  late final VectorText _title_text;
  late final VectorText _text;

  @override
  onLoad() {
    _title_text = added(vectorTextXY('', game_width / 2, pos_y - 15, scale: 2)..isVisible = false);
    _text = added(vectorTextXY('', game_width / 2, pos_y + 5)..isVisible = false);
  }

  @override
  void update(double dt) {
    super.update(dt);

    if (_active != null || pipe.isEmpty) return;

    final it = pipe.first;

    script_clear();

    script_after(0.0, () {
      _title_text.isVisible = it.title != null;
      _title_text.change_text_in_place(it.title ?? '');
      if (it.title != null) _title_text.fadeInDeep();

      _text.isVisible = true;
      _text.change_text_in_place(it.text);
      _text.fadeInDeep();
    });
    if (kReleaseMode && it.stay_longer) script_after(2, () {});
    if (pipe.length > 3) {
      script_after(0.4, () => _text.fadeOutDeep(and_remove: false));
      script_after(0.0, () {
        if (it.title != null) _title_text.fadeOutDeep(and_remove: false);
      });
      script_after(0.4, () => it.when_done?.call());
    } else {
      script_after(quick ? 0.2 : 0.4, () {
        if (it.blink_text) _text.add(BlinkEffect(on: 0.35, off: 0.15));
      });
      script_after(quick ? 0.9 : 1.8, () => _text.removeAll(_text.children)); // remove blink?
      if (pipe.length == 1) {
        script_after(quick ? 0.0 : 1.0, () => _text.fadeOutDeep(and_remove: false));
        script_after(0.0, () {
          if (it.title != null) _title_text.fadeOutDeep(and_remove: false);
        });
        script_after(quick ? 0.2 : 0.5, () => it.when_done?.call());
      } else {
        script_after(0.0, () => it.when_done?.call());
      }
    }

    final active = _active = script_execute();
    _active?.then((_) {
      pipe.removeAt(0);
      if (_active == active) _active = null;
    });
  }
}
