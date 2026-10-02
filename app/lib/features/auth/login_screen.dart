import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../brand/animated_logo.dart';
import '../../core/auth/auth_controller.dart';
import '../../core/auth/google_auth_controller.dart';
import '../../theme/app_theme.dart';
import 'auth_widgets.dart';

/// شاشة الدخول: الشعار، وزر «المتابعة باستخدام Google»، وتنبيه أن الدخول للحسابات المضافة فقط.
///
/// على الويب يظهر زر Google الرسمي المرسوم بمكتبة Google (authenticate() غير مدعومة في المتصفح).
class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = AppScope.of(context).auth;
    return ListenableBuilder(
      listenable: auth,
      builder: (context, _) {
        final busy = auth.status == AuthStatus.signingIn;
        final message = auth.message;
        return AuthScaffold(
          top: auth.isDemo
              ? const AuthChip(
                  label: 'وضع تجريبي',
                  icon: Icons.science_outlined,
                  background: AppColors.amberLight,
                  foreground: AppColors.amber,
                )
              : null,
          body: const [
            AppLogo(size: 112),
            SizedBox(height: 20),
            AuthTitle('حاسبة الرمان'),
            SizedBox(height: 8),
            AuthSubtitle('شراء الرمان من المزارعين، وتحميل البرادات، ومشتريات التعبئة في مكان واحد.'),
          ],
          footer: [
            if (message != null && message.isNotEmpty && !busy) AuthErrorBanner(message),
            _googleButton(auth, busy),
            if (auth.isDemo) ...[
              AuthPrimaryButton(
                label: 'دخول تجريبي',
                icon: Icons.science_outlined,
                busy: busy,
                onPressed: auth.signIn,
              ),
              const Text(
                'الوضع التجريبي يفتح التطبيق ببيانات ثابتة في الذاكرة، دون حساب Google ودون أي ملف حقيقي.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12.5, height: 1.5, color: AppColors.inkMuted),
              ),
            ],
            const AuthInfoCard(
              icon: Icons.verified_user_outlined,
              text: 'الدخول متاح فقط للحسابات التي أضافها المدير. نجاح الدخول لدى Google وحده لا يكفي لعرض أي بيانات.',
            ),
            const AuthVersionText(),
          ],
        );
      },
    );
  }

  Widget _googleButton(AuthController auth, bool busy) {
    if (auth.usesRenderedWebButton && auth is GoogleAuthController) {
      if (busy) return const _VerifyingBox();
      return Center(child: auth.google.buildButton(minimumWidth: 320));
    }
    return AuthSecondaryButton(
      key: const ValueKey('google-sign-in'),
      label: 'المتابعة باستخدام Google',
      busyLabel: 'جارٍ تسجيل الدخول…',
      leading: const GoogleGLogo(),
      busy: busy,
      height: 56,
      fontSize: 17,
      onPressed: auth.signIn,
    );
  }
}

/// مكان زر الويب أثناء تحقق الخادم من الحساب.
class _VerifyingBox extends StatelessWidget {
  const _VerifyingBox();

  @override
  Widget build(BuildContext context) => Container(
        height: 56,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border, width: 1.5),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2.4)),
            SizedBox(width: 12),
            Text('جارٍ التحقق من الحساب…', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          ],
        ),
      );
}
