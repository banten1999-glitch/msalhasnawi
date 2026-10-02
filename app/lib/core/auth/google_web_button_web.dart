import 'package:flutter/widgets.dart';
import 'package:google_sign_in_web/web_only.dart' as gsi;

/// زر «المتابعة باستخدام Google» الرسمي على الويب (authenticate() غير مدعومة في المتصفح).
///
/// يجب استدعاؤه بعد اكتمال GoogleSignIn.instance.initialize، وإنشاؤه مرة واحدة فقط
/// (المكتبة تعيد رسم الزر كلما تغيّر كائن الإعدادات).
Widget renderGoogleWebButton({required double minimumWidth}) => gsi.renderButton(
      configuration: gsi.GSIButtonConfiguration(
        type: gsi.GSIButtonType.standard,
        theme: gsi.GSIButtonTheme.outline,
        size: gsi.GSIButtonSize.large,
        text: gsi.GSIButtonText.continueWith,
        shape: gsi.GSIButtonShape.pill,
        logoAlignment: gsi.GSIButtonLogoAlignment.left,
        minimumWidth: minimumWidth,
        locale: 'ar',
      ),
    );
