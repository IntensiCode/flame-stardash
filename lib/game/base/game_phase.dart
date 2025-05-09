enum GamePhase {
  entering_level,
  playing_level,
  live_lost,
  level_completed,
  leaving_level,
  game_over,
  ;

  static GamePhase from(final String name) => GamePhase.values.firstWhere((e) => e.name == name);
}
