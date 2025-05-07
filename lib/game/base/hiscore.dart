import 'dart:convert';

import 'package:flame/components.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stardash/util/game_data.dart';
import 'package:stardash/util/log.dart';

final hiscore = Hiscore();

int? pending_score;
int? pending_level;

class Hiscore extends Component with HasGameData {
  static const int max_name_length = 10;
  static const int number_of_entries = 10;

  final entries = List.generate(number_of_entries, _default_rank);

  HiscoreRank? latest_rank;

  static HiscoreRank _default_rank(int idx) => HiscoreRank(100000 - idx * 10000, 10 - idx, 'INTENSICODE');

  bool is_new_hiscore(int score) => score > entries.first.score;

  bool is_hiscore_rank(int score) => score > entries.last.score;

  void insert(int score, int level, String name) {
    final rank = HiscoreRank(score, level, name);
    for (int idx = 0; idx < entries.length; idx++) {
      final check = entries[idx];
      if (score <= check.score) continue;
      if (check == rank) break;
      entries.insert(idx, rank);
      entries.removeLast();
      break;
    }
    latest_rank = rank;

    try_store_state();
  }

  // Component

  @override
  onLoad() async => await try_restore_state();

  // HasGameData

  @override
  void load_state(GameData data) {
    entries.clear();

    final it = data['entries'] as List<dynamic>;
    entries.addAll(it.map((it) => HiscoreRank.load(it)));
  }

  @override
  GameData save_state(GameData data) => data..['entries'] = entries.map((it) => it.save_state({})).toList();

  // Implementation

  try_store_state() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      preferences.setString('hiscore', jsonEncode(save_state({})));
    } catch (it, trace) {
      log_error('Failed to store hiscore: $it', trace);
    }
  }

  Future try_restore_state() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      if (preferences.containsKey('hiscore')) {
        final json = preferences.getString('hiscore');
        if (json != null) {
          log_verbose(json);
          load_state(jsonDecode(json));
        }
      }
    } catch (it, trace) {
      log_error('Failed to restore hiscore: $it', trace);
    }
  }
}

class HiscoreRank {
  final int score;
  final int level;
  final String name;

  HiscoreRank(this.score, this.level, this.name);

  HiscoreRank.load(GameData data) : this(data['score'], data['level'], data['name']);

  GameData save_state(GameData data) => data
    ..['score'] = score
    ..['level'] = level
    ..['name'] = name;
}
