import '../core/common.dart';
import 'auto_dispose.dart';
import 'messaging.dart';

extension AutoDisposeComponentExtensions on AutoDispose {
  void on_message<T extends Message>(void Function(T) callback) {
    auto_dispose('listen-$T', messaging.listen<T>(callback));
  }
}
