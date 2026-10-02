import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../brand/animated_logo.dart';
import '../../theme/app_theme.dart';
import 'auth_widgets.dart';

/// تظهر إن استمرت استعادة الجلسة بعد انتهاء شاشة البداية.
class AuthLoadingScreen extends StatelessWidget {
  const AuthLoadingScreen({super.key});

  @override
  Widget build(BuildContext context) => const Scaffold(
        backgroundColor: AppColors.ivory,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppLogo(size: 96),
              SizedBox(height: 24),
              SizedBox.square(dimension: 28, child: CircularProgressIndicator(strokeWidth: 3)),
              SizedBox(height: 14),
              Text('جارٍ التحقق من حسابك…', style: TextStyle(fontSize: 15, color: AppColors.inkSecondary)),
            ],
          ),
        ),
      );
}

/// تعذّر التحقق من الجلسة المحفوظة (مثل خطأ في الخادم أو الملف ولا توجد بيانات محفوظة).
class AuthErrorScreen extends StatelessWidget {
  const AuthErrorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = AppScope.of(context).auth;
    return ListenableBuilder(
      listenable: auth,
      builder: (context, _) => AuthScaffold(
        body: [
          const AuthIconBadge(
            icon: Icons.cloud_off_outlined,
            background: AppColors.amberLight,
            foreground: AppColors.amber,
          ),
          const SizedBox(height: 18),
          const AuthTitle('تعذّر التحقق من الحساب', size: 24),
          const SizedBox(height: 8),
          const AuthSubtitle(
            'جلستك محفوظة على هذا الجهاز، لكن الخادم لم يؤكدها الآن. لم تُعرض أي بيانات.',
            size: 15,
          ),
          if (auth.message != null && auth.message!.isNotEmpty) ...[
            const SizedBox(height: 16),
            AuthErrorBanner(auth.message!),
          ],
        ],
        footer: [
          AuthPrimaryButton(label: 'إعادة المحاولة', icon: Icons.refresh, onPressed: auth.restore),
          AuthSecondaryButton(label: 'تسجيل الخروج', onPressed: () => auth.signOut()),
        ],
      ),
    );
  }
}
