import 'package:flutter/foundation.dart';

/// إشارة «تغيّرت البيانات»: كل شاشة تحفظ شيئًا تستدعي [bump]، والشاشات المفتوحة (لوحة التحكم، القوائم،
/// تفاصيل البراد) تستمع وتعيد التحميل. تُستدعى أيضًا بعد إرسال عملية من قائمة «بانتظار المزامنة».
class DataChanges extends ChangeNotifier {
  int _revision = 0;

  int get revision => _revision;

  void bump() {
    _revision++;
    notifyListeners();
  }
}
