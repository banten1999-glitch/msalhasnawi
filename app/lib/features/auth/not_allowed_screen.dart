import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../core/auth/auth_controller.dart';
import '../../core/auth/google_auth_controller.dart';
import '../../theme/app_theme.dart';
import 'auth_widgets.dart';

/// «هذا الحساب غير مصرح له»: الدخول لدى Google نجح لكن البريد ليس في قائمة المستخدمين أو معطّل.
///
/// لا تُعرض ولا تُحمّل أي بيانات في هذه الحالة.
class NotAllowedScreen extends StatelessWidget {
  const NotAllowedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = AppScope.of(context).auth;
    return ListenableBuilder(
      listenable: auth,
      builder: (context, _) {
        final busy = auth.status == AuthStatus.signingIn;
        final email = auth.notAllowedEmail;
        final disabled = auth is GoogleAuthController && auth.notAllowedReason == 'disabled';
        return AuthScaffold(
          body: [
            const AuthIconBadge(
              icon: Icons.lock_outline,
              background: AppColors.pomegranateLight,
              foreground: AppColors.pomegranate,
            ),
            const SizedBox(height: 18),
            const AuthTitle('هذا الحساب غير مصرح له', size: 24),
            const SizedBox(height: 8),
            AuthSubtitle(
              disabled
                  ? 'سجّلت الدخول لدى Google بنجاح، لكن هذا الحساب معطّل في قائمة المستخدمين.'
                  : 'سجّلت الدخول لدى Google بنجاح، لكن هذا البريد غير موجود في قائمة المستخدمين المسموح لهم.',
              size: 15,
            ),
            if (email != null) ...[
              const SizedBox(height: 16),
              _EmailChip(email: email),
            ],
            const SizedBox(height: 16),
            AuthInfoCard(
              icon: Icons.info_outline,
              iconColor: AppColors.info,
              background: AppColors.infoLight,
              foreground: AppColors.info,
              bordered: false,
              text: disabled
                  ? 'اطلب من مدير التطبيق تفعيل حسابك من «الإعدادات ← المستخدمون»، ثم اضغط «إعادة المحاولة». '
                      'لم تُعرض أو تُحمّل أي بيانات على هذا الجهاز.'
                  : 'اطلب من مدير التطبيق إضافة بريدك من «الإعدادات ← المستخدمون»، ثم اضغط «إعادة المحاولة». '
                      'لم تُعرض أو تُحمّل أي بيانات على هذا الجهاز.',
            ),
          ],
          footer: [
            AuthPrimaryButton(
              label: 'إعادة المحاولة',
              icon: Icons.refresh,
              busy: busy,
              onPressed: auth.signIn,
            ),
            AuthSecondaryButton(
              label: 'الدخول بحساب آخر',
              onPressed: busy ? null : () => _useAnotherAccount(auth),
            ),
          ],
        );
      },
    );
  }

  Future<void> _useAnotherAccount(AuthController auth) async {
    await auth.signOut();
    // على Android وiPhone نفتح اختيار الحساب مباشرة؛ على الويب تظهر شاشة الدخول بزر Google.
    if (!auth.usesRenderedWebButton && !auth.isDemo) await auth.signIn();
  }
}

class _EmailChip extends StatelessWidget {
  const _EmailChip({required this.email});

  final String email;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AuthColors.cardBorder),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: const BoxDecoration(color: Color(0xFFEEE9E2), shape: BoxShape.circle),
              child: const Icon(Icons.person_outline, size: 20, color: Color(0xFF4A423C)),
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                email,
                textDirection: TextDirection.ltr,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600, color: AppColors.ink),
              ),
            ),
          ],
        ),
      );
}
