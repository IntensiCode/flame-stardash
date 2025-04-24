import 'dart:math';
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/extensions.dart';
import 'package:flame/sprite.dart';
import 'package:stardash/core/common.dart';
import 'package:stardash/game/base/has_context.dart';
import 'package:stardash/util/mutable.dart';

Stars? _sharedStars;

Stars get sharedStars {
  if (_sharedStars?.parent != null) {
    _sharedStars?.removeFromParent();
  }
  return _sharedStars ??= Stars()..centerOffset.setFrom(game_center);
}

extension HasContextExtensions on HasContext {
  Stars get stars => cache.putIfAbsent('stars', () => Stars());
}

class Stars extends Component with HasPaint {
  static const int _numFrames = 10;
  static const double _frameSize = 8;
  static const double _maxSigma = 1.0;

  static final Paint _prerenderPaint = Paint();
  static final _renderPos = Vector2(0, 0);
  static final _renderColor = MutColor(0);

  // Burst configuration
  static const int burstStarCount = 300;
  static const double burstMaxSpawnRadius = 0.02;
  static const double burstZRandomness = 0.1;
  static const double burstInitialYOffset = 0.0;
  static const double burstInitialYVelocity = 0.0;
  static const double burstFountainStrength = 0.0;

  late final SpriteSheet _starSheet;

  final centerOffset = Vector2.zero();
  double base_alpha = 1.0;

  final int starCount;
  final List<_Star> _stars = [];

  Stars({this.starCount = 200});

  @override
  Future<void> onLoad() async {
    for (var i = 0; i < starCount; i++) {
      _stars.add(_Star());
    }
    await _preRenderStarSheet();
  }

  @override
  void update(double dt) {
    final effectiveDt = dt / 2;
    _stars.removeWhere((star) {
      star.update(effectiveDt);
      if (star.position.z <= 0) {
        if (star.inBurst) {
          return true; // Remove single run star
        } else {
          star.reset(); // Reset normal star
        }
      }
      return false; // Keep star
    });
  }

  @override
  void render(Canvas canvas) {
    final saved = paint.color;
    _renderStars(canvas, saved.a);
    paint.color = saved;
  }

  void _renderStars(Canvas canvas, double globalAlpha) {
    const darkBlue = Color(0xFF4040c0);
    const red = Color(0xFFc04040);
    const white = Color(0xFFffffff);

    for (final star in _stars) {
      // Projection - Calculate screen position only
      final z = star.position.z;
      if (z <= 0.01) continue;
      final perspectiveScale = 1.0 / z;
      final screenX = star.position.x * perspectiveScale * game_width + centerOffset.x;
      final screenY = star.position.y * perspectiveScale * game_height + centerOffset.y;

      final depthFactor = (1.0 - z / _Star.farPlaneZ).clamp(0.0, 1.0);
      final starAlpha = depthFactor;
      if (starAlpha < 0.01) continue;

      // Combined alpha
      final ba = star.inBurst ? 1.0 : base_alpha;
      final combinedAlpha = (starAlpha * globalAlpha * ba).clamp(0.0, 1.0);
      if (combinedAlpha < 0.01) continue;

      // Sprite index based on depth factor
      final spriteIndex = (depthFactor * (_numFrames - 1)).round().clamp(0, _numFrames - 1);
      final sprite = _starSheet.getSpriteById(spriteIndex);

      // Apply color transformation or reset paint for rendering
      if (star.inBurst) {
        Color targetColor;
        final p = 1.0 - (z / _Star.farPlaneZ).clamp(0.0, 1.0); // 0 (far) to 1 (near)
        if (p < 0.8 || star.isCentered) {
          targetColor = white;
        } else if (p < 0.9) {
          targetColor = red;
        } else {
          targetColor = darkBlue;
        }
        // Apply ColorFilter to replace sprite color
        paint.colorFilter = ColorFilter.mode(targetColor, BlendMode.srcIn);
        // Use white paint with combined alpha for final opacity
        _renderColor.setFrom(white);
        _renderColor.a = combinedAlpha * (1 - star.position.z * 3 / _Star.farPlaneZ).clamp(0,1);
        paint.color = _renderColor;
      } else {
        // Regular stars: No color filter, just white with combined alpha
        _renderColor.setFrom(white);
        _renderColor.a = combinedAlpha;
        paint.color = _renderColor;
        paint.colorFilter = null;
      }

      // Render using the configured paint
      _renderPos.setValues(screenX, screenY);
      sprite.render(canvas, position: _renderPos, anchor: Anchor.center, overridePaint: paint);
    }

    // Reset color filter after rendering all stars
    paint.colorFilter = null;
  }

  Future<void> _preRenderStarSheet() async {
    final recorder = PictureRecorder();
    final canvas = Canvas(recorder);
    final sheetWidth = _frameSize * _numFrames;
    final sheetHeight = _frameSize;

    _prerenderPaint.style = PaintingStyle.fill;

    for (var i = 0; i < _numFrames; i++) {
      final depthFactor = i / (_numFrames - 1); // 0.0 to 1.0

      final sigma = _maxSigma * depthFactor;
      _prerenderPaint.maskFilter = (sigma > 0.01) ? MaskFilter.blur(BlurStyle.normal, sigma) : null;

      final frameX = i * _frameSize;
      final centerX = frameX + _frameSize / 2;
      final centerY = _frameSize / 2;
      final offset = Offset(centerX, centerY);

      // Calculate radii based on depth
      final maxRadius = _frameSize / 2 * 0.8; // Max outer radius
      final outerRadius = maxRadius * (0.2 + 0.8 * depthFactor); // Scale from 20% to 100%
      final innerRadius = outerRadius * 0.5; // Inner white radius is half the outer

      // Draw outer yellow circle
      _prerenderPaint.color = const Color(0xAAFFFF60); // Semi-transparent Yellow
      canvas.drawCircle(offset, outerRadius, _prerenderPaint);

      // Draw inner white circle
      _prerenderPaint.color = const Color(0xDDFFFFFF); // Semi-transparent White
      canvas.drawCircle(offset, innerRadius, _prerenderPaint);
    }

    final picture = recorder.endRecording();
    final image = await picture.toImage(sheetWidth.toInt(), sheetHeight.toInt());
    _starSheet = SpriteSheet.fromColumnsAndRows(image: image, columns: _numFrames, rows: 1);
    _prerenderPaint.maskFilter = null;
  }

  void burst() {
    for (var i = 0; i < burstStarCount; i++) {
      _stars.add(_Star.burst(i * 1.0 / burstStarCount / 2));
    }
  }
}

class _Star {
  static const farPlaneZ = 3.0;

  final Vector3 position = Vector3.zero();
  final Vector3 velocity = Vector3.zero();
  bool inBurst = false;
  double wait = 0.0;

  /// sqrt(x^2 + y^2) tiny
  bool get isCentered => position.x * position.x + position.y * position.y < 0.0006;

  _Star() {
    reset();
    position.z = random.nextDouble() * farPlaneZ;
  }

  _Star.burst(this.wait) {
    inBurst = true;
    // Spawn logic for burst stars
    final radius = random.nextDouble() * Stars.burstMaxSpawnRadius; // 0 to max radius
    final angle = random.nextDouble() * tau;
    final z = farPlaneZ * 2 / 3 - random.nextDouble() * Stars.burstZRandomness; // Near far plane
    final initialX = cos(angle) * radius;
    final initialY = sin(angle) * radius - Stars.burstInitialYOffset; // Apply Y offset

    position.setValues(initialX, initialY, z);

    // Use similar velocity logic as reset for now
    const baseSpeed = 0.8;
    velocity.setValues(
      initialX * baseSpeed * 0.5, // Keep X velocity calculation
      initialY * baseSpeed * 0.5 + Stars.burstInitialYVelocity, // Add initial Y velocity
      -baseSpeed * 1.5, // Slightly faster maybe?
    );
  }

  void reset() {
    // Define spawn radius bounds
    const double minSpawnRadius = 0.05; // Increase minimum slightly
    const double maxSpawnRadius = 0.4; // Increase maximum significantly

    // Generate radius within the allowed range
    final radiusRange = maxSpawnRadius - minSpawnRadius;
    final radius = minSpawnRadius + random.nextDouble() * radiusRange;

    // Generate random angle
    final angle = random.nextDouble() * tau;

    // Set Z position: far plane to near plane
    final z = 0.05 * random.nextDouble() + farPlaneZ;

    // Set position: Use calculated radius/angle, but set Z much further back
    position.setValues(cos(angle) * radius, sin(angle) * radius, z);

    // Set velocity: constant speed towards viewer, slight outward drift
    const baseSpeed = 0.2; // Z units per second
    velocity.setValues(
      position.x * baseSpeed * 0.5, // Move slightly outwards
      position.y * baseSpeed * 0.5,
      -baseSpeed,
    );
  }

  void update(double dt) {
    if (wait > 0) {
      wait -= dt;
      return;
    }
    position.addScaled(velocity, dt);
    if (inBurst) {
      // Spread effect
      position.x *= 1.005;
      position.y *= 1.005;

      // Fountain effect: Push upwards more as the star gets closer (z decreases)
      if (position.z > 0) {
        // Avoid division by zero or invalid ops if z=0
        position.y -= (position.z / farPlaneZ) * Stars.burstFountainStrength * dt;
      }
    }
  }
}

// Helper for random numbers
final random = Random();
const tau = pi * 2;
