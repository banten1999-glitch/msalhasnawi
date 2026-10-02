import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/app_theme.dart';
import 'auth_widgets.dart';

/// تظهر عندما تُبنى نسخة من التطبيق دون عنوان الخادم (API_URL) ودون الوضع التجريبي.
class SetupRequiredScreen extends StatelessWidget {
  const SetupRequiredScreen({super.key});

  static const runCommand = 'flutter run --dart-define=API_URL=https://script.google.com/macros/s/XXXX/exec';
  static const demoCommand = 'flutter run --dart-define=DEMO=true';

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      body: [
        const AuthIconBadge(
          icon: Icons.link_off,
          background: AppColors.amberLight,
          foreground: AppColors.amber,
        ),
        const SizedBox(height: 18),
        const AuthTitle('إعداد الخادم مطلوب', size: 24),
        const SizedBox(height: 8),
        const AuthSubtitle(
          'هذه النسخة من التطبيق لا تعرف عنوان الخادم (API_URL)، لذلك لا يمكن تسجيل الدخول أو قراءة البيانات.',
          size: 15,
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AuthColors.cardBorder),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Step(
                number: '1',
                text: 'انشر الخادم من محرر Apps Script المرتبط بملف Google Sheets كما في الملف \u2066backend/\u2060DEPLOY.md\u2069، '
                    'ثم انسخ رابط النشر المنتهي بـ \u2066/\u2060exec\u2069.',
              ),
              SizedBox(height: 14),
              _Step(number: '2', text: 'أعد بناء التطبيق أو شغّله مع العنوان مكان XXXX:'),
              SizedBox(height: 8),
              _CommandBox(command: runCommand),
              SizedBox(height: 14),
              _Step(number: '3', text: 'للتجربة دون خادم، شغّل الوضع التجريبي ببيانات ثابتة:'),
              SizedBox(height: 8),
              _CommandBox(command: demoCommand),
            ],
          ),
        ),
      ],
      footer: const [
        AuthInfoCard(
          icon: Icons.lock_outline,
          text: 'لا توضع أي كلمة سر أو مفتاح داخل التطبيق. العنوان وحده يكفي؛ الخادم يتحقق من كل مستخدم بنفسه.',
        ),
        AuthVersionText(),
      ],
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({required this.number, required this.text});

  final String number;
  final String text;

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 26,
            height: 26,
            alignment: Alignment.center,
            decoration: const BoxDecoration(color: AppColors.pomegranateLight, shape: BoxShape.circle),
            child: Text(
              number,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.pomegranate),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text, style: const TextStyle(fontSize: 14, height: 1.55, color: AuthColors.body)),
          ),
        ],
      );
}

class _CommandBox extends StatelessWidget {
  const _CommandBox({required this.command});

  final String command;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsetsDirectional.only(start: 12, end: 4, top: 4, bottom: 4),
        decoration: BoxDecoration(color: AuthColors.codeBackground, borderRadius: BorderRadius.circular(10)),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: Row(
            children: [
              Expanded(
                child: SelectableText(
                  command,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 12.5, height: 1.5, color: AppColors.ink),
                ),
              ),
              IconButton(
                tooltip: 'نسخ الأمر',
                icon: const Icon(Icons.copy_rounded, size: 20),
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: command));
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context)
                    ..hideCurrentSnackBar()
                    ..showSnackBar(const SnackBar(content: Text('نُسخ الأمر.')));
                },
              ),
            ],
          ),
        ),
      );
}
