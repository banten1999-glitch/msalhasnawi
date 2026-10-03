import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rumman_calculator/app/app_scope.dart';
import 'package:rumman_calculator/core/api/backend_api.dart';
import 'package:rumman_calculator/core/auth/auth_controller.dart';
import 'package:rumman_calculator/core/sync/data_changes.dart';
import 'package:rumman_calculator/core/sync/outbox.dart';
import 'package:rumman_calculator/theme/app_theme.dart';

const phoneSize = Size(390, 844);
const wideSize = Size(1280, 900);

bool _fontsLoaded = false;

/// يحمّل خطوط التطبيق الحقيقية حتى تكون أطوال النصوص العربية (وأي فيض في التخطيط) واقعية.
Future<void> loadAppFonts() async {
  if (_fontsLoaded) return;
  _fontsLoaded = true;
  ByteData bytes(String name) => ByteData.sublistView(File('assets/fonts/$name').readAsBytesSync());
  final plex = FontLoader(AppFonts.body);
  for (final w in ['Regular', 'Medium', 'SemiBold', 'Bold']) {
    plex.addFont(Future.value(bytes('IBMPlexSansArabic-$w.ttf')));
  }
  final readex = FontLoader(AppFonts.display)
    ..addFont(Future.value(bytes('ReadexPro-Regular.ttf')))
    ..addFont(Future.value(bytes('ReadexPro-Bold.ttf')));
  await Future.wait([plex.load(), readex.load()]);
}

/// يبني [child] داخل التطبيق: السمة، العربية، الاتجاه من اليمين لليسار، و[AppScope].
///
/// [outbox] افتراضيًا قائمة في الذاكرة دون مستخدم مربوط (submit يرسل مباشرة ويرمي أخطاء الاتصال).
Future<void> pumpTestApp(
  WidgetTester tester,
  Widget child, {
  required BackendApi api,
  required AuthController auth,
  Outbox? outbox,
  DataChanges? changes,
  Size size = phoneSize,
  bool settle = true,
}) async {
  final box = outbox ?? Outbox(api: api, storage: MemoryOutboxStorage());
  if (outbox == null) addTearDown(box.dispose);
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    AppScope(
      api: api,
      auth: auth,
      outbox: box,
      changes: changes ?? DataChanges(),
      child: MaterialApp(
        theme: buildAppTheme(),
        debugShowCheckedModeBanner: false,
        locale: const Locale('ar'),
        supportedLocales: const [Locale('ar')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        builder: (context, child) => Directionality(textDirection: TextDirection.rtl, child: child!),
        home: child,
      ),
    ),
  );
  if (settle) await tester.pumpAndSettle();
}

/// نص كامل لعنصر Text أو Text.rich (مفيد للأرقام مع وحداتها).
Finder findRichText(String contains) => find.byWidgetPredicate(
      (w) => w is Text && (w.data ?? w.textSpan?.toPlainText() ?? '').contains(contains),
      description: 'Text containing "$contains"',
    );
