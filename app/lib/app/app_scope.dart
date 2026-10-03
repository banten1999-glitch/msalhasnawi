import 'package:flutter/widgets.dart';

import '../core/api/backend_api.dart';
import '../core/auth/auth_controller.dart';
import '../core/sync/data_changes.dart';
import '../core/sync/outbox.dart';

/// يوفّر الخادم وحالة الدخول وقائمة المزامنة لكل الشاشات: `AppScope.of(context).api`.
class AppScope extends InheritedWidget {
  const AppScope({
    super.key,
    required this.api,
    required this.auth,
    required this.outbox,
    required this.changes,
    required super.child,
  });

  final BackendApi api;
  final AuthController auth;

  /// عمليات الشراء والدفعات المحفوظة على الجهاز «بانتظار المزامنة».
  final Outbox outbox;

  /// استدعِ `changes.bump()` بعد كل حفظ ناجح لتتحدث الشاشات المفتوحة.
  final DataChanges changes;

  static AppScope of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'AppScope غير موجود فوق هذه الشاشة');
    return scope!;
  }

  @override
  bool updateShouldNotify(AppScope oldWidget) =>
      api != oldWidget.api || auth != oldWidget.auth || outbox != oldWidget.outbox || changes != oldWidget.changes;
}
