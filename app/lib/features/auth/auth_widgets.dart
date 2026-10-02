import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../config/app_config.dart';
import '../../theme/app_theme.dart';

/// ألوان شاشات الدخول كما في التصميم المعتمد.
abstract final class AuthColors {
  static const cardBorder = Color(0xFFECE4D8);
  static const body = Color(0xFF3D3530);
  static const codeBackground = Color(0xFFF3EEE6);
  static const errorBackground = Color(0xFFFDECEA);
  static const errorText = Color(0xFF8F1D14);
}

/// إطار شاشات الدخول: خلفية عاجية، محتوى في الوسط، وأزرار في الأسفل، وعرض أقصى مناسب للويب.
class AuthScaffold extends StatelessWidget {
  const AuthScaffold({super.key, required this.body, required this.footer, this.top});

  /// يظهر أعلى الشاشة (مثل شارة «وضع تجريبي»).
  final Widget? top;

  /// المحتوى في منتصف الشاشة.
  final List<Widget> body;

  /// الأزرار والبطاقات في أسفل الشاشة.
  final List<Widget> footer;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.ivory,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, viewport) => SingleChildScrollView(
            child: Center(
              child: ConstrainedBox(
                // الأزرار في أسفل الشاشة والمحتوى في منتصف المساحة الباقية؛ ويمرر المحتوى إن طال.
                constraints: BoxConstraints(maxWidth: 440, minHeight: viewport.maxHeight),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(child: top ?? const SizedBox.shrink()),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: Column(children: body),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (var i = 0; i < footer.length; i++) ...[
                            if (i > 0) const SizedBox(height: 12),
                            footer[i],
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// عنوان الشاشة بخط Readex Pro.
class AuthTitle extends StatelessWidget {
  const AuthTitle(this.text, {super.key, this.size = 30});

  final String text;
  final double size;

  @override
  Widget build(BuildContext context) => Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontFamily: AppFonts.display,
          fontWeight: FontWeight.w700,
          fontSize: size,
          height: 1.3,
          color: AppColors.ink,
        ),
      );
}

/// نص شرح رمادي في المنتصف.
class AuthSubtitle extends StatelessWidget {
  const AuthSubtitle(this.text, {super.key, this.size = 16});

  final String text;
  final double size;

  @override
  Widget build(BuildContext context) => ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 320),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: size, height: 1.6, color: AppColors.inkMuted),
        ),
      );
}

/// «الإصدار 1.0.0»
class AuthVersionText extends StatelessWidget {
  const AuthVersionText({super.key});

  @override
  Widget build(BuildContext context) => const Text(
        'الإصدار ${AppConfig.appVersion}',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 12.5, color: AppColors.inkMuted),
      );
}

/// بطاقة معلومة صغيرة بأيقونة.
class AuthInfoCard extends StatelessWidget {
  const AuthInfoCard({
    super.key,
    required this.icon,
    required this.text,
    this.iconColor = AppColors.leaf,
    this.background = Colors.white,
    this.foreground = AuthColors.body,
    this.bordered = true,
  });

  final IconData icon;
  final String text;
  final Color iconColor;
  final Color background;
  final Color foreground;
  final bool bordered;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(14),
          border: bordered ? Border.all(color: AuthColors.cardBorder) : null,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Icon(icon, size: 20, color: iconColor),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(text, style: TextStyle(fontSize: 13.5, height: 1.55, color: foreground)),
            ),
          ],
        ),
      );
}

/// شريط خطأ واضح فوق الأزرار. يُقرأ تلقائيًا لقارئ الشاشة.
class AuthErrorBanner extends StatelessWidget {
  const AuthErrorBanner(this.message, {super.key});

  final String message;

  @override
  Widget build(BuildContext context) => Semantics(
        liveRegion: true,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: AuthColors.errorBackground,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 2),
                child: Icon(Icons.error_outline, size: 20, color: AppColors.error),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(fontSize: 14, height: 1.55, color: AuthColors.errorText),
                ),
              ),
            ],
          ),
        ),
      );
}

/// شارة صغيرة ملوّنة.
class AuthChip extends StatelessWidget {
  const AuthChip({super.key, required this.label, required this.background, required this.foreground, this.icon});

  final String label;
  final Color background;
  final Color foreground;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => Container(
        height: 28,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(999)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[Icon(icon, size: 15, color: foreground), const SizedBox(width: 6)],
            Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: foreground)),
          ],
        ),
      );
}

/// زر أساسي كبير (رمّاني) مع حالة انتظار.
class AuthPrimaryButton extends StatelessWidget {
  const AuthPrimaryButton({super.key, required this.label, required this.onPressed, this.icon, this.busy = false});

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool busy;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 54,
        child: FilledButton(
          onPressed: busy ? null : onPressed,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.pomegranate,
            foregroundColor: Colors.white,
            disabledBackgroundColor: AppColors.pomegranate.withValues(alpha: 0.55),
            disabledForegroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            textStyle: const TextStyle(fontFamily: AppFonts.body, fontSize: 16, fontWeight: FontWeight.w700),
          ),
          child: _ButtonContent(label: label, icon: icon, busy: busy, color: Colors.white),
        ),
      );
}

/// زر ثانوي أبيض بإطار.
class AuthSecondaryButton extends StatelessWidget {
  const AuthSecondaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.leading,
    this.busy = false,
    this.busyLabel,
    this.height = 54,
    this.fontSize = 16,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  /// عنصر يسبق النص بدل الأيقونة (مثل شعار Google).
  final Widget? leading;
  final bool busy;
  final String? busyLabel;
  final double height;
  final double fontSize;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: height,
        child: OutlinedButton(
          onPressed: busy ? null : onPressed,
          style: OutlinedButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: AppColors.ink,
            disabledForegroundColor: AppColors.inkSecondary,
            side: const BorderSide(color: AppColors.border, width: 1.5),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            textStyle: TextStyle(fontFamily: AppFonts.body, fontSize: fontSize, fontWeight: FontWeight.w700),
            elevation: 0,
          ),
          child: _ButtonContent(
            label: busy ? (busyLabel ?? label) : label,
            icon: icon,
            leading: leading,
            busy: busy,
            color: AppColors.ink,
          ),
        ),
      );
}

class _ButtonContent extends StatelessWidget {
  const _ButtonContent({required this.label, required this.busy, required this.color, this.icon, this.leading});

  final String label;
  final bool busy;
  final Color color;
  final IconData? icon;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final Widget? lead = busy
        ? SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2.4, color: color))
        : (leading ?? (icon == null ? null : Icon(icon, size: 22)));
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (lead != null) ...[lead, const SizedBox(width: 12)],
        Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
      ],
    );
  }
}

/// شعار Google بالألوان الأربعة (مطلوب في زر «المتابعة باستخدام Google»).
class GoogleGLogo extends StatelessWidget {
  const GoogleGLogo({super.key, this.size = 22});

  final double size;

  static const _svg = '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 48 48">'
      '<path fill="#EA4335" d="M24 9.5c3.54 0 6.71 1.22 9.21 3.6l6.85-6.85C35.9 2.38 30.47 0 24 0 14.62 0 6.51 5.38 2.56 13.22l7.98 6.19C12.43 13.72 17.74 9.5 24 9.5z"/>'
      '<path fill="#4285F4" d="M46.98 24.55c0-1.57-.15-3.09-.38-4.55H24v9.02h12.94c-.58 2.96-2.26 5.48-4.78 7.18l7.73 6c4.51-4.18 7.09-10.36 7.09-17.65z"/>'
      '<path fill="#FBBC05" d="M10.53 28.59c-.48-1.45-.76-2.99-.76-4.59s.27-3.14.76-4.59l-7.98-6.19C.92 16.46 0 20.12 0 24c0 3.88.92 7.54 2.56 10.78l7.97-6.19z"/>'
      '<path fill="#34A853" d="M24 48c6.48 0 11.93-2.13 15.89-5.81l-7.73-6c-2.15 1.45-4.92 2.3-8.16 2.3-6.26 0-11.57-4.22-13.47-9.91l-7.98 6.19C6.51 42.62 14.62 48 24 48z"/>'
      '</svg>';

  @override
  Widget build(BuildContext context) => SvgPicture.string(_svg, width: size, height: size, excludeFromSemantics: true);
}

/// دائرة ملونة بأيقونة كبيرة أعلى شاشات الحالة.
class AuthIconBadge extends StatelessWidget {
  const AuthIconBadge({super.key, required this.icon, required this.background, required this.foreground});

  final IconData icon;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) => Container(
        width: 96,
        height: 96,
        decoration: BoxDecoration(color: background, shape: BoxShape.circle),
        child: Icon(icon, size: 48, color: foreground),
      );
}
