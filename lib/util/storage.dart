import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:stardash/core/common.dart';
import 'package:stardash/util/game_data.dart';
import 'package:stardash/util/log.dart';

final _prefs = SharedPreferences.getInstance();

late String storage_prefix;

extension on String {
  String get key => '${storage_prefix}_$this';
}

Future clear_storage_entry(String name) async {
  final preferences = await _prefs;
  preferences.remove(name.key);
  log_verbose('cleared $name data');
}

Future save_to_storage(String name, HasGameData it) async => save_data(name, it.save_state({}));

Future load_from_storage(String name, HasGameData it) async {
  final data = await load_data(name);
  if (data != null) it.load_state(data);
}

Future save_data(String name, GameData data) async {
  try {
    final preferences = await _prefs;
    final json = jsonEncode(data);
    if (dev) log_info(json);
    preferences.setString(name.key, json);
    log_verbose('saved $name data');
  } catch (it, trace) {
    log_error('Failed to store $data in $name: $it', trace);
  }
}

Future<GameData?> load_data(String name) async {
  try {
    final preferences = await _prefs;
    if (!preferences.containsKey(name.key)) {
      log_verbose('no data for $name');
      return null;
    }

    final json = preferences.getString(name.key);
    if (json == null) {
      log_error('invalid data for $name');
      return null;
    }

    log_info('loaded $name');
    log_verbose(json);
    return jsonDecode(json);
  } catch (it, trace) {
    log_error('Failed to restore $name: $it', trace);
    return null;
  }
}
