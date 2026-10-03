import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rumman_calculator/brand/animated_logo.dart';
import 'package:rumman_calculator/core/api/unconfigured_backend_api.dart';
import 'package:rumman_calculator/core/auth/google_auth_controller.dart';
import 'package:rumman_calculator/core/auth/session_store.dart';
import 'package:rumman_calculator/features/auth/auth_gate.dart';
import 'package:rumman_calculator/features/auth/setup_required_screen.dart';
import 'package:rumman_calculator/main.dart';

import 'support/auth_fakes.dart';

/// التطبيق كما يبدو دون عنوان خادم (البناء الافتراضي يضمّن الرابط المنشور، فنحقن هنا حالة «غير مضبوط»).
RummanApp unconfiguredApp() {
  final api = UnconfiguredBackendApi();
  return RummanApp(
    api: api,
    auth: GoogleAuthController(api: api, google: FakeGoogleSignIn(), store: SessionStore(), configured: false),
  );
}

void main() {
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  testWidgets('شاشة البداية تعرض الشعار والنص ثم تنتقل بعد 3 ثوانٍ', (tester) async {
    await tester.pumpWidget(unconfiguredApp());

    expect(find.byType(AnimatedLogo), findsOneWidget);
    expect(find.text('حاسبة الحسناوي'), findsOneWidget);
    expect(find.byType(AuthGate), findsNothing);

    await tester.pump(const Duration(milliseconds: 2900));
    expect(find.byType(AuthGate), findsNothing);

    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpAndSettle();
    expect(find.byType(AuthGate), findsOneWidget);
    // دون عنوان خادم ودون DEMO: تظهر شاشة إعداد الخادم.
    expect(find.byType(SetupRequiredScreen), findsOneWidget);
    expect(find.text('إعداد الخادم مطلوب'), findsOneWidget);
  });

  testWidgets('مع تقليل الحركة يظهر النص فورًا', (tester) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);

    await tester.pumpWidget(unconfiguredApp());
    await tester.pump();
    final opacity = tester.widget<AnimatedOpacity>(find.byType(AnimatedOpacity));
    expect(opacity.opacity, 1);
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
  });
}
