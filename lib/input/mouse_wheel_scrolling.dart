import 'package:stardash/core/common.dart';
import 'package:stardash/util/auto_dispose.dart';
import 'package:stardash/util/on_message.dart';

mixin MouseWheelScrolling on AutoDisposeComponent {
  void onDragSteps(int steps);

  @override
  void onMount() {
    super.onMount();
    on_message<MouseWheel>((it) {
      onDragSteps(it.direction.toInt());
    });
  }
}
