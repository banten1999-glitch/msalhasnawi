import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:rumman_calculator/core/api/api_exception.dart';
import 'package:rumman_calculator/core/api/http_backend_api.dart';
import 'package:rumman_calculator/core/models/user.dart';

const _url = 'https://script.google.com/macros/s/TEST/exec';
const _echo = 'https://script.googleusercontent.com/macros/echo?user_content_key=abc';

http.Response _json(Object body, {int status = 200}) => http.Response.bytes(
      utf8.encode(jsonEncode(body)),
      status,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );

Map<String, dynamic> _ok(Object? data) => {'ok': true, 'data': data, 'serverTime': '2026-10-02T10:58:00+03:00'};

Map<String, dynamic> _err(String code, String message, {String? field, Map<String, dynamic> details = const {}}) => {
      'ok': false,
      'error': {'code': code, 'message': message, 'field': field, 'details': details},
      'serverTime': '2026-10-02T10:58:00+03:00',
    };

const _adminUser = {
  'id': 'US-0001',
  'email': 'owner@example.com',
  'name': 'محمد',
  'role': 'admin',
  'status': 'active',
  'isBootstrap': true,
  'version': 1,
  'permissions': {'viewData': true, 'manageUsers': true},
};

void main() {
  group('غلاف الطلب والرد', () {
    test('يرسل POST نصيًا بالحقول الخمسة ويعيد data', () async {
      late http.Request sent;
      final api = HttpBackendApi(
        apiUrl: _url,
        web: true,
        platform: 'android',
        appVersion: '1.0.0',
        client: MockClient((req) async {
          sent = req;
          return _json(_ok({'value': 42}));
        }),
      )..session = 'SESSION-1';

      final data = await api.call('settings.get', payload: {'a': 1});

      expect(data, {'value': 42});
      expect(sent.method, 'POST');
      expect(sent.url.toString(), _url);
      expect(sent.headers['content-type'], startsWith('text/plain'));
      expect(sent.headers['content-type'], contains('charset=utf-8'));
      final body = jsonDecode(sent.body) as Map<String, dynamic>;
      expect(body['action'], 'settings.get');
      expect(body['session'], 'SESSION-1');
      expect(body['requestId'], isNull, reason: 'القراءة لا تحتاج requestId');
      expect(body['payload'], {'a': 1});
      expect(body['client'], {'platform': 'android', 'version': '1.0.0'});
    });

    test('data = null تُعاد كخريطة فارغة', () async {
      final api = HttpBackendApi(apiUrl: _url, web: true, client: MockClient((_) async => _json(_ok(null))));
      expect(await api.call('auth.logout'), isEmpty);
    });

    test('{ok:false} يصبح ApiException بالكود والحقل والتفاصيل', () async {
      final api = HttpBackendApi(
        apiUrl: _url,
        web: true,
        client: MockClient((_) async => _json(_err('VALIDATION', 'عدد الصناديق مطلوب.', field: 'boxes', details: {'max': 5}))),
      );
      await expectLater(
        api.call('purchases.create', mutation: true),
        throwsA(isA<ApiException>()
            .having((e) => e.code, 'code', ApiErrorCode.validation)
            .having((e) => e.message, 'message', 'عدد الصناديق مطلوب.')
            .having((e) => e.field, 'field', 'boxes')
            .having((e) => e.details['max'], 'details.max', 5)),
      );
    });

    test('كود غير معروف يصبح INTERNAL', () async {
      final api = HttpBackendApi(apiUrl: _url, web: true, client: MockClient((_) async => _json(_err('SOMETHING_NEW', 'رسالة'))));
      await expectLater(api.call('x'), throwsA(isA<ApiException>().having((e) => e.code, 'code', ApiErrorCode.internal)));
    });
  });

  group('التحويل (Apps Script يرد دائمًا بـ 302)', () {
    test('على Android وiPhone: POST دون تتبع التحويل ثم GET إلى Location', () async {
      final requests = <http.Request>[];
      final api = HttpBackendApi(
        apiUrl: _url,
        web: false,
        client: MockClient((req) async {
          requests.add(req);
          if (req.method == 'POST') {
            return http.Response('', 302, headers: {'location': _echo});
          }
          return _json(_ok({'user': _adminUser}));
        }),
      );

      final user = await api.me();

      expect(user.email, 'owner@example.com');
      expect(requests, hasLength(2));
      expect(requests[0].method, 'POST');
      expect(requests[0].followRedirects, isFalse);
      expect(requests[1].method, 'GET');
      expect(requests[1].url.toString(), _echo);
    });

    for (final code in [301, 303, 307, 308]) {
      test('رمز $code يُتبع أيضًا بـ GET', () async {
        var gets = 0;
        final api = HttpBackendApi(
          apiUrl: _url,
          web: false,
          client: MockClient((req) async {
            if (req.method == 'POST') return http.Response('', code, headers: {'location': _echo});
            gets++;
            return _json(_ok({'n': code}));
          }),
        );
        expect(await api.call('x'), {'n': code});
        expect(gets, 1);
      });
    }

    test('رد 200 مباشر بلا تحويل يُقرأ كما هو', () async {
      var count = 0;
      final api = HttpBackendApi(
        apiUrl: _url,
        web: false,
        client: MockClient((req) async {
          count++;
          return _json(_ok({'direct': true}));
        }),
      );
      expect(await api.call('x'), {'direct': true});
      expect(count, 1);
    });

    test('تحويل بلا Location ⇒ BAD_RESPONSE', () async {
      final api = HttpBackendApi(apiUrl: _url, web: false, client: MockClient((_) async => http.Response('', 302)));
      await expectLater(api.call('x'), throwsA(isA<ApiException>().having((e) => e.code, 'code', ApiErrorCode.badResponse)));
    });

    test('على الويب: طلب واحد عادي والمتصفح يتتبع التحويل', () async {
      final requests = <http.Request>[];
      final api = HttpBackendApi(
        apiUrl: _url,
        web: true,
        client: MockClient((req) async {
          requests.add(req);
          return _json(_ok({'web': true}));
        }),
      );
      expect(await api.call('x'), {'web': true});
      expect(requests.single.method, 'POST');
    });
  });

  group('أخطاء الشبكة والردود غير المفهومة', () {
    test('انتهاء المهلة ⇒ NETWORK برسالة عربية وrequestId في التفاصيل', () async {
      final api = HttpBackendApi(
        apiUrl: _url,
        web: true,
        timeout: const Duration(milliseconds: 50),
        newRequestId: () => 'REQ-TIMEOUT',
        client: MockClient((_) async {
          await Future<void>.delayed(const Duration(milliseconds: 500));
          return _json(_ok({}));
        }),
      );
      await expectLater(
        api.call('purchases.create', mutation: true),
        throwsA(isA<ApiException>()
            .having((e) => e.code, 'code', ApiErrorCode.network)
            .having((e) => e.isRetryable, 'isRetryable', isTrue)
            .having((e) => e.message, 'message', contains('ثانية'))
            .having((e) => e.details['requestId'], 'requestId', 'REQ-TIMEOUT')),
      );
    });

    test('فشل الاتصال ⇒ NETWORK', () async {
      final api = HttpBackendApi(
        apiUrl: _url,
        web: false,
        client: MockClient((_) async => throw http.ClientException('Connection refused')),
      );
      await expectLater(
        api.call('x'),
        throwsA(isA<ApiException>()
            .having((e) => e.code, 'code', ApiErrorCode.network)
            .having((e) => e.message, 'message', contains('الإنترنت'))),
      );
    });

    test('صفحة HTML (مثل صفحة دخول Google) ⇒ BAD_RESPONSE تشير إلى DEPLOY.md', () async {
      final api = HttpBackendApi(
        apiUrl: _url,
        web: false,
        client: MockClient((_) async => http.Response('<!DOCTYPE html><html><body>Sign in</body></html>', 200)),
      );
      await expectLater(
        api.call('x'),
        throwsA(isA<ApiException>()
            .having((e) => e.code, 'code', ApiErrorCode.badResponse)
            .having((e) => e.message, 'message', contains('DEPLOY.md'))),
      );
    });

    test('نص ليس JSON ⇒ BAD_RESPONSE', () async {
      final api = HttpBackendApi(apiUrl: _url, web: true, client: MockClient((_) async => http.Response('hello', 200)));
      await expectLater(api.call('x'), throwsA(isA<ApiException>().having((e) => e.code, 'code', ApiErrorCode.badResponse)));
    });

    test('JSON بلا ok ⇒ BAD_RESPONSE', () async {
      final api = HttpBackendApi(apiUrl: _url, web: true, client: MockClient((_) async => _json({'hello': 1})));
      await expectLater(api.call('x'), throwsA(isA<ApiException>().having((e) => e.code, 'code', ApiErrorCode.badResponse)));
    });

    test('404 ⇒ BAD_RESPONSE تذكر رابط ‎/exec', () async {
      final api = HttpBackendApi(apiUrl: _url, web: false, client: MockClient((_) async => http.Response('Not Found', 404)));
      await expectLater(
        api.call('x'),
        throwsA(isA<ApiException>()
            .having((e) => e.code, 'code', ApiErrorCode.badResponse)
            .having((e) => e.message, 'message', contains('exec'))
            .having((e) => e.details['status'], 'status', 404)),
      );
    });

    test('بيانات بصيغة خاطئة في دالة محددة ⇒ BAD_RESPONSE', () async {
      final api = HttpBackendApi(apiUrl: _url, web: true, client: MockClient((_) async => _json(_ok({'user': 'x'}))));
      await expectLater(api.me(), throwsA(isA<ApiException>().having((e) => e.code, 'code', ApiErrorCode.badResponse)));
    });
  });

  group('requestId', () {
    Future<List<Map<String, dynamic>>> capture(Future<void> Function(HttpBackendApi api) run) async {
      final bodies = <Map<String, dynamic>>[];
      final api = HttpBackendApi(
        apiUrl: _url,
        web: true,
        client: MockClient((req) async {
          bodies.add(jsonDecode(req.body) as Map<String, dynamic>);
          return _json(_ok({'user': _adminUser}));
        }),
      );
      await run(api);
      return bodies;
    }

    test('كل عملية حفظ تحصل على UUID v4 جديد', () async {
      final bodies = await capture((api) async {
        await api.call('users.add', mutation: true);
        await api.call('users.add', mutation: true);
      });
      final a = bodies[0]['requestId'] as String;
      final b = bodies[1]['requestId'] as String;
      final v4 = RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$');
      expect(a, matches(v4));
      expect(b, matches(v4));
      expect(a, isNot(b));
    });

    test('إعادة المحاولة بنفس requestId ترسله كما هو', () async {
      final bodies = await capture((api) async {
        await api.call('purchases.create', mutation: true, requestId: 'fixed-id-1');
        await api.call('purchases.create', mutation: true, requestId: 'fixed-id-1');
      });
      expect(bodies.map((b) => b['requestId']), ['fixed-id-1', 'fixed-id-1']);
    });

    test('الدوال المحددة ترسل الإجراءات وقيم العقد', () async {
      final bodies = await capture((api) async {
        await api.addUser(
          email: ' New@Gmail.com ',
          name: 'سلمى',
          role: UserRole.entry,
          permissions: const UserPermissions(recordPurchases: true),
        );
        await api.updateUser(id: 'US-0002', expectedVersion: 3, active: false, role: UserRole.viewer);
      });
      expect(bodies[0]['action'], 'users.add');
      expect(bodies[0]['requestId'], isNotNull);
      expect(bodies[0]['payload'], {
        'email': 'New@Gmail.com',
        'name': 'سلمى',
        'role': 'entry',
        'permissions': {
          'addFarmers': false,
          'recordPurchases': true,
          'editOthers': false,
          'recordPayments': false,
          'packaging': false,
          'closeCoolers': false,
        },
      });
      expect(bodies[1]['action'], 'users.update');
      expect(bodies[1]['payload'], {'id': 'US-0002', 'expectedVersion': 3, 'role': 'viewer', 'status': 'disabled'});
    });

    test('dashboard وsheet.connect وsheet.repair', () async {
      final bodies = <Map<String, dynamic>>[];
      final api = HttpBackendApi(
        apiUrl: _url,
        web: true,
        client: MockClient((req) async {
          final body = jsonDecode(req.body) as Map<String, dynamic>;
          bodies.add(body);
          if (body['action'] == 'dashboard.get') {
            return _json(_ok({'period': {'key': 'today', 'label': 'اليوم'}, 'kpis': {}, 'empty': true}));
          }
          return _json(_ok({'configured': true, 'ok': true, 'sheets': []}));
        }),
      );
      final d = await api.dashboard(period: 'today', coolerId: 'CL-0014');
      await api.sheetConnect('  https://docs.google.com/spreadsheets/d/abc/edit  ');
      await api.sheetRepair();
      await api.sheetStatus();
      expect(d.period.key, 'today');
      expect(bodies[0]['payload'], {'period': 'today', 'coolerId': 'CL-0014'});
      expect(bodies[0]['requestId'], isNull);
      expect(bodies[1]['action'], 'sheet.connect');
      expect(bodies[1]['payload'], {'spreadsheet': 'https://docs.google.com/spreadsheets/d/abc/edit'});
      expect(bodies[1]['requestId'], isNotNull);
      expect(bodies[2]['action'], 'sheet.repair');
      expect(bodies[2]['requestId'], isNotNull);
      expect(bodies[3]['action'], 'sheet.status');
      expect(bodies[3]['requestId'], isNull);
    });
  });

  group('أحداث الجلسة', () {
    test('AUTH_EXPIRED وSESSION_STALE وAUTH_REQUIRED تستدعي onSessionExpired', () async {
      for (final code in ['AUTH_EXPIRED', 'SESSION_STALE', 'AUTH_REQUIRED']) {
        final seen = <ApiErrorCode>[];
        final api = HttpBackendApi(apiUrl: _url, web: true, client: MockClient((_) async => _json(_err(code, 'انتهت'))))
          ..onSessionExpired = (e) => seen.add(e.code);
        await expectLater(api.call('dashboard.get'), throwsA(isA<ApiException>()));
        expect(seen, hasLength(1), reason: code);
      }
    });

    test('أخطاء أخرى لا تستدعيه', () async {
      var called = false;
      final api = HttpBackendApi(apiUrl: _url, web: true, client: MockClient((_) async => _json(_err('FORBIDDEN', 'لا'))))
        ..onSessionExpired = (_) => called = true;
      await expectLater(api.call('users.list'), throwsA(isA<ApiException>()));
      expect(called, isFalse);
    });

    test('NOT_ALLOWED من إجراء محمي يستدعي onNotAllowed، ومن auth.login لا', () async {
      final seen = <String>[];
      final api = HttpBackendApi(
        apiUrl: _url,
        web: true,
        client: MockClient((_) async => _json(_err('NOT_ALLOWED', 'معطّل', details: {'email': 'a@b.c', 'reason': 'disabled'}))),
      )..onNotAllowed = (e) => seen.add(e.details['email'] as String);
      await expectLater(api.call('dashboard.get'), throwsA(isA<ApiException>()));
      await expectLater(api.login('token'), throwsA(isA<ApiException>()));
      expect(seen, ['a@b.c']);
    });

    test('onServerReachable مع كل رد مفهوم فقط', () async {
      var reached = 0;
      var fail = false;
      final api = HttpBackendApi(
        apiUrl: _url,
        web: true,
        client: MockClient((_) async {
          if (fail) throw http.ClientException('offline');
          return _json(_ok({}));
        }),
      )..onServerReachable = () => reached++;
      await api.call('x');
      fail = true;
      await expectLater(api.call('x'), throwsA(isA<ApiException>()));
      expect(reached, 1);
    });
  });
}
