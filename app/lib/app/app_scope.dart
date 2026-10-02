import 'package:flutter/widgets.dart';

import '../core/api/backend_api.dart';
import '../core/auth/auth_controller.dart';

/// يوفّر الخادم وحالة الدخول لكل الشاشات: `AppScope.of(context).api`.
class AppScope extends InheritedWidget {
  const AppScope({super.key, required this.api, required this.auth, required super.child});

  final BackendApi api;
  final AuthController auth;

  static AppScope of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'AppScope غير موجود فوق هذه الشاشة');
    return scope!;
  }

  @override
  bool updateShouldNotify(AppScope oldWidget) => api != oldWidget.api || auth != oldWidget.auth;
}
