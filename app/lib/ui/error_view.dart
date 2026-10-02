import 'package:flutter/material.dart';

import '../core/api/api_exception.dart';
import '../theme/app_theme.dart';
import 'app_button.dart';
import 'ui_tokens.dart';

/// رسالة عربية لأي خطأ. رسائل الخادم عربية جاهزة؛ غيرها يُستبدل برسالة عامة واضحة.
String errorMessage(Object error) {
  if (error is ApiException) return error.message;
  return 'حدث خطأ غير متوقع في التطبيق. أعد المحاولة، وإن تكرر الخطأ فأبلغ المدير.';
}

/// لا فائدة من إعادة المحاولة مع هذه الأخطاء (صلاحية أو حساب غير مسموح).
bool isRetryUseful(Object error) {
  if (error is! ApiException) return true;
  return !const {ApiErrorCode.forbidden, ApiErrorCode.notAllowed}.contains(error.code);
}

/// أخطاء ملف Google Sheets التي يصلحها المدير من شاشة الإعدادات.
bool isSheetError(Object error) =>
    error is ApiException &&
    const {ApiErrorCode.sheetNotConfigured, ApiErrorCode.sheetUnreachable, ApiErrorCode.sheetSchema}
        .contains(error.code);

/// خطأ يتطلب الدخول من جديد (انتهت الجلسة أو تغيّرت الصلاحيات).
bool needsSignIn(Object error) => error is ApiException && error.requiresLogin;

/// عرض خطأ في مكان المحتوى: رسالة عربية + «إعادة المحاولة».
class ErrorView extends StatelessWidget {
  const ErrorView({
    super.key,
    required this.message,
    this.title = 'تعذّر تحميل البيانات',
    this.onRetry,
    this.actions = const [],
    this.compact = false,
  });

  /// يبني العرض من أي خطأ: يخفي «إعادة المحاولة» حين لا تفيد، ويضيف «فتح إعدادات الملف» لأخطاء الملف
  /// و«تسجيل الدخول من جديد» عند انتهاء الجلسة إن مُررت الدوال المناسبة.
  factory ErrorView.fromError(
    Object error, {
    Key? key,
    VoidCallback? onRetry,
    VoidCallback? onOpenSheetSettings,
    VoidCallback? onSignInAgain,
    String title = 'تعذّر تحميل البيانات',
    bool compact = false,
  }) {
    final actions = <Widget>[
      if (needsSignIn(error) && onSignInAgain != null)
        AppButton(label: 'تسجيل الدخول من جديد', icon: Icons.login, onPressed: onSignInAgain),
      if (isSheetError(error) && onOpenSheetSettings != null)
        AppButton(
          label: 'فتح إعدادات الملف',
          icon: Icons.table_chart_outlined,
          variant: AppButtonVariant.secondary,
          onPressed: onOpenSheetSettings,
        ),
    ];
    final retry = needsSignIn(error) || !isRetryUseful(error) ? null : onRetry;
    return ErrorView(
      key: key,
      message: errorMessage(error),
      title: title,
      onRetry: retry,
      actions: actions,
      compact: compact,
    );
  }

  final String title;
  final String message;
  final VoidCallback? onRetry;
  final List<Widget> actions;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: compact ? 56 : 80,
          height: compact ? 56 : 80,
          decoration: const BoxDecoration(color: UiColors.errorBg, shape: BoxShape.circle),
          child: Icon(Icons.cloud_off_outlined, size: compact ? 28 : 38, color: AppColors.error),
        ),
        const SizedBox(height: 14),
        Semantics(
          header: true,
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontFamily: AppFonts.display, fontSize: 19, fontWeight: FontWeight.w700, height: 1.35),
          ),
        ),
        const SizedBox(height: 6),
        Semantics(
          liveRegion: true,
          child: Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 15, color: AppColors.inkSecondary, height: 1.55),
          ),
        ),
        const SizedBox(height: 18),
        if (onRetry != null)
          AppButton(label: 'إعادة المحاولة', icon: Icons.refresh, onPressed: onRetry, expand: true),
        for (final a in actions) ...[const SizedBox(height: 10), SizedBox(width: double.infinity, child: a)],
      ],
    );
    return Center(
      child: SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: 24, vertical: compact ? 16 : 32),
        child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 420), child: content),
      ),
    );
  }
}
