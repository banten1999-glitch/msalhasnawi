import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rumman_calculator/brand/animated_logo.dart';
import 'package:rumman_calculator/main.dart';
import 'package:rumman_calculator/screens/home_placeholder.dart';

void main() {
  testWidgets('شاشة البداية تعرض الشعار والنص ثم تنتقل بعد 3 ثوانٍ', (tester) async {
    await tester.pumpWidget(const RummanApp());

    expect(find.byType(AnimatedLogo), findsOneWidget);
    expect(find.text('حاسبة الحسناوي'), findsOneWidget);
    expect(find.byType(HomePlaceholder), findsNothing);

    await tester.pump(const Duration(milliseconds: 2900));
    expect(find.byType(HomePlaceholder), findsNothing);

    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpAndSettle();
    expect(find.byType(HomePlaceholder), findsOneWidget);
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
