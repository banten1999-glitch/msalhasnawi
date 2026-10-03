// عناصر مشتركة بين شاشات البرادات (خاصة بهذا القسم).
import 'package:flutter/material.dart';

import '../../core/api/api_exception.dart';
import '../../core/format/numbers.dart';
import '../../core/models/dashboard.dart';
import '../../theme/app_theme.dart';
import '../../ui/ui.dart';
import 'cooler_format.dart';

/// الشريط العلوي لصفحات القسم المفتوحة فوق الواجهة الرئيسية.
PreferredSizeWidget coolerAppBar(String title, {String? subtitle, List<Widget> actions = const []}) => AppBar(
      backgroundColor: AppColors.ivory,
      surfaceTintColor: Colors.transparent,
      scrolledUnderElevation: 0,
      toolbarHeight: 64,
      titleSpacing: 4,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(title, style: UiText.pageTitle, maxLines: 1, overflow: TextOverflow.ellipsis),
          if (subtitle != null && subtitle.isNotEmpty)
            Text(subtitle, style: UiText.small, maxLines: 1, overflow: TextOverflow.ellipsis),
        ],
      ),
      actions: [...actions, const SizedBox(width: 4)],
    );

/// يفتح [child] كلوحة من الأسفل على الهاتف، وكنافذة في المنتصف على الشاشات العريضة.
Future<T?> showAdaptiveSheet<T>(BuildContext context, Widget child, {double maxWidth = 560}) {
  if (isWideLayout(context)) {
    return showDialog<T>(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: ConstrainedBox(constraints: BoxConstraints(maxWidth: maxWidth, maxHeight: 820), child: child),
      ),
    );
  }
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.white,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (context) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: child,
    ),
  );
}

/// شريط الأرقام الأربعة للبراد: المزارعون، العمليات، الصناديق، الوزن.
class CoolerStatsStrip extends StatelessWidget {
  const CoolerStatsStrip({super.key, required this.cooler});

  final CoolerSummary cooler;

  @override
  Widget build(BuildContext context) {
    final c = cooler;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
      decoration: BoxDecoration(color: AppColors.ivory, borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          _stat(formatCount(c.farmers), 'مزارعين'),
          _stat(formatCount(c.purchases), 'عمليات'),
          _stat(formatCount(c.boxes), 'صندوق'),
          _stat(kgShort(c.weightGrams), 'كغ'),
        ],
      ),
    );
  }

  Widget _stat(String value, String unit) => Expanded(
        child: Column(
          children: [
            Text(value, textAlign: TextAlign.center, maxLines: 1, style: UiText.number(size: 17)),
            Text(unit, style: const TextStyle(fontSize: 12, color: AppColors.inkMuted, height: 1.3)),
          ],
        ),
      );
}

/// تسمية صغيرة فوق مبلغ (داخل بطاقة).
class MoneyFigure extends StatelessWidget {
  const MoneyFigure({
    super.key,
    required this.label,
    required this.piasters,
    this.color = AppColors.ink,
    this.fontSize = 16,
    this.note,
  });

  final String label;
  final int piasters;
  final Color color;
  final double fontSize;
  final String? note;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: UiText.small.copyWith(color: color == AppColors.ink ? AppColors.inkMuted : color)),
          MoneyText(piasters, fontSize: fontSize, color: color, unitFontSize: 12),
          if (note != null)
            Text(note!, style: const TextStyle(fontSize: 11.5, color: AppColors.inkMuted, height: 1.35)),
        ],
      ),
    );
  }
}

/// مؤشرات البراد الكاملة (تفاصيل البراد ومراجعة التقفيل).
List<Widget> coolerKpiTiles(CoolerSummary c, {double valueSize = 20}) => [
      KpiTile(label: 'مزارعون مختلفون', value: formatCount(c.farmers), valueSize: valueSize),
      KpiTile(label: 'عمليات الشراء', value: formatCount(c.purchases), valueSize: valueSize),
      KpiTile(label: 'الصناديق', value: formatCount(c.boxes), valueSize: valueSize),
      KpiTile(label: 'وزن الرمان', value: kgShort(c.weightGrams), unit: kWeightUnit, valueSize: valueSize),
      KpiTile(label: 'قيمة الرمان', value: formatMoney(c.valuePiasters), unit: kCurrencySymbol, valueSize: valueSize),
      KpiTile(
        label: 'المدفوع',
        value: formatMoney(c.paidPiasters),
        unit: kCurrencySymbol,
        accent: KpiAccent.paid,
        valueSize: valueSize,
      ),
      KpiTile(
        label: 'المتبقي للمزارعين',
        value: formatMoney(c.remainingPiasters),
        unit: kCurrencySymbol,
        accent: KpiAccent.remaining,
        valueSize: valueSize,
      ),
      KpiTile(
        label: 'تكلفة التعبئة المعتمدة',
        value: formatMoney(c.packagingApprovedPiasters),
        unit: kCurrencySymbol,
        valueSize: valueSize,
        note: c.packagingLatePiasters > 0 ? 'منها متأخرة\u00A0${formatMoney(c.packagingLatePiasters)}' : null,
      ),
      KpiTile(
        label: 'إجمالي تكلفة البراد',
        value: formatMoney(c.totalCostPiasters),
        unit: kCurrencySymbol,
        valueSize: valueSize,
        note: 'الرمان + التعبئة المعتمدة',
      ),
      KpiTile(
        label: 'متوسط سعر الكيلو',
        value: formatMoney(c.avgPricePerKgPiasters),
        unit: '$kCurrencySymbol/كغ',
        valueSize: valueSize,
        note: 'مرجّح بالوزن',
      ),
    ];

/// شبكة المؤشرات: عمودان على الهاتف، وحتى خمسة على الشاشات العريضة.
class CoolerKpiGrid extends StatelessWidget {
  const CoolerKpiGrid({super.key, required this.cooler, this.wide = false});

  final CoolerSummary cooler;
  final bool wide;

  @override
  Widget build(BuildContext context) => ResponsiveGrid(
        minTileWidth: wide ? 190 : 150,
        maxColumns: wide ? 5 : 3,
        minColumns: 2,
        spacing: wide ? 12 : 10,
        children: coolerKpiTiles(cooler, valueSize: wide ? 21 : 19),
      );
}

/// نافذة سبب مطلوب (إلغاء عملية، إعادة فتح براد). [onSubmit] يرسل الطلب ويرمي [ApiException] عند الرفض،
/// فتبقى النافذة مفتوحة برسالة الخادم. تعيد true بعد النجاح فقط.
Future<bool> showReasonDialog(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  required Future<void> Function(String reason) onSubmit,
  String fieldLabel = 'السبب',
  String hint = 'اكتب السبب بوضوح',
  bool destructive = false,
  IconData? icon,
}) async {
  final ok = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _ReasonDialog(
      title: title,
      message: message,
      confirmLabel: confirmLabel,
      onSubmit: onSubmit,
      fieldLabel: fieldLabel,
      hint: hint,
      destructive: destructive,
      icon: icon,
    ),
  );
  return ok ?? false;
}

class _ReasonDialog extends StatefulWidget {
  const _ReasonDialog({
    required this.title,
    required this.message,
    required this.confirmLabel,
    required this.onSubmit,
    required this.fieldLabel,
    required this.hint,
    required this.destructive,
    this.icon,
  });

  final String title;
  final String message;
  final String confirmLabel;
  final Future<void> Function(String reason) onSubmit;
  final String fieldLabel;
  final String hint;
  final bool destructive;
  final IconData? icon;

  @override
  State<_ReasonDialog> createState() => _ReasonDialogState();
}

class _ReasonDialogState extends State<_ReasonDialog> {
  final _reason = TextEditingController();
  bool _busy = false;
  String? _fieldError;
  String? _error;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    final reason = _reason.text.trim();
    if (reason.isEmpty) {
      setState(() => _fieldError = '«${widget.fieldLabel}» مطلوب. اكتب سببًا واضحًا ثم أعد المحاولة.');
      return;
    }
    if (reason.length > PurchaseLimits.reasonMax) {
      setState(() =>
          _fieldError = '«${widget.fieldLabel}» أطول من المسموح (${PurchaseLimits.reasonMax} حرفًا). اختصره.');
      return;
    }
    setState(() {
      _busy = true;
      _fieldError = null;
      _error = null;
    });
    try {
      await widget.onSubmit(reason);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        if (e is ApiException && e.code == ApiErrorCode.validation && e.field == 'reason') {
          _fieldError = e.message;
        } else {
          _error = errorMessage(e);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.destructive ? AppColors.error : AppColors.pomegranate;
    return AlertDialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      icon: widget.icon == null ? null : Icon(widget.icon, color: color, size: 32),
      title: Text(
        widget.title,
        textAlign: TextAlign.center,
        style: const TextStyle(fontFamily: AppFonts.display, fontSize: 20, fontWeight: FontWeight.w700),
      ),
      content: SizedBox(
        width: 440,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(widget.message, textAlign: TextAlign.center, style: const TextStyle(fontSize: 15, height: 1.6)),
              const SizedBox(height: 14),
              if (_error != null) ...[
                InlineBanner(kind: BannerKind.error, message: _error!),
                const SizedBox(height: 12),
              ],
              LabeledField(
                label: widget.fieldLabel,
                child: TextField(
                  controller: _reason,
                  enabled: !_busy,
                  autofocus: true,
                  minLines: 2,
                  maxLines: 4,
                  textInputAction: TextInputAction.newline,
                  onChanged: (_) {
                    if (_fieldError != null) setState(() => _fieldError = null);
                  },
                  decoration: uiInputDecoration(hint: widget.hint, errorText: _fieldError),
                ),
              ),
            ],
          ),
        ),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      actions: [
        Row(
          children: [
            Expanded(
              child: AppButton(
                label: 'تراجع',
                variant: AppButtonVariant.secondary,
                onPressed: _busy ? null : () => Navigator.of(context).pop(false),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: AppButton(
                label: widget.confirmLabel,
                variant: widget.destructive ? AppButtonVariant.danger : AppButtonVariant.primary,
                busy: _busy,
                busyLabel: 'جارٍ الحفظ',
                onPressed: _submit,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// «عملية واحدة بانتظار المزامنة» مع رابط إلى قائمة المزامنة.
class PendingSyncBanner extends StatelessWidget {
  const PendingSyncBanner({super.key, required this.count, required this.onOpen, this.message, this.kind});

  final int count;
  final VoidCallback onOpen;
  final String? message;
  final BannerKind? kind;

  @override
  Widget build(BuildContext context) => InlineBanner(
        kind: kind ?? BannerKind.info,
        icon: Icons.cloud_upload_outlined,
        title: pendingLabel(count),
        message: message ?? 'حُفظت على هذا الجهاز وستُرسل إلى الملف تلقائيًا عند توفر الاتصال.',
        actionLabel: 'عرض',
        onAction: onOpen,
      );
}
