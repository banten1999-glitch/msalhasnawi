import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

import '../../config/app_config.dart';
import 'api_exception.dart';
import 'backend_actions.dart';
import 'backend_api.dart';

/// الاتصال الحقيقي بخادم Apps Script (docs/API.md §2).
///
/// * كل طلب `POST` بنوع `text/plain;charset=utf-8` (طلب «بسيط» بلا CORS preflight) وجسمه
///   `{action, session, requestId, payload, client}`.
/// * Apps Script يرد دائمًا بتحويل 302 إلى `script.googleusercontent.com`. على Android وiPhone
///   يُرسل الطلب دون تتبع التحويل، ثم يُقرأ الرد بطلب `GET` إلى عنوان `Location`. المتصفح يتتبعه بنفسه.
/// * 30 ثانية حدًا أقصى للطلب كاملًا، وإلا [ApiErrorCode.network].
class HttpBackendApi extends BackendApi with BackendActions {
  HttpBackendApi({
    required String apiUrl,
    http.Client? client,
    this.timeout = const Duration(seconds: 30),
    bool? web,
    String? platform,
    this.appVersion = AppConfig.appVersion,
    String Function()? newRequestId,
  })  : _uri = Uri.parse(apiUrl.trim()),
        _client = client ?? http.Client(),
        _web = web ?? kIsWeb,
        _platform = platform ?? _detectPlatform(),
        _newRequestId = newRequestId ?? _uuidV4;

  final Uri _uri;
  final http.Client _client;
  final bool _web;
  final String _platform;
  final String Function() _newRequestId;

  /// الحد الأقصى لانتظار الطلب كاملًا (مع التحويل وقراءة الرد).
  final Duration timeout;
  final String appVersion;

  @override
  String? session;

  /// يُستدعى عند أي خطأ يتطلب تسجيل الدخول من جديد (انتهت الجلسة، أو تغيّرت الصلاحيات).
  void Function(ApiException error)? onSessionExpired;

  /// يُستدعى عند NOT_ALLOWED من إجراء غير الدخول (عُطّل الحساب أو حُذف أثناء استخدامه).
  void Function(ApiException error)? onNotAllowed;

  /// يُستدعى مع كل رد مفهوم من الخادم (نجاحًا أو خطأً)، أي أن الاتصال يعمل.
  void Function()? onServerReachable;

  static const _redirectCodes = {301, 302, 303, 307, 308};
  static const _deployHint = 'راجع $_deployDoc';
  static const _deployDoc = '\u2066backend/\u2060DEPLOY.md\u2069';
  static const _exec = '\u2066/\u2060exec\u2069';

  static String _uuidV4() => const Uuid().v4();

  static String _detectPlatform() {
    if (kIsWeb) return 'web';
    switch (defaultTargetPlatform) {
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
        return 'ios';
      default:
        return 'android';
    }
  }

  /// يغلق اتصال HTTP. لا يُستخدم الكائن بعدها.
  void close() => _client.close();

  @override
  Future<Map<String, dynamic>> call(
    String action, {
    Map<String, dynamic> payload = const {},
    bool mutation = false,
    String? requestId,
  }) async {
    final id = mutation ? (requestId ?? _newRequestId()) : requestId;
    final body = jsonEncode({
      'action': action,
      'session': session,
      'requestId': id,
      'payload': payload,
      'client': {'platform': _platform, 'version': appVersion},
    });

    final http.Response response;
    try {
      response = await _send(body).timeout(timeout);
    } on TimeoutException {
      throw ApiException(
        ApiErrorCode.network,
        'لم يصل رد من الخادم خلال ${timeout.inSeconds} ثانية. تحقق من اتصال الإنترنت ثم أعد المحاولة.',
        details: {'action': action, 'requestId': ?id, 'reason': 'timeout'},
      );
    } on ApiException {
      rethrow;
    } catch (_) {
      throw ApiException(
        ApiErrorCode.network,
        'تعذّر الاتصال بالخادم. تحقق من اتصال الإنترنت ثم أعد المحاولة.',
        details: {'action': action, 'requestId': ?id, 'reason': 'connection'},
      );
    }

    final envelope = _decodeEnvelope(response);
    onServerReachable?.call();

    if (envelope['ok'] == true) {
      final data = envelope['data'];
      if (data == null) return <String, dynamic>{};
      if (data is Map) return data.cast<String, dynamic>();
      throw _badResponse('بيانات الرد ليست بالصيغة المتوقعة.');
    }

    final error = envelope['error'];
    final exception = error is Map
        ? ApiException.fromJson(error.cast<String, dynamic>())
        : _badResponse('الرد يفيد بفشل العملية لكنه لا يذكر السبب.');
    if (exception.requiresLogin) {
      onSessionExpired?.call(exception);
    } else if (exception.code == ApiErrorCode.notAllowed && action != 'auth.login') {
      onNotAllowed?.call(exception);
    }
    throw exception;
  }

  Future<http.Response> _send(String body) async {
    const headers = {'Content-Type': 'text/plain;charset=utf-8'};
    if (_web) {
      // المتصفح يتتبع التحويل بنفسه ويقرأ الرد النهائي.
      return _client.post(_uri, headers: headers, body: body, encoding: utf8);
    }
    final request = http.Request('POST', _uri)
      ..followRedirects = false
      ..headers.addAll(headers)
      ..body = body;
    final first = await http.Response.fromStream(await _client.send(request));
    if (!_redirectCodes.contains(first.statusCode)) return first;
    final location = first.headers['location'];
    if (location == null || location.isEmpty) {
      throw _badResponse('الخادم طلب التحويل إلى عنوان آخر دون أن يذكره.');
    }
    return _client.get(_uri.resolve(location));
  }

  Map<String, dynamic> _decodeEnvelope(http.Response response) {
    final text = utf8.decode(response.bodyBytes, allowMalformed: true).trim();
    final status = response.statusCode;
    if (text.startsWith('<')) {
      throw _badResponse(_htmlMessage(status), status: status);
    }
    Object? decoded;
    try {
      decoded = text.isEmpty ? null : jsonDecode(text);
    } on FormatException {
      decoded = null;
    }
    if (decoded is Map && decoded['ok'] is bool) return decoded.cast<String, dynamic>();
    if (status != 200) throw _badResponse(_statusMessage(status), status: status);
    throw _badResponse('رد الخادم ليس بيانات JSON مفهومة.');
  }

  String _htmlMessage(int status) {
    if (status == 404) return _statusMessage(status);
    return 'رد الخادم صفحة ويب وليس بيانات. غالبًا عنوان الخادم (API_URL) ليس رابط نشر Apps Script '
        'المنتهي بـ $_exec، أو أن النشر غير متاح لـ «أي شخص» (Anyone). $_deployHint ثم أعد المحاولة.';
  }

  String _statusMessage(int status) {
    if (status == 401 || status == 403) {
      return 'الخادم رفض الطلب (رمز $status). تأكد أن نشر Apps Script متاح لـ «أي شخص» (Anyone) '
          'وأنه يعمل باسم مالك الملف. $_deployHint ثم أعد المحاولة.';
    }
    if (status == 404) {
      return 'عنوان الخادم غير موجود (رمز 404). تأكد أن API_URL هو رابط النشر الصحيح المنتهي بـ $_exec. '
          '$_deployHint.';
    }
    if (status == 429 || status >= 500) {
      return 'خدمة Google لا تستجيب الآن (رمز $status). انتظر قليلًا ثم أعد المحاولة.';
    }
    return 'رد الخادم غير متوقع (رمز $status). $_deployHint ثم أعد المحاولة.';
  }

  ApiException _badResponse(String message, {int? status}) => ApiException(
        ApiErrorCode.badResponse,
        message,
        details: {'status': ?status},
      );
}
