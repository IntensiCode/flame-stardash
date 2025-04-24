import 'package:flame/game.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:stardash/main_game.dart';
import 'package:stardash/util/log.dart';
import 'package:stardash/util/storage.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  log_level = kDebugMode ? LogLevel.debug : LogLevel.none;
  storage_prefix = 'stardash';
  final game = MainGame();
  final widget = GameWidget(game: game);
  if (kDebugMode) {
    log_verbose('Adding debug listener for right-click panning and zooming');
    runApp(_wrapListener(widget, game, widget));
  } else {
    runApp(widget);
  }
}

Widget _wrapListener(Widget rootWidget, MainGame game, GameWidget<MainGame> gameWidget) {
  rootWidget = Listener(
    onPointerMove: (event) {
      if (event.buttons == kPrimaryMouseButton) {
        return;
      }
      _updatePan(event, game);
    },
    onPointerSignal: (event) {
      if (event is PointerScrollEvent) {
        _updateZoom(event, game);
      }
    },
    child: gameWidget,
  );
  return rootWidget;
}

void _updatePan(PointerMoveEvent event, MainGame game) {
  final camera = game.camera;
  if (camera.isMounted) {
    final screenDelta = Vector2(event.delta.dx, event.delta.dy);
    final adjustment = screenDelta / camera.viewfinder.zoom;
    camera.viewfinder.position -= adjustment;
  }
}

void _updateZoom(PointerScrollEvent event, MainGame game) {
  final camera = game.camera;
  if (!camera.isMounted) return;

  final direction = event.scrollDelta.dy.sign;
  if (direction == 0) return;

  const baseZoomFactor = 0.1; // Adjust sensitivity as needed
  final currentZoom = camera.viewfinder.zoom;
  // Make the zoom step proportional to the current zoom level
  final zoomStep = currentZoom * baseZoomFactor;
  final newZoom = (currentZoom - direction * zoomStep).clamp(0.1, 5.0);

  if (newZoom == currentZoom) return;

  // Zoom towards cursor position
  // final pos = event.position.toVector2();
  // final worldPos = camera.globalToLocal(pos);
  final cameraPos = camera.viewfinder.position;
  // final zoomRatio = currentZoom / newZoom;
  // final adjustment = (worldPos - cameraPos) * (1 - zoomRatio);

  camera.viewfinder.zoom = newZoom;
  camera.viewfinder.position = cameraPos;
}
