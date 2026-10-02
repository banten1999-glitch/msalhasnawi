import 'package:flutter/material.dart';

import '../brand/animated_logo.dart';
import '../theme/app_theme.dart';

/// شاشة مؤقتة بعد البداية، تُستبدل بتسجيل الدخول ولوحة التحكم في المرحلة التالية.
class HomePlaceholder extends StatelessWidget {
  const HomePlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.ivory,
        title: const Text('حاسبة الرمان', style: TextStyle(fontFamily: AppFonts.display, fontWeight: FontWeight.w700)),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                child: const AppLogo(size: 120),
              ),
              const SizedBox(height: 20),
              Text('مرحبًا بك', style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 8),
              const Text(
                'تسجيل الدخول ولوحة التحكم هما الخطوة التالية في التنفيذ.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: AppColors.inkSecondary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
