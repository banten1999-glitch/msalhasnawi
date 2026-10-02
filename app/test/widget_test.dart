import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rumman_calculator/brand/animated_logo.dart';
import 'package:rumman_calculator/features/auth/auth_gate.dart';
import 'package:rumman_calculator/features/auth/setup_required_screen.dart';
import 'package:rumman_calculator/main.dart';

void main() {
  testWidgets('شاشة البداية تعرض الشعار والنص ثم تنتقل بعد 3 ثوانٍ', (tester) async {
    await tester.pumpWidget(const RummanApp());

    expect(find.byType(AnimatedLogo), findsOneWidget);
    expect(find.text('حاسبة الحسناوي'), findsOneWidget);
    expect(find.byType(AuthGate), findsNothing);

    await tester.pump(const Duration(milliseconds: 2900));
    expect(find.byType(AuthGate), findsNothing);

    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpAndSettle();
    expect(find.byType(AuthGate), findsOneWidget);
    // الاختبارات تُشغَّل دون API_URL ودون DEMO: تظهر شاشة إعداد الخادم.
    expect(find.byType(SetupRequiredScreen), findsOneWidget);
    expect(find.text('إعداد الخادم مطلوب'), findsOneWidget);
  });

  testWidgets('مع تقليل الحركة يظهر النص فورًا', (tester) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);

    await tester.pumpWidget(const RummanApp());
    await tester.pump();
    final opacity = tester.widget<AnimatedOpacity>(find.byType(AnimatedOpacity));
    expect(opacity.opacity, 1);
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
  });
}
