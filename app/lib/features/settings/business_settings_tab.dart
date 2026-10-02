import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../core/format/numbers.dart';
import '../../core/models/settings.dart';
import '../../ui/ui.dart';
import 'settings_widgets.dart';

/// تبويب «إعدادات العمل»: للعرض فقط من settings.get.
class BusinessSettingsTab extends StatefulWidget {
  const BusinessSettingsTab({super.key});

  @override
  State<BusinessSettingsTab> createState() => _BusinessSettingsTabState();
}

class _BusinessSettingsTabState extends State<BusinessSettingsTab> {
  BusinessSettings? _settings;
  Object? _error;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    unawaited(_load());
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final s = await AppScope.of(context).api.settings();
      if (mounted) setState(() => _settings = s);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  String _decimals(int n) => switch (n) {
        0 => 'بدون منازل عشرية',
        1 => 'منزلة واحدة',
        2 => 'منزلتان',
        _ => '$n منازل',
      };

  @override
  Widget build(BuildContext context) {
    final s = _settings;
    if (s == null) {
      if (_error != null) return ErrorView.fromError(_error!, onRetry: _load, title: 'تعذّر تحميل إعدادات العمل');
      return const LoadingSkeleton(tiles: 0, lines: 8, showHeaderCard: false);
    }
    return SettingsTabBody(
      onRefresh: _load,
      children: [
        AppCard(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const CardTitle('إعدادات العمل'),
              const SizedBox(height: 4),
              KeyValueRow(label: 'اسم النشاط', value: s.businessName, first: true),
              KeyValueRow(label: 'العملة', value: s.currency),
              KeyValueRow(label: 'رمز العملة', value: s.currencySymbol),
              KeyValueRow(label: 'المنطقة الزمنية', value: s.timezone, ltr: true),
              KeyValueRow(label: 'المنازل العشرية للمبالغ', value: _decimals(s.moneyDecimals)),
              KeyValueRow(label: 'المنازل العشرية للأوزان', value: _decimals(s.weightDecimals)),
              KeyValueRow(
                label: 'وزن الصندوق الفارغ',
                value: '${formatWeight(s.emptyBoxGrams, decimals: 3)} $kWeightUnit',
              ),
              KeyValueRow(
                label: 'بداية الموسم',
                value: s.seasonStart == null || s.seasonStart!.isEmpty ? 'غير محددة' : formatArabicDate(s.seasonStart),
              ),
            ],
          ),
        ),
        const InlineBanner(
          kind: BannerKind.info,
          message: 'هذه القيم للعرض فقط في هذه المرحلة، ويقرؤها الخادم من صفحة «الإعدادات» في الملف المركزي. '
              'تعديلها من التطبيق سيتاح في مرحلة لاحقة.',
        ),
      ],
    );
  }
}
