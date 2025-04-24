enum GamePhase {
  entering_level,
  playing_level,
  level_complete,
  leaving_level,
  game_over,
  ;

  static GamePhase from(final String name) => GamePhase.values.firstWhere((e) => e.name == name);
}
