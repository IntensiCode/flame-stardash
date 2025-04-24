import 'package:collection/collection.dart';
import 'package:dart_extensions_methods/dart_extension_methods.dart';
import 'package:kart/kart.dart';
import 'package:stardash/core/common.dart';
import 'package:stardash/input/game_keys.dart';
import 'package:stardash/input/game_pads.dart';
import 'package:stardash/util/extensions.dart';
import 'package:stardash/util/game_data.dart';
import 'package:stardash/util/log.dart';
import 'package:stardash/util/storage.dart' as storage;
import 'package:supercharged/supercharged.dart';

final configuration = Configuration._();

class Configuration with HasGameData {
  Configuration._() {
    on_debug_change = (it) => _save_if(_data['debug'] != it);
  }

  bool _loading = false;

  void _save_if(bool changed) {
    if (_loading) return;
    if (changed) storage.save_to_storage('configuration', this);
  }

  Future<void> load() async {
    await storage.load_from_storage('configuration', this);
    log_verbose(known_hw_mappings.entries.firstWhereOrNull((it) => it.value.deepEquals(hw_mapping))?.key ?? 'CUSTOM');
  }

  void save() => storage.save_to_storage('configuration', this);

  // HasGameData

  var _data = <String, dynamic>{};

  @override
  void load_state(Map<String, dynamic> data) {
    try {
      _loading = true;
      _load_state(data);
    } catch (it, trace) {
      log_error('Failed to load configuration: $it', trace);
    } finally {
      _loading = false;
    }
  }

  void _load_state(Map<String, dynamic> data) {
    _data = data;
    if (dev) log_verbose(data);
    debug = data['debug'] ?? debug;
    prefer_x_over_y = data['prefer_x_over_y'] ?? prefer_x_over_y;
    hw_mapping = (data['hw_mapping'] as Map<String, dynamic>? ?? {}).entries.mapNotNull((e) {
      final k = e?.key.toIntOrNull();
      if (k == null) return null;
      final v = GamePadControl.values.firstWhereOrNull((it) => it.name == e?.value);
      if (v == null) return null;
      return MapEntry(k, v);
    }).toMap();
  }

  @override
  GameData save_state(Map<String, dynamic> data) => data
    ..['debug'] = debug
    ..['prefer_x_over_y'] = prefer_x_over_y
    ..['hw_mapping'] = hw_mapping.map((k, v) => MapEntry(k.toString(), v.name));
}
