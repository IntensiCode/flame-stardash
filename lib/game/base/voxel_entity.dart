import 'dart:math';
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/extensions.dart';
import 'package:stardash/core/common.dart';
import 'package:stardash/util/mutable.dart';
import 'package:stardash/util/pixelate.dart';
import 'package:stardash/util/uniforms.dart';

class VoxelEntity extends Component with HasPaint {
  static final _render_color = Color(0xFFFFFFFF);
  static final _shader_rect = MutRect(0, 0, 0, 0);
  static final _src_rect = MutRect(0, 0, 0, 0);
  static final _dst_rect = MutRect(0, 0, 0, 0);
  static final _paint = pixel_paint();

  static final Matrix4 _scale_matrix = Matrix4.identity();
  static final Matrix4 _transform = Matrix4.identity();
  static final Matrix4 _inverse = Matrix4.identity();

  static Image? _exhaust_buffer;
  static Image? _shader_buffer;

  late final int _frames;
  late final Image _voxel_mage;
  late final Color _exhaust_color;
  late final FragmentShader _shader;
  late final FragmentShader _exhaust_shader;
  late final UniformsExt<Voxel3dUniform> _uniforms;
  late final UniformsExt<ExhaustUniform> _exhaust_uniforms;

  double _exhaust_anim = 0.0;

  var voxel_pixel_size = 128;
  var exhaust_length = 8.0;
  var render_mode = 0.0;

  final model_scale = Vector3.all(1.0);
  final orientation_matrix = Matrix3.identity();
  final light_direction = Vector3(0.5, 0.75, -1.0)..normalize();

  final Vector2 parent_size;

  VoxelEntity({
    required Sprite voxel_image,
    required int height_frames,
    required Color exhaust_color,
    required this.parent_size,
  }) {
    _frames = height_frames;
    _voxel_mage = voxel_image.toImageSync();
    _exhaust_color = exhaust_color;
  }

  void set_exhaust_color(int index, Color color) {
    final first = ExhaustUniform.color0.index;
    _exhaust_uniforms[ExhaustUniform.values[first + index]] = color;
  }

  @override
  Future<void> onLoad() async => await _init_shaders();

  Future<void> _init_shaders() async {
    _shader = await loadShader('voxel3d.frag');
    _exhaust_shader = await loadShader('exhaust.frag');
    _exhaust_shader.setImageSampler(0, _voxel_mage);

    _uniforms = UniformsExt<Voxel3dUniform>(_shader, {
      for (final e in Voxel3dUniform.values) e: e.type,
    });
    _exhaust_uniforms = UniformsExt<ExhaustUniform>(_exhaust_shader, {
      for (final e in ExhaustUniform.values) e: e.type,
    });

    _init_voxel_uniforms();
    _init_exhaust_uniforms();
  }

  void _init_voxel_uniforms() {
    final atlas_size = _voxel_mage.size;
    final frame_size = Vector2(atlas_size.x, atlas_size.y / _frames);
    _uniforms
      ..[Voxel3dUniform.dst_origin] = Vector2.zero()
      ..[Voxel3dUniform.src_origin] = Vector2.zero()
      ..[Voxel3dUniform.atlas_size] = atlas_size
      ..[Voxel3dUniform.frames] = _frames.toDouble()
      ..[Voxel3dUniform.frame_size] = frame_size;
  }

  void _init_exhaust_uniforms() => _exhaust_uniforms
    ..[ExhaustUniform.resolution] = _voxel_mage.size
    ..[ExhaustUniform.target_color] = _exhaust_color
    ..[ExhaustUniform.color_variance] = 0.1
    ..[ExhaustUniform.color0] = const Color(0xFFff0000)
    ..[ExhaustUniform.color1] = const Color(0xFFffff00)
    ..[ExhaustUniform.color2] = const Color(0xFFff0000)
    ..[ExhaustUniform.color3] = const Color(0xFF800000)
    ..[ExhaustUniform.color4] = const Color(0xFF800000);

  @override
  void update(double dt) => _exhaust_anim += dt;

  @override
  void render(Canvas canvas) {
    final size = parent_size;
    voxel_pixel_size = min(size.x, size.y).toInt().clamp(16, 256);
    _src_rect.setSize(voxel_pixel_size * 1.0, voxel_pixel_size * 1.0);

    _renderExhaust();
    _renderVoxelModel();

    _dst_rect.setSize(size.x, size.y);
    _paint.color = _render_color;
    if (paint.color.a < 1.0) {
      _paint.color = _paint.color.withValues(alpha: paint.color.a / 4 + 0.75);
    }
    canvas.drawImageRect(_shader_buffer!, _src_rect, _dst_rect, _paint);
  }

  void _renderExhaust() {
    _exhaust_buffer?.dispose();
    _exhaust_buffer = pixelate(_voxel_mage.width, _voxel_mage.height, (canvas) {
      _exhaust_uniforms[ExhaustUniform.exhaust_length] = exhaust_length;
      _exhaust_uniforms[ExhaustUniform.time] = _exhaust_anim;
      _paint.shader = _exhaust_shader;
      _shader_rect.setFromImage(_voxel_mage);
      canvas.drawRect(_shader_rect, _paint);
      _paint.shader = null;
    });
  }

  void _renderVoxelModel() {
    final img = pixelate(voxel_pixel_size, voxel_pixel_size, (canvas) {
      _updateUniforms(_shader);
      _paint.shader = _shader;
      _shader_rect.setSizeInt(voxel_pixel_size, voxel_pixel_size);
      canvas.drawRect(_shader_rect, _paint);
      _paint.shader = null;
    });

    _shader_buffer?.dispose();
    _shader_buffer = img;
  }

  void _updateUniforms(FragmentShader shader) {
    _scale_matrix.setIdentity();
    _scale_matrix.scale(model_scale);
    _transform.setIdentity();
    _transform.setRotation(orientation_matrix);
    _transform.multiply(_scale_matrix);
    _inverse.copyInverse(_transform);

    _uniforms[Voxel3dUniform.dst_size] = Vector2.all(voxel_pixel_size.toDouble());
    _uniforms[Voxel3dUniform.light_direction] = light_direction;
    _uniforms[Voxel3dUniform.model_matrix_inverse] = _inverse;
    _uniforms[Voxel3dUniform.render_mode] = render_mode;

    _shader.setImageSampler(0, _exhaust_buffer ?? _voxel_mage);
  }
}

enum Voxel3dUniform {
  dst_origin(Vector2),
  dst_size(Vector2),
  src_origin(Vector2),
  atlas_size(Vector2),
  frames(double),
  frame_size(Vector2),
  model_matrix_inverse(Matrix4),
  light_direction(Vector3),
  render_mode(double);

  final Type type;

  const Voxel3dUniform(this.type);
}

enum ExhaustUniform {
  resolution(Vector2),
  time(double),
  target_color(Color),
  color_variance(double),
  exhaust_length(double),
  color0(Color),
  color1(Color),
  color2(Color),
  color3(Color),
  color4(Color);

  final Type type;

  const ExhaustUniform(this.type);
}
