import 'dart:math';
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/extensions.dart';
import 'package:flame/sprite.dart';
import 'package:stardash/core/common.dart';
import 'package:stardash/game/base/has_context.dart';

Stars? _shared_stars;

Stars get shared_stars {
  if (_shared_stars?.parent != null) {
    _shared_stars?.removeFromParent();
  }
  return _shared_stars ??= Stars()..center_offset.setFrom(game_center);
}

extension HasContextExtensions on HasContext {
  Stars get stars => cache.putIfAbsent('stars', () => Stars());
}

class Stars extends Component with HasPaint {
  static const int _num_frames = 10;
  static const double _frame_size = 8;
  static const double _max_sigma = 1.0;

  static final _prerender_paint = Paint();
  static final _render_pos = Vector2(0, 0);

  // Burst configuration
  static const int burst_star_count = 300;
  static const double burst_max_spawn_radius = 0.02;
  static const double burst_z_randomness = 0.1;
  static const double burst_initial_y_offset = 0.0;
  static const double burst_initial_y_velocity = 0.0;
  static const double burst_fountain_strength = 0.0;

  late final SpriteSheet _star_sheet;

  final center_offset = Vector2.zero();
  double base_alpha = 1.0;

  final int star_count;
  final List<_Star> _stars = [];

  Stars({this.star_count = 200});

  @override
  Future<void> onLoad() async {
    for (var i = 0; i < star_count; i++) {
      _stars.add(_Star());
    }
    await _pre_render_star_sheet();
  }

  @override
  void update(double dt) {
    final effective_dt = dt / 2;
    _stars.removeWhere((star) {
      star.update(effective_dt);
      if (star.position.z <= 0) {
        if (star.in_burst) {
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
    super.render(canvas);
    _render_stars(canvas, 1.0);
  }

  void _render_stars(Canvas canvas, double global_alpha) {
    const dark_blue = Color(0xFF4040c0);
    const red = Color(0xFFc04040);
    const white = Color(0xFFffffff);

    for (final star in _stars) {
      // Projection - Calculate screen position only
      final z = star.position.z;
      if (z <= 0.01) continue;
      final perspective_scale = 1.0 / z;
      final screen_x = star.position.x * perspective_scale * game_width + center_offset.x;
      final screen_y = star.position.y * perspective_scale * game_height + center_offset.y;

      final depth_factor = (1.0 - z / _Star.far_plane_z).clamp(0.0, 1.0);
      final star_alpha = depth_factor;
      if (star_alpha < 0.01) continue;

      // Combined alpha
      final base_alpha_local = star.in_burst ? 1.0 : base_alpha;
      final combined_alpha = (star_alpha * global_alpha * base_alpha_local).clamp(0.0, 1.0);
      if (combined_alpha < 0.01) continue;

      // Sprite index based on depth factor
      final sprite_index = (depth_factor * (_num_frames - 1)).round().clamp(0, _num_frames - 1);
      final sprite = _star_sheet.getSpriteById(sprite_index);

      // Apply color transformation or reset paint for rendering
      if (star.in_burst) {
        Color target_color;
        final progress = 1.0 - (z / _Star.far_plane_z).clamp(0.0, 1.0); // 0 (far) to 1 (near)
        if (progress < 0.8 || star.is_centered) {
          target_color = white;
        } else if (progress < 0.9) {
          target_color = red;
        } else {
          target_color = dark_blue;
        }
        // Apply ColorFilter to replace sprite color
        paint.colorFilter = ColorFilter.mode(target_color, BlendMode.srcIn);
        // Use white paint with combined alpha for final opacity
        var dist_alpha = (1 - star.position.z * 3 / _Star.far_plane_z);
        final _render_color = white.withValues(alpha: combined_alpha * dist_alpha.clamp(0, 1));
        paint.color = _render_color;
      } else {
        // Regular stars: No color filter, just white with combined alpha
        final _render_color = white.withValues(alpha: combined_alpha);
        paint.color = _render_color;
        paint.colorFilter = null;
      }

      // Render using the configured paint
      _render_pos.setValues(screen_x, screen_y);
      sprite.render(canvas, position: _render_pos, anchor: Anchor.center, overridePaint: paint);
    }

    // Reset color filter after rendering all stars
    paint.colorFilter = null;
  }

  Future<void> _pre_render_star_sheet() async {
    final recorder = PictureRecorder();
    final canvas = Canvas(recorder);
    final sheet_width = _frame_size * _num_frames;
    final sheet_height = _frame_size;

    _prerender_paint.style = PaintingStyle.fill;

    for (var i = 0; i < _num_frames; i++) {
      final depth_factor = i / (_num_frames - 1); // 0.0 to 1.0

      final sigma = _max_sigma * depth_factor;
      _prerender_paint.maskFilter = (sigma > 0.01) ? MaskFilter.blur(BlurStyle.normal, sigma) : null;

      final frame_x = i * _frame_size;
      final center_x = frame_x + _frame_size / 2;
      final center_y = _frame_size / 2;
      final offset = Offset(center_x, center_y);

      // Calculate radii based on depth
      final max_radius = _frame_size / 2 * 0.8; // Max outer radius
      final outer_radius = max_radius * (0.2 + 0.8 * depth_factor); // Scale from 20% to 100%
      final inner_radius = outer_radius * 0.5; // Inner white radius is half the outer

      // Draw outer yellow circle
      _prerender_paint.color = const Color(0xAAFFFF60); // Semi-transparent Yellow
      canvas.drawCircle(offset, outer_radius, _prerender_paint);

      // Draw inner white circle
      _prerender_paint.color = const Color(0xDDFFFFFF); // Semi-transparent White
      canvas.drawCircle(offset, inner_radius, _prerender_paint);
    }

    final picture = recorder.endRecording();
    final image = await picture.toImage(sheet_width.toInt(), sheet_height.toInt());
    _star_sheet = SpriteSheet.fromColumnsAndRows(image: image, columns: _num_frames, rows: 1);
    _prerender_paint.maskFilter = null;
  }

  void burst() {
    for (var i = 0; i < burst_star_count; i++) {
      _stars.add(_Star.burst(i * 1.0 / burst_star_count / 2));
    }
  }
}

class _Star {
  static const far_plane_z = 3.0;

  final Vector3 position = Vector3.zero();
  final Vector3 velocity = Vector3.zero();
  bool in_burst = false;
  double wait = 0.0;

  /// sqrt(x^2 + y^2) tiny
  bool get is_centered => position.x * position.x + position.y * position.y < 0.0006;

  _Star() {
    reset();
    position.z = random.nextDouble() * far_plane_z;
  }

  _Star.burst(this.wait) {
    in_burst = true;
    // Spawn logic for burst stars
    final radius = random.nextDouble() * Stars.burst_max_spawn_radius; // 0 to max radius
    final angle = random.nextDouble() * tau;
    final z = far_plane_z * 2 / 3 - random.nextDouble() * Stars.burst_z_randomness; // Near far plane
    final initial_x = cos(angle) * radius;
    final initial_y = sin(angle) * radius - Stars.burst_initial_y_offset; // Apply Y offset

    position.setValues(initial_x, initial_y, z);

    // Use similar velocity logic as reset for now
    const base_speed = 0.8;
    velocity.setValues(
      initial_x * base_speed * 0.5, // Keep X velocity calculation
      initial_y * base_speed * 0.5 + Stars.burst_initial_y_velocity, // Add initial Y velocity
      -base_speed * 1.5, // Slightly faster maybe?
    );
  }

  void reset() {
    // Define spawn radius bounds
    const double min_spawn_radius = 0.05; // Increase minimum slightly
    const double max_spawn_radius = 0.4; // Increase maximum significantly

    // Generate radius within the allowed range
    final radius_range = max_spawn_radius - min_spawn_radius;
    final radius = min_spawn_radius + random.nextDouble() * radius_range;

    // Generate random angle
    final angle = random.nextDouble() * tau;

    // Set Z position: far plane to near plane
    final z = 0.05 * random.nextDouble() + far_plane_z;

    // Set position: Use calculated radius/angle, but set Z much further back
    position.setValues(cos(angle) * radius, sin(angle) * radius, z);

    // Set velocity: constant speed towards viewer, slight outward drift
    const base_speed = 0.2; // Z units per second
    velocity.setValues(
      position.x * base_speed * 0.5, // Move slightly outwards
      position.y * base_speed * 0.5,
      -base_speed,
    );
  }

  void update(double dt) {
    if (wait > 0) {
      wait -= dt;
      return;
    }
    position.addScaled(velocity, dt);
    if (in_burst) {
      // Spread effect
      position.x *= 1.005;
      position.y *= 1.005;

      // Fountain effect: Push upwards more as the star gets closer (z decreases)
      if (position.z > 0) {
        // Avoid division by zero or invalid ops if z=0
        position.y -= (position.z / far_plane_z) * Stars.burst_fountain_strength * dt;
      }
    }
  }
}

// Helper for random numbers
final random = Random();
const tau = pi * 2;
