import 'dart:math';

import 'package:flame/components.dart';

final shared_rng = Random();

Vector2 randomNormalizedVector2() => Vector2(shared_rng.nextDoublePM(1), shared_rng.nextDoublePM(1))..normalize();

extension RandomExtensions on Random {
  double nextDoubleLimit(double limit) => nextDouble() * limit;

  double nextDoublePM(double limit) => (nextDouble() - nextDouble()) * limit;
}

extension Vector2Extensions on Vector2 {
  void randomizedNormal() {
    setValues(shared_rng.nextDoublePM(1), shared_rng.nextDoublePM(1));
    normalize();
  }
}
