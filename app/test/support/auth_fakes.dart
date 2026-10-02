import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:rumman_calculator/core/api/api_exception.dart';
import 'package:rumman_calculator/core/api/backend_actions.dart';
import 'package:rumman_calculator/core/api/backend_api.dart';
import 'package:rumman_calculator/core/auth/google_sign_in_service.dart';

/// مستخدم كما يرده الخادم.
Map<String, dynamic> userJson({
  String id = 'US-0001',
  String email = 'owner@example.com',
  String name = 'محمد الحسناوي',
  String role = 'admin',
  String status = 'active',
  int version = 1,
}) =>
    {
      'id': id,
      'email': email,
      'name': name,
      'role': role,
      'status': status,
      'isBootstrap': id == 'US-0001',
      'version': version,
      'permissions': {'viewData': true, 'manageUsers': role == 'admin'},
    };

typedef FakeHandler = FutureOr<Map<String, dynamic>> Function(Map<String, dynamic> payload);

/// خادم وهمي: لكل إجراء دالة ترد أو ترمي ApiException. يسجل الإجراءات والجلسة المرسلة.
class ScriptedBackendApi extends BackendApi with BackendActions {
  ScriptedBackendApi([Map<String, FakeHandler>? handlers]) : handlers = {...?handlers};

  final Map<String, FakeHandler> handlers;
  final calls = <({String action, String? session, Map<String, dynamic> payload})>[];

  @override
  String? session;

  @override
  Future<Map<String, dynamic>> call(
    String action, {
    Map<String, dynamic> payload = const {},
    bool mutation = false,
    String? requestId,
  }) async {
    calls.add((action: action, session: session, payload: payload));
    final handler = handlers[action];
    if (handler == null) {
      throw ApiException(ApiErrorCode.unknownAction, 'لا يوجد رد وهمي لـ $action');
    }
    return handler(payload);
  }

  List<String> get actions => [for (final c in calls) c.action];
}

/// Google وهمي: لا يلمس المكتبة الحقيقية.
class FakeGoogleSignIn implements GoogleSignInService {
  FakeGoogleSignIn({this.usesRenderedButton = false});

  @override
  final bool usesRenderedButton;

  /// نتيجة signIn التالية: نص (ID token) أو GoogleSignInFailure.
  Object? next = 'google-id-token';
  int signInCalls = 0;
  int signOutCalls = 0;
  Completer<String>? pending;

  final _tokens = StreamController<String>.broadcast();

  void emitToken(String token) => _tokens.add(token);
  void emitError(Object error) => _tokens.addError(error);

  @override
  Future<String> signIn() async {
    signInCalls++;
    if (pending != null) return pending!.future;
    final n = next;
    if (n is GoogleSignInFailure) throw n;
    return n! as String;
  }

  @override
  Stream<String> get idTokens => _tokens.stream;

  @override
  Widget buildButton({double minimumWidth = 320}) => const SizedBox(key: ValueKey('fake-web-button'), height: 40);

  @override
  Future<void> signOut() async => signOutCalls++;
}
