import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../core/format/numbers.dart';
import '../../core/models/sheet_status.dart';
import '../../theme/app_theme.dart';
import '../../ui/ui.dart';
import '../dashboard/dashboard_format.dart';
import 'change_sheet_dialog.dart';
import 'settings_widgets.dart';

enum _Busy { none, test, check, repair }

/// تبويب «Google Sheets»: حالة الملف المركزي، فحص الصفحات والأعمدة، الإصلاح، وتغيير الملف.
class SheetsTab extends StatefulWidget {
  const SheetsTab({super.key});

  @override
  State<SheetsTab> createState() => _SheetsTabState();
}

class _SheetsTabState extends State<SheetsTab> {
  SheetStatus? _status;
  Object? _loadError;
  _Busy _busy = _Busy.none;

  /// بعد «فحص الأعمدة» تُبرز الصفحات التي فيها مشكلة.
  bool _highlight = false;

  /// رسالة نتيجة آخر إجراء.
  ({BannerKind kind, String? title, String message})? _notice;

  /// تنبيه الخادم بعد ربط ملف آخر.
  String? _connectWarning;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    unawaited(_load());
  }

  Future<SheetStatus?> _fetch() async {
    try {
      final s = await AppScope.of(context).api.sheetStatus();
      if (!mounted) return null;
      setState(() {
        _status = s;
        _loadError = null;
      });
      return s;
    } catch (e) {
      if (!mounted) return null;
      setState(() {
        if (_status == null) {
          _loadError = e;
        } else {
          _notice = (kind: BannerKind.error, title: 'تعذّر الاتصال بالخادم', message: errorMessage(e));
        }
      });
      return null;
    }
  }

  Future<void> _load() async {
    setState(() => _loadError = null);
    await _fetch();
  }

  bool _opened(SheetStatus s) => s.configured && (s.title != null || s.sheets.isNotEmpty);

  Future<void> _testConnection() async {
    setState(() {
      _busy = _Busy.test;
      _notice = null;
    });
    final s = await _fetch();
    if (!mounted) return;
    setState(() {
      _busy = _Busy.none;
      if (s == null) return;
      if (!s.configured) {
        _notice = (
          kind: BannerKind.warning,
          title: 'لا يوجد ملف مربوط',
          message: 'الخادم يعمل لكن لم يُربط به ملف Google Sheets بعد. اضغط «ربط ملف…» في الأسفل.',
        );
      } else if (!_opened(s)) {
        _notice = (
          kind: BannerKind.error,
          title: 'تعذّر فتح الملف',
          message: 'الخادم يعمل لكنه لم يستطع فتح الملف. تأكد أن الملف موجود وأن الحساب '
              '${s.connectedAs ?? 'المتصل'} لديه صلاحية «محرر» عليه، ثم أعد الاختبار.',
        );
      } else {
        _notice = (
          kind: BannerKind.success,
          title: 'الاتصال يعمل',
          message: 'وصل التطبيق إلى الخادم، وفتح الخادم الملف «${s.title ?? s.spreadsheetId ?? ''}».',
        );
      }
    });
  }

  Future<void> _checkColumns() async {
    setState(() {
      _busy = _Busy.check;
      _notice = null;
    });
    final s = await _fetch();
    if (!mounted) return;
    setState(() {
      _busy = _Busy.none;
      if (s == null) return;
      _highlight = true;
      _notice = _schemaNotice(s);
    });
  }

  ({BannerKind kind, String? title, String message}) _schemaNotice(SheetStatus s) {
    if (!_opened(s)) {
      return (
        kind: BannerKind.error,
        title: 'لا يمكن فحص الأعمدة',
        message: 'يجب أولًا ربط ملف يستطيع الخادم فتحه.',
      );
    }
    final problems = s.sheets.where((x) => !x.ok).toList();
    if (problems.isEmpty) {
      return (kind: BannerKind.success, title: 'الملف سليم', message: 'كل الصفحات والأعمدة المطلوبة موجودة.');
    }
    final parts = [
      for (final p in problems)
        p.exists ? 'أعمدة ${_quoted(p.missingColumns)} في «${p.title}»' : 'صفحة «${p.title}»',
    ];
    return (
      kind: BannerKind.warning,
      title: 'ينقص الملف ${_things(problems.length)}',
      message: '${parts.join('؛ ')}. اضغط «إصلاح الملف» لإضافتها دون حذف أي بيانات.',
    );
  }

  static String _quoted(List<String> cols) => cols.map((c) => '«$c»').join('، ');

  /// «شيء واحد»، «شيئان»، «3 أشياء»، «11 شيئًا».
  static String _things(int n) {
    if (n == 1) return 'شيء واحد';
    if (n == 2) return 'شيئان';
    final mod = n % 100;
    if (mod >= 3 && mod <= 10) return '$n أشياء';
    return '$n شيئًا';
  }

  Future<void> _repair() async {
    setState(() {
      _busy = _Busy.repair;
      _notice = null;
    });
    try {
      final s = await AppScope.of(context).api.sheetRepair();
      if (!mounted) return;
      setState(() {
        _status = s;
        _busy = _Busy.none;
        _highlight = true;
        _notice = s.needsRepair
            ? _schemaNotice(s)
            : (
                kind: BannerKind.success,
                title: 'اكتمل الإصلاح',
                message: 'أُنشئت الصفحات والأعمدة الناقصة وأُعيد تنسيق الملف دون حذف أي بيانات.',
              );
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = _Busy.none;
        _notice = (kind: BannerKind.error, title: 'تعذّر إصلاح الملف', message: errorMessage(e));
      });
    }
  }

  Future<void> _changeFile() async {
    final result = await showChangeSheetDialog(context, current: _status);
    if (result == null || !mounted) return;
    setState(() {
      _status = result;
      _highlight = true;
      _connectWarning = result.warning ?? 'البيانات القديمة لا تُنقل تلقائيًا إلى الملف الجديد.';
      _notice = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = _status;
    if (s == null) {
      if (_loadError != null) return ErrorView.fromError(_loadError!, onRetry: _load, title: 'تعذّر قراءة حالة الملف');
      return const LoadingSkeleton(tiles: 2, lines: 6);
    }
    final notice = _notice;
    return SettingsTabBody(
      onRefresh: _fetch,
      children: [
        if (_connectWarning != null)
          InlineBanner(kind: BannerKind.warning, title: 'تم ربط الملف الجديد', message: _connectWarning!),
        if (notice != null) InlineBanner(kind: notice.kind, title: notice.title, message: notice.message),
        _fileCard(s),
        _sheetsCard(s),
        _activityCard(s),
        _changeCard(s),
      ],
    );
  }

  // ------------------------------------------------------------------ الملف

  Widget _fileCard(SheetStatus s) {
    final opened = _opened(s);
    final link = s.url ?? s.spreadsheetId;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(color: AppColors.leafLight, borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.table_chart_outlined, color: AppColors.leaf),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const CardTitle('الملف المركزي'),
                    Text(
                      s.title ?? (s.configured ? 'تعذّر فتح الملف' : 'لم يُربط ملف بعد'),
                      style: UiText.small,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _ConnectionLabel(connected: opened),
            ],
          ),
          const SizedBox(height: 14),
          LabeledField(
            label: 'رابط الملف أو معرّفه',
            child: link == null
                ? const Text('لا يوجد', style: UiText.muted)
                : CopyableValue(value: link, copyTooltip: 'نسخ رابط الملف', copiedMessage: 'نُسخ رابط الملف.'),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: AppColors.ivory, borderRadius: BorderRadius.circular(12)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('الحساب المتصل بالملف', style: UiText.fieldLabel),
                const SizedBox(height: 6),
                if (s.connectedAs != null)
                  CopyableValue(value: s.connectedAs!, copyTooltip: 'نسخ البريد', copiedMessage: 'نُسخ البريد.')
                else
                  const Text('لم يُعرف بعد', style: UiText.muted),
                const SizedBox(height: 6),
                const Text(
                  'هذا حساب Google الذي يعمل به الخادم، وهو الحساب الوحيد الذي يفتح الملف ويكتب فيه. '
                  'الموظفون لا يحتاجون أي وصول إلى الملف: التطبيق يتحقق من صلاحياتهم، ثم يكتب الخادم نيابة عنهم.',
                  style: TextStyle(fontSize: 12.5, color: AppColors.inkMuted, height: 1.55),
                ),
              ],
            ),
          ),
          if (s.timezone != null) ...[
            const SizedBox(height: 8),
            Text('المنطقة الزمنية للملف: ${s.timezone}', style: UiText.small),
          ],
          const SizedBox(height: 14),
          ResponsiveGrid(
            minTileWidth: 150,
            maxColumns: 2,
            minColumns: 2,
            spacing: 8,
            children: [
              AppButton(
                label: 'اختبار الاتصال',
                icon: Icons.sync,
                height: 48,
                variant: AppButtonVariant.secondary,
                busy: _busy == _Busy.test,
                busyLabel: 'جارٍ الاختبار',
                onPressed: _busy == _Busy.none ? _testConnection : null,
              ),
              AppButton(
                label: 'فحص الأعمدة',
                icon: Icons.fact_check_outlined,
                height: 48,
                variant: AppButtonVariant.secondary,
                busy: _busy == _Busy.check,
                busyLabel: 'جارٍ الفحص',
                onPressed: _busy == _Busy.none ? _checkColumns : null,
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------------ الصفحات

  Widget _sheetsCard(SheetStatus s) {
    final opened = _opened(s);
    return AppCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CardTitle(
            'الصفحات داخل الملف',
            trailing: s.checkedAt == null ? null : Text('فحص ${relativeDateTime(s.checkedAt)}', style: UiText.small),
          ),
          const SizedBox(height: 6),
          if (!opened || s.sheets.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text('لا يمكن فحص الصفحات قبل ربط ملف يستطيع الخادم فتحه.', style: UiText.muted),
            )
          else ...[
            for (final sheet in s.sheets) _SheetRow(sheet: sheet, highlight: _highlight),
            Container(
              decoration: const BoxDecoration(border: Border(top: BorderSide(color: UiColors.divider))),
              padding: const EdgeInsets.only(top: 12, bottom: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AppButton(
                    // الاسم نفسه الذي تذكره رسائل الخادم («اضغط إصلاح الملف»).
                    label: 'إصلاح الملف',
                    icon: Icons.build_outlined,
                    variant: AppButtonVariant.success,
                    busy: _busy == _Busy.repair,
                    busyLabel: 'جارٍ الإصلاح',
                    onPressed: _busy == _Busy.none ? _repair : null,
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'يُنشئ الصفحات والأعمدة الناقصة فقط. لا تُحذف أو تُستبدل أي بيانات موجودة.',
                    textAlign: TextAlign.center,
                    style: UiText.small,
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ------------------------------------------------------------------ آخر نشاط

  Widget _activityCard(SheetStatus s) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const CardTitle('آخر نشاط على الملف'),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(color: AppColors.ivory, borderRadius: BorderRadius.circular(12)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('آخر كتابة ناجحة', style: UiText.small),
                Text(
                  s.lastWriteAt == null ? 'لا توجد كتابة مسجلة بعد' : relativeDateTime(s.lastWriteAt),
                  style: const TextStyle(fontWeight: FontWeight.w700, height: 1.5),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          if (s.lastErrorMessage == null)
            const IconNote(
              icon: Icons.check_circle_outline,
              text: 'لا توجد أخطاء مسجلة.',
              color: AppColors.leaf,
              background: null,
            )
          else
            InlineBanner(
              kind: BannerKind.error,
              title: s.lastErrorAt == null ? 'آخر خطأ' : 'آخر خطأ · ${relativeDateTime(s.lastErrorAt)}',
              message: s.lastErrorMessage!,
            ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------------ تغيير الملف

  Widget _changeCard(SheetStatus s) {
    final connected = s.configured;
    return AppCard(
      color: UiColors.warningBg,
      borderColor: UiColors.amberBorder,
      borderWidth: 1.5,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: AppColors.amber, size: 20),
              const SizedBox(width: 8),
              Text(
                connected ? 'تغيير الملف' : 'ربط ملف',
                style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.amber, fontSize: 15),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'الربط بملف آخر لا ينقل البيانات القديمة تلقائيًا. بعد التغيير تقرأ كل الأجهزة من الملف الجديد فقط وتكتب فيه.',
            style: TextStyle(fontSize: 13.5, height: 1.55),
          ),
          const SizedBox(height: 10),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: AppButton(
              label: connected ? 'تغيير الملف…' : 'ربط ملف…',
              height: 48,
              variant: AppButtonVariant.secondary,
              foreground: AppColors.amber,
              borderColor: UiColors.amberBorder,
              onPressed: _busy == _Busy.none ? _changeFile : null,
            ),
          ),
        ],
      ),
    );
  }
}

class _ConnectionLabel extends StatelessWidget {
  const _ConnectionLabel({required this.connected});

  final bool connected;

  @override
  Widget build(BuildContext context) {
    final color = connected ? AppColors.leaf : AppColors.error;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 5),
        Text(
          connected ? 'متصل' : 'غير متصل',
          style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: color),
        ),
      ],
    );
  }
}

class _SheetRow extends StatelessWidget {
  const _SheetRow({required this.sheet, required this.highlight});

  final SheetCheck sheet;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final s = sheet;
    final (String state, Color color, IconData? icon) = !s.exists
        ? ('غير موجودة', AppColors.error, Icons.error_outline)
        : s.missingColumns.isNotEmpty
            ? ('ناقصة', AppColors.amber, Icons.warning_amber_rounded)
            : ('سليمة', AppColors.leaf, null);
    final detail = !s.exists
        ? 'لا توجد صفحة بهذا الاسم'
        : s.missingColumns.isNotEmpty
            ? '${s.missingColumns.length == 1 ? 'عمود ناقص' : 'أعمدة ناقصة'}: ${s.missingColumns.map((c) => '«$c»').join('، ')}'
            : 'السجلات: ${formatCount(s.rows)}';
    final emphasize = highlight && !s.ok;
    return Container(
      decoration: BoxDecoration(
        color: emphasize ? (s.exists ? AppColors.amberLight : UiColors.errorBg) : null,
        border: const Border(top: BorderSide(color: UiColors.divider)),
      ),
      padding: EdgeInsets.symmetric(vertical: 10, horizontal: emphasize ? 8 : 0),
      child: Semantics(
        container: true,
        label: '${s.title}: $state',
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(s.title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, height: 1.45)),
                  Text(
                    detail,
                    style: TextStyle(
                      fontSize: 12.5,
                      height: 1.45,
                      color: s.ok ? AppColors.inkMuted : color,
                      fontWeight: s.ok ? FontWeight.w400 : FontWeight.w600,
                    ),
                  ),
                  if (s.extraColumns.isNotEmpty)
                    Text(
                      'أعمدة إضافية لا يستخدمها التطبيق (تبقى كما هي): ${s.extraColumns.map((c) => '«$c»').join('، ')}',
                      style: UiText.small,
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[Icon(icon, size: 16, color: color), const SizedBox(width: 4)],
                Text(state, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: color)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
