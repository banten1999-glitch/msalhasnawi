import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api/api_exception.dart';
import '../api/backend_api.dart';

/// الإجراءات التي تُحفظ في قائمة «بانتظار المزامنة» عند انقطاع الاتصال.
///
/// كلها آمنة لإعادة الإرسال: الخادم يتعرّف على requestId (docs/API.md §7) فلا يتكرر السجل.
const outboxActions = {'purchases.create', 'payments.create'};

/// عملية حُفظت على الجهاز ولم تصل إلى الملف المركزي بعد.
@immutable
class OutboxEntry {
  const OutboxEntry({
    required this.requestId,
    required this.action,
    required this.payload,
    required this.label,
    required this.createdAt,
    this.coolerId,
    this.attempts = 0,
    this.lastError,
    this.errorCode,
    this.blocked = false,
  });

  factory OutboxEntry.fromJson(Map<String, dynamic> j) => OutboxEntry(
        requestId: j['requestId'] as String,
        action: j['action'] as String,
        payload: (j['payload'] as Map).cast<String, dynamic>(),
        label: j['label'] as String? ?? '',
        createdAt: j['createdAt'] as String? ?? '',
        coolerId: j['coolerId'] as String?,
        attempts: (j['attempts'] as num?)?.toInt() ?? 0,
        lastError: j['lastError'] as String?,
        errorCode: j['errorCode'] as String?,
        blocked: j['blocked'] == true,
      );

  /// يُرسل نفسه في كل محاولة.
  final String requestId;
  final String action;
  final Map<String, dynamic> payload;

  /// وصف عربي قصير للعرض: «شراء · حسن البدري · 50 صندوق».
  final String label;

  /// وقت الحفظ على الجهاز (ISO محلي).
  final String createdAt;

  /// البراد المرتبط (يمنع تقفيله حتى تُرسل العملية).
  final String? coolerId;
  final int attempts;

  /// آخر رسالة خطأ عربية.
  final String? lastError;
  final String? errorCode;

  /// رفضها الخادم لسبب لا تحلّه إعادة المحاولة (براد مقفّل، بيانات غير صالحة...): تحتاج قرار المستخدم.
  final bool blocked;

  OutboxEntry copyWith({int? attempts, String? lastError, String? errorCode, bool? blocked}) => OutboxEntry(
        requestId: requestId,
        action: action,
        payload: payload,
        label: label,
        createdAt: createdAt,
        coolerId: coolerId,
        attempts: attempts ?? this.attempts,
        lastError: lastError ?? this.lastError,
        errorCode: errorCode ?? this.errorCode,
        blocked: blocked ?? this.blocked,
      );

  Map<String, dynamic> toJson() => {
        'requestId': requestId,
        'action': action,
        'payload': payload,
        'label': label,
        'createdAt': createdAt,
        'coolerId': coolerId,
        'attempts': attempts,
        'lastError': lastError,
        'errorCode': errorCode,
        'blocked': blocked,
      };
}

/// نتيجة [Outbox.submit].
sealed class SubmitOutcome {
  const SubmitOutcome();
}

/// وصلت إلى الخادم وحُفظت في الملف المركزي.
class SubmitSent extends SubmitOutcome {
  const SubmitSent(this.data);
  final Map<String, dynamic> data;
}

/// لا اتصال: حُفظت على الجهاز «بانتظار المزامنة» وستُرسل تلقائيًا بالمعرّف نفسه.
class SubmitQueued extends SubmitOutcome {
  const SubmitQueued(this.entry);
  final OutboxEntry entry;
}

/// مكان حفظ القائمة. الافتراضي [SharedPreferencesOutboxStorage]؛ الاختبارات تستخدم [MemoryOutboxStorage].
abstract class OutboxStorage {
  Future<List<OutboxEntry>> read(String key);
  Future<void> write(String key, List<OutboxEntry> entries);
}

class MemoryOutboxStorage implements OutboxStorage {
  final data = <String, String>{};

  @override
  Future<List<OutboxEntry>> read(String key) async => _decode(data[key]);

  @override
  Future<void> write(String key, List<OutboxEntry> entries) async => data[key] = _encode(entries);
}

/// SharedPreferences: localStorage على الويب، وملفات التطبيق على Android وiPhone.
///
/// القائمة بيانات عمل (أسماء وأرقام) وليست بيانات دخول؛ الجلسة نفسها في التخزين الآمن (SessionStore).
class SharedPreferencesOutboxStorage implements OutboxStorage {
  @override
  Future<List<OutboxEntry>> read(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return _decode(prefs.getString(key));
    } catch (_) {
      return const [];
    }
  }

  @override
  Future<void> write(String key, List<OutboxEntry> entries) async {
    final prefs = await SharedPreferences.getInstance();
    if (entries.isEmpty) {
      await prefs.remove(key);
    } else {
      await prefs.setString(key, _encode(entries));
    }
  }
}

List<OutboxEntry> _decode(String? raw) {
  if (raw == null || raw.isEmpty) return const [];
  try {
    return [
      for (final e in (jsonDecode(raw) as List))
        if (e is Map) OutboxEntry.fromJson(e.cast<String, dynamic>()),
    ];
  } catch (_) {
    return const [];
  }
}

String _encode(List<OutboxEntry> entries) => jsonEncode([for (final e in entries) e.toJson()]);

/// قائمة «بانتظار المزامنة»: عمليات الشراء والدفعات التي سُجّلت دون اتصال.
///
/// * [submit] يرسل فورًا؛ إن انقطع الاتصال (أو انشغل الملف) تُحفظ العملية على الجهاز بالـ requestId نفسه.
/// * [flush] يرسل المحفوظ بالترتيب. يُستدعى تلقائيًا كل 30 ثانية ما دامت القائمة غير فارغة، وعند عودة
///   الاتصال، وعند فتح التطبيق.
/// * عملية يرفضها الخادم لسبب دائم تصبح [OutboxEntry.blocked] وتبقى حتى يقرر المستخدم ([discard]).
/// * القائمة لكل مستخدم على حدة ([bindUser])، فلا تُرسل عمليات مستخدم بجلسة غيره.
class Outbox extends ChangeNotifier {
  Outbox({
    required this.api,
    OutboxStorage? storage,
    this.retryInterval = const Duration(seconds: 30),
    DateTime Function()? clock,
  })  : _storage = storage ?? SharedPreferencesOutboxStorage(),
        _clock = clock ?? DateTime.now;

  final BackendApi api;
  final OutboxStorage _storage;
  final Duration retryInterval;
  final DateTime Function() _clock;

  String? _key;
  List<OutboxEntry> _entries = const [];
  bool _syncing = false;
  bool _disposed = false;
  Timer? _timer;
  Future<void>? _loading;

  /// يُستدعى بعد كل إرسال ناجح من القائمة (لتحديث الشاشات المفتوحة).
  final _sent = StreamController<OutboxEntry>.broadcast();

  List<OutboxEntry> get entries => List.unmodifiable(_entries);
  int get pendingCount => _entries.length;
  int get blockedCount => _entries.where((e) => e.blocked).length;
  bool get syncing => _syncing;
  bool get isEmpty => _entries.isEmpty;

  /// كل عملية أُرسلت بنجاح من القائمة.
  Stream<OutboxEntry> get sent => _sent.stream;

  /// عدد عمليات البراد التي لم تصل بعد (تُرسل مع coolers.close كـ clientPendingCount).
  int pendingForCooler(String coolerId) => _entries.where((e) => e.coolerId == coolerId).length;

  /// يربط القائمة بالمستخدم الحالي ويحمّلها (null عند الخروج: تُخفى القائمة دون حذفها).
  Future<void> bindUser(String? email) {
    final key = email == null || email.isEmpty ? null : 'rumman.outbox.v1.${email.toLowerCase()}';
    if (key == _key && _loading != null) return _loading!;
    _key = key;
    _entries = const [];
    _timer?.cancel();
    _notify();
    if (key == null) return _loading = Future.value();
    return _loading = () async {
      final loaded = await _storage.read(key);
      if (_key != key || _disposed) return;
      _entries = loaded;
      _notify();
      _schedule();
      unawaited(flush());
    }();
  }

  /// يرسل [action] الآن، أو يحفظه في القائمة إن تعذّر الاتصال.
  ///
  /// يرمي [ApiException] لأي خطأ آخر (بيانات غير صالحة، صلاحيات، براد مقفّل...) فيعرضه النموذج.
  Future<SubmitOutcome> submit({
    required String action,
    required Map<String, dynamic> payload,
    required String requestId,
    required String label,
    String? coolerId,
  }) async {
    assert(outboxActions.contains(action), '$action لا يُحفظ في قائمة المزامنة');
    try {
      final data = await api.call(action, payload: payload, mutation: true, requestId: requestId);
      return SubmitSent(data);
    } on ApiException catch (e) {
      if (!e.isRetryable || _key == null) rethrow;
      final entry = OutboxEntry(
        requestId: requestId,
        action: action,
        payload: payload,
        label: label,
        createdAt: _clock().toIso8601String(),
        coolerId: coolerId,
        attempts: 1,
        lastError: e.message,
        errorCode: e.code.wire,
      );
      // المعرّف نفسه لا يُضاف مرتين (ضغطتان على «حفظ» أثناء الانقطاع).
      _entries = [..._entries.where((x) => x.requestId != requestId), entry];
      await _persist();
      _notify();
      _schedule();
      return SubmitQueued(entry);
    }
  }

  /// يرسل العمليات المحفوظة بالترتيب. يتوقف عند أول انقطاع ويعيد المحاولة لاحقًا.
  Future<void> flush() async {
    if (_syncing || _key == null || _entries.isEmpty) return;
    final key = _key;
    _syncing = true;
    _notify();
    try {
      for (final entry in List.of(_entries)) {
        if (_key != key || _disposed) return;
        if (entry.blocked) continue;
        try {
          await api.call(entry.action, payload: entry.payload, mutation: true, requestId: entry.requestId);
          _entries = [..._entries.where((x) => x.requestId != entry.requestId)];
          await _persist();
          _sent.add(entry);
          _notify();
        } on ApiException catch (e) {
          final retry = e.isRetryable || e.requiresLogin;
          _replace(entry.copyWith(
            attempts: entry.attempts + 1,
            lastError: e.message,
            errorCode: e.code.wire,
            blocked: !retry,
          ));
          await _persist();
          _notify();
          // انقطاع أو انتهاء الجلسة: لا فائدة من إرسال البقية الآن.
          if (retry) return;
        }
      }
    } finally {
      _syncing = false;
      _notify();
      _schedule();
    }
  }

  /// يحذف عملية من الجهاز نهائيًا (بعد تأكيد المستخدم). لا يمس الملف المركزي.
  Future<void> discard(String requestId) async {
    _entries = [..._entries.where((x) => x.requestId != requestId)];
    await _persist();
    _notify();
    _schedule();
  }

  /// يعيد محاولة عملية موقوفة (بعد أن يعالج المستخدم السبب، مثل إعادة فتح البراد).
  Future<void> retry(String requestId) async {
    final i = _entries.indexWhere((x) => x.requestId == requestId);
    if (i < 0) return;
    _replace(_entries[i].copyWith(blocked: false));
    await _persist();
    _notify();
    await flush();
  }

  void _replace(OutboxEntry entry) {
    _entries = [for (final x in _entries) x.requestId == entry.requestId ? entry : x];
  }

  Future<void> _persist() async {
    final key = _key;
    if (key == null) return;
    try {
      await _storage.write(key, _entries);
    } catch (_) {
      // تبقى في الذاكرة حتى الكتابة التالية.
    }
  }

  void _schedule() {
    _timer?.cancel();
    _timer = null;
    if (_disposed || _key == null || _entries.every((e) => e.blocked)) return;
    _timer = Timer(retryInterval, () => unawaited(flush()));
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    unawaited(_sent.close());
    super.dispose();
  }
}
