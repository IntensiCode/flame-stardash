import 'dart:math';
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:stardash/core/common.dart';
import 'package:stardash/game/base/voxel_entity.dart';
import 'package:stardash/game/enemies/shader_pulsar.dart';
import 'package:stardash/game/enemies/voxel_flipper.dart';
import 'package:stardash/game/enemies/voxel_spiker.dart';
import 'package:stardash/game/enemies/voxel_tanker.dart';
import 'package:stardash/game/player/player.dart';
import 'package:stardash/title/title_fuseball.dart';
import 'package:stardash/title/title_pulsar.dart';
import 'package:stardash/util/vector_text.dart';

final title_models = <VoxelEntity>[];

List<Future<Component>> TitleEntities() => [
      _voxel(
        image: 'voxel/flipper16.png',
        frames: 16,
        x: 100,
        scale: Vector3(0.7, 0.25, 0.7),
        name: 'Flipper',
        type: VoxelFlipper,
      ),
      _voxel(
        image: 'voxel/tanker50.png',
        frames: 50,
        x: 200,
        scale: Vector3(0.8, 0.8, 0.8),
        name: 'Tanker',
        type: VoxelTanker,
      ),
      _voxel(
        image: 'voxel/spiker20.png',
        frames: 20,
        x: 300,
        scale: Vector3(0.6, 0.4, 0.8),
        name: 'Spiker',
        type: VoxelSpiker,
      ),
      _column(enemy: TitlePulsar(), x: 400, name: 'Pulsar', type: ShaderPulsar),
      _column(enemy: TitleFuseball(), x: 500, name: 'Fuseball', type: ShaderPulsar),
      _voxel(
        image: 'voxel/manta19.png',
        frames: 19,
        x: 700,
        scale: Vector3(0.8, 0.3, 0.8),
        name: 'Manta Zapper',
        type: Player,
      ),
    ];

Future<Component> _voxel({
  required String image,
  required int frames,
  required double x,
  required Vector3 scale,
  required String name,
  required Type type,
}) async {
  final voxel = VoxelEntity(
    voxel_image: await images.load(image),
    height_frames: frames,
    exhaust_color: const Color(0xFF00FF80),
    exhaust_color_variance: 0.0,
    parent_size: Vector2.all(64),
  );
  voxel.orientation_matrix.setRotationX(-pi / 12);
  voxel.model_scale.setFrom(scale);
  voxel.exhaust_length = 2;
  title_models.add(voxel);

  final column = PositionComponent(
    position: Vector2(x, game_height / 2),
    size: Vector2(64, 110),
    anchor: Anchor.center,
  );
  column.add(voxel);

  column.add(VectorText(
    text: name,
    anchor: Anchor.center,
    position: Vector2(32, 80),
    scale: 1.0,
  ));
  if (enemy_score(type) > 0) {
    column.add(VectorText(
      text: enemy_score(type).toString(),
      anchor: Anchor.center,
      position: Vector2(32, 100),
      scale: 1.0,
    ));
  }

  return column;
}

Future<Component> _column({
  required PositionComponent enemy,
  required double x,
  required String name,
  required Type type,
}) async {
  final column = PositionComponent(
    position: Vector2(x, game_height / 2),
    size: Vector2(64, 110),
    anchor: Anchor.center,
  );

  enemy.size.setAll(64);
  column.add(enemy);

  column.add(VectorText(
    text: name,
    anchor: Anchor.center,
    position: Vector2(32, 80),
    scale: 1.0,
  ));
  if (enemy_score(type) > 0) {
    column.add(VectorText(
      text: enemy_score(type).toString(),
      anchor: Anchor.center,
      position: Vector2(32, 100),
      scale: 1.0,
    ));
  }

  return column;
}
