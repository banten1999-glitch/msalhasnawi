import 'package:rumman_calculator/core/auth/auth_controller.dart';
import 'package:rumman_calculator/core/models/user.dart';

import 'sample_data.dart';

/// حالة دخول وهمية: مستخدم مسجّل الدخول، مع تسجيل استدعاءات الخروج وتحديث المستخدم.
class FakeAuthController extends AuthController {
  FakeAuthController({AppUser? user, this._offline = false, this._isDemo = false}) : _user = user ?? sampleAdmin();

  AppUser? _user;
  AuthStatus _status = AuthStatus.signedIn;
  bool _offline;
  final bool _isDemo;

  int signOutCalls = 0;
  final updatedUsers = <AppUser>[];

  @override
  AuthStatus get status => _status;

  @override
  AppUser? get user => _user;

  @override
  String? get message => null;

  @override
  String? get notAllowedEmail => null;

  @override
  bool get offline => _offline;

  set offline(bool value) {
    _offline = value;
    notifyListeners();
  }

  @override
  bool get isDemo => _isDemo;

  @override
  bool get usesRenderedWebButton => false;

  @override
  Future<void> restore() async {}

  @override
  Future<void> signIn() async {}

  @override
  Future<void> signInWithIdToken(String idToken) async {}

  @override
  Future<void> signOut({String? message}) async {
    signOutCalls++;
    _status = AuthStatus.signedOut;
    _user = null;
    notifyListeners();
  }

  @override
  void updateUser(AppUser user) {
    updatedUsers.add(user);
    if (_user?.id == user.id) _user = user;
    notifyListeners();
  }
}
