import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/user.dart';

/// الجلسة المحفوظة على الجهاز.
class StoredSession {
  const StoredSession({required this.token, this.user});

  final String token;

  /// آخر بيانات معروفة للمستخدم (لعرضها دون اتصال). قد تكون null إن تعذّرت قراءتها.
  final AppUser? user;
}

/// يحفظ توكن الجلسة وآخر بيانات للمستخدم في التخزين الآمن للجهاز
/// (Keychain على iPhone، وKeystore على Android، وتخزين مشفّر في المتصفح).
///
/// لا يُحفظ أي توكن من Google؛ فقط جلسة الخادم. أي فشل في التخزين لا يوقف التطبيق:
/// القراءة تعيد null والكتابة تُتجاهل (يعني ذلك فقط طلب تسجيل الدخول مرة أخرى لاحقًا).
class SessionStore {
  SessionStore({this._storage = const FlutterSecureStorage(), String namespace = 'live'})
      : _tokenKey = 'rumman.$namespace.session',
        _userKey = 'rumman.$namespace.user';

  final FlutterSecureStorage _storage;
  final String _tokenKey;
  final String _userKey;

  Future<StoredSession?> read() async {
    try {
      final token = await _storage.read(key: _tokenKey);
      if (token == null || token.trim().isEmpty) return null;
      return StoredSession(token: token, user: await _readUser());
    } catch (_) {
      return null;
    }
  }

  Future<AppUser?> _readUser() async {
    try {
      final raw = await _storage.read(key: _userKey);
      if (raw == null || raw.isEmpty) return null;
      return AppUser.fromJson((jsonDecode(raw) as Map).cast<String, dynamic>());
    } catch (_) {
      return null;
    }
  }

  Future<void> save(String token, AppUser user) async {
    try {
      await _storage.write(key: _tokenKey, value: token);
      await _storage.write(key: _userKey, value: jsonEncode(user.toJson()));
    } catch (_) {
      // التخزين غير متاح: تبقى الجلسة في الذاكرة فقط.
    }
  }

  Future<void> saveUser(AppUser user) async {
    try {
      await _storage.write(key: _userKey, value: jsonEncode(user.toJson()));
    } catch (_) {
      // نتجاهل.
    }
  }

  Future<void> clear() async {
    try {
      await _storage.delete(key: _tokenKey);
    } catch (_) {
      // نتجاهل.
    }
    try {
      await _storage.delete(key: _userKey);
    } catch (_) {
      // نتجاهل.
    }
  }
}
