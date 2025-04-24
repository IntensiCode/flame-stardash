import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:stardash/util/mutable.dart'; // Needed for Color, lerpDouble

enum _FlashState { Idle, Delayed, FadingIn, Holding, FadingOut }

class LevelTile extends PositionComponent {
  final _color = MutColor(0);

  final Paint sharedPaint;
  final Vector2 p1, p2, p3, p4;

  late final Vertices _vertices;

  // Flashing state
  _FlashState _flashState = _FlashState.Idle;
  double _flashTimer = 0.0;
  double _startDelay = 0.0;
  Color _flashBaseColor = Colors.transparent;
  double _fadeInDuration = 0.05;
  double _holdDuration = 0.2;
  double _fadeOutDuration = 0.5;
  double _maxFlashAlpha = 0.8; // Maximum opacity during flash

  LevelTile({
    required this.sharedPaint,
    required this.p1,
    required this.p2,
    required this.p3,
    required this.p4,
  }) : super(position: Vector2.zero(), size: Vector2.zero()) {
    _vertices = Vertices(
      VertexMode.triangleFan,
      [p1.toOffset(), p2.toOffset(), p3.toOffset(), p4.toOffset()],
    );
    final avgY = (p1.y + p2.y + p3.y + p4.y) / 4.0;
    priority = -avgY.round();
  }

  /// Starts the flash effect.
  /// [baseColor] is the target color (alpha will be animated).
  void flash(
    Color baseColor, {
    double fadeIn = 0.1,
    double hold = 0.2,
    double fadeOut = 0.4,
    double maxAlpha = 0.5,
    double startDelay = 0.0,
  }) {
    _flashBaseColor = baseColor;
    _fadeInDuration = fadeIn;
    _holdDuration = hold;
    _fadeOutDuration = fadeOut;
    _maxFlashAlpha = maxAlpha.clamp(0.0, 1.0);
    _startDelay = startDelay;
    _flashTimer = 0.0;

    if (_startDelay > 0) {
      _flashState = _FlashState.Delayed;
    } else {
      _flashState = _FlashState.FadingIn;
    }
    _color.setFrom(_flashBaseColor);
    _color.a = 0;
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (_flashState == _FlashState.Idle) return;

    _flashTimer += dt;
    double alpha = 0.0;

    switch (_flashState) {
      case _FlashState.Delayed:
        if (_flashTimer >= _startDelay) {
          _flashState = _FlashState.FadingIn;
          _flashTimer = 0.0;
        }
        alpha = 0.0;
        break;
      case _FlashState.FadingIn:
        final t = (_flashTimer / _fadeInDuration).clamp(0.0, 1.0);
        alpha = lerpDouble(0, _maxFlashAlpha, t)!;
        if (_flashTimer >= _fadeInDuration) {
          _flashState = _FlashState.Holding;
          _flashTimer = 0.0;
        }
        break;
      case _FlashState.Holding:
        alpha = _maxFlashAlpha;
        if (_flashTimer >= _holdDuration) {
          _flashState = _FlashState.FadingOut;
          _flashTimer = 0.0;
        }
        break;
      case _FlashState.FadingOut:
        final t = (_flashTimer / _fadeOutDuration).clamp(0.0, 1.0);
        alpha = lerpDouble(_maxFlashAlpha, 0, t)!;
        if (_flashTimer >= _fadeOutDuration) {
          _flashState = _FlashState.Idle;
          _flashTimer = 0.0;
        }
        break;
      case _FlashState.Idle:
        break;
    }

    if (_flashState != _FlashState.Delayed) {
      _color.a = alpha;
    }
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    if (_color.a <= 0) return;

    final saved = sharedPaint.color;

    // Handle global fade:
    if (sharedPaint.color.a < 1.0) {
      sharedPaint.color = _color.withValues(alpha: saved.a * _color.a);
      canvas.drawVertices(_vertices, BlendMode.srcOver, sharedPaint);
    } else {
      sharedPaint.color = _color;
      canvas.drawVertices(_vertices, BlendMode.srcOver, sharedPaint);
    }
    sharedPaint.color = saved;
  }
}
