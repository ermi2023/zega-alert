import 'package:flutter/foundation.dart';

class NotificationState {
  static final ValueNotifier<int> changes = ValueNotifier<int>(0);

  static void notifyChanged() {
    changes.value++;
  }
}
