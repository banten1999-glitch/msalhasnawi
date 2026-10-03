// أجزاء نموذج الشراء: اختيار المزارع بالبحث، أوزان العينة، بطاقة الحساب الحي، والشريط السفلي.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/format/numbers.dart';
import '../../core/models/dashboard.dart';
import '../../core/models/records.dart';
import '../../core/models/user.dart';
import '../../theme/app_theme.dart';
import '../../ui/ui.dart';
import 'cooler_format.dart';

/// أرقام عشرية بالأرقام اللاتينية أو العربية أو الفارسية مع العلامة العشرية وفواصل الآلاف.
final decimalInputFormatter = FilteringTextInputFormatter.allow(RegExp('[0-9٠-٩۰-۹.,٫٬ ]'));

/// أعداد صحيحة (تُقبل النقطة حتى يظهر خطأ واضح بدل تجاهلها بصمت).
final integerInputFormatter = FilteringTextInputFormatter.allow(RegExp('[0-9٠-٩۰-۹.,٫٬ ]'));

/// حقل اختيار يفتح قائمة (البراد).
class PickerField extends StatelessWidget {
  const PickerField({
    super.key,
    required this.text,
    required this.onTap,
    this.subtitle,
    this.icon = Icons.local_shipping_outlined,
    this.errorText,
    this.trailing,
  });

  final String text;
  final String? subtitle;
  final VoidCallback? onTap;
  final IconData icon;
  final String? errorText;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: onTap != null,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: InputDecorator(
          isEmpty: false,
          decoration: uiInputDecoration(
            errorText: errorText,
            prefixIcon: Icon(icon, color: AppColors.inkSecondary),
            suffixIcon: trailing ??
                (onTap == null ? null : const Icon(Icons.keyboard_arrow_down, color: AppColors.inkSecondary)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(text, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.ink)),
              if (subtitle != null && subtitle!.isNotEmpty) Text(subtitle!, style: UiText.small),
            ],
          ),
        ),
      ),
    );
  }
}

/// قائمة اختيار البراد المفتوح (لوحة سفلية أو نافذة).
class CoolerChoiceList extends StatelessWidget {
  const CoolerChoiceList({super.key, required this.coolers, required this.selectedId});

  final List<CoolerSummary> coolers;
  final String? selectedId;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 4, vertical: 6),
            child: Text('اختر البراد المفتوح', style: UiText.cardTitle),
          ),
          for (final c in coolers)
            InkWell(
              onTap: () => Navigator.of(context).pop(c.id),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                constraints: const BoxConstraints(minHeight: 60),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                decoration: const BoxDecoration(border: Border(top: BorderSide(color: UiColors.divider))),
                child: Row(
                  children: [
                    SizedBox(
                      width: 28,
                      child: c.id == selectedId ? const Icon(Icons.check, color: AppColors.pomegranate) : null,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(c.title, style: const TextStyle(fontWeight: FontWeight.w700, height: 1.4)),
                          Text(
                            [openedLine(c), operationsLabel(c.purchases)].where((s) => s.isNotEmpty).join(' · '),
                            style: UiText.small,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ============================================================================ المزارع

/// اختيار المزارع: بحث فوري داخل النموذج (دون نافذة منبثقة)، أو كتابة اسم مزارع جديد.
class PurchaseFarmerField extends StatelessWidget {
  const PurchaseFarmerField({
    super.key,
    required this.query,
    required this.focusNode,
    required this.farmers,
    required this.farmersError,
    required this.onRetryFarmers,
    required this.selected,
    required this.newName,
    required this.canAddNew,
    required this.enabled,
    required this.errorText,
    required this.onQueryChanged,
    required this.onSelect,
    required this.onNew,
    required this.onClear,
  });

  final TextEditingController query;
  final FocusNode focusNode;

  /// null = جارٍ التحميل.
  final List<Farmer>? farmers;
  final Object? farmersError;
  final VoidCallback onRetryFarmers;
  final Farmer? selected;
  final String? newName;
  final bool canAddNew;
  final bool enabled;
  final String? errorText;
  final ValueChanged<String> onQueryChanged;
  final ValueChanged<Farmer> onSelect;
  final ValueChanged<String> onNew;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];
    if (selected != null) {
      children.add(_SelectedFarmer(
        name: selected!.name,
        subtitle: [
          if (selected!.no > 0) 'رقم ${selected!.no}',
          if (selected!.village != null) selected!.village!,
          if (selected!.phone != null) selected!.phone!,
        ].join(' · '),
        isNew: false,
        onClear: enabled ? onClear : null,
      ));
    } else if (newName != null) {
      children.add(_SelectedFarmer(
        name: newName!,
        subtitle: 'يُضاف إلى قائمة المزارعين مع حفظ العملية',
        isNew: true,
        onClear: enabled ? onClear : null,
      ));
      final similar = (farmers ?? const <Farmer>[]).where((f) => similarName(f.name, newName!)).take(5).toList();
      if (similar.isNotEmpty) {
        children.add(const SizedBox(height: 8));
        children.add(_SimilarNames(farmers: similar, onSelect: enabled ? onSelect : null));
      }
    } else {
      children.add(TextField(
        controller: query,
        focusNode: focusNode,
        enabled: enabled,
        textInputAction: TextInputAction.search,
        onChanged: onQueryChanged,
        onSubmitted: (_) => _submitQuery(),
        decoration: uiInputDecoration(
          hint: 'اكتب اسم المزارع أو رقمه',
          errorText: errorText,
          prefixIcon: const Icon(Icons.search, color: AppColors.inkSecondary),
          suffixIcon: query.text.isEmpty
              ? null
              : IconButton(
                  tooltip: 'مسح البحث',
                  icon: const Icon(Icons.close),
                  onPressed: () {
                    query.clear();
                    onQueryChanged('');
                  },
                ),
        ),
      ));
      if (farmersError != null) {
        children.add(const SizedBox(height: 8));
        children.add(InlineBanner(
          kind: BannerKind.warning,
          message: 'تعذّر تحميل قائمة المزارعين. ${errorMessage(farmersError!)}',
          actionLabel: 'إعادة المحاولة',
          onAction: onRetryFarmers,
        ));
      }
      final suggestions = _suggestions();
      if (suggestions != null) {
        children.add(const SizedBox(height: 6));
        children.add(suggestions);
      }
    }
    if (errorText != null && (selected != null || newName != null)) {
      children.add(const SizedBox(height: 6));
      children.add(FieldError(errorText!));
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: children);
  }

  /// Enter في البحث: يختار المطابق الوحيد، أو المطابق تمامًا.
  void _submitQuery() {
    final q = query.text.trim();
    if (q.isEmpty) return;
    final list = farmers ?? const <Farmer>[];
    final exact = list.where((f) => sameName(f.name, q)).toList();
    if (exact.length == 1) return onSelect(exact.single);
    final matches = searchFarmers(list, q);
    if (matches.length == 1) return onSelect(matches.single);
    if (matches.isEmpty && canAddNew) onNew(q);
  }

  Widget? _suggestions() {
    final q = query.text.trim();
    if (q.isEmpty) return null;
    final list = farmers ?? const <Farmer>[];
    final matches = searchFarmers(list, q);
    final exists = list.any((f) => sameName(f.name, q));
    final rows = <Widget>[
      for (final f in matches)
        _SuggestionRow(
          icon: Icons.person_outline,
          title: f.name,
          subtitle: [if (f.no > 0) 'رقم ${f.no}', if (f.village != null) f.village!].join(' · '),
          onTap: enabled ? () => onSelect(f) : null,
        ),
      if (!exists && canAddNew)
        _SuggestionRow(
          icon: Icons.person_add_alt_1_outlined,
          title: 'مزارع جديد: «$q»',
          subtitle: matches.isEmpty ? 'لا يوجد مزارع بهذا الاسم في القائمة' : 'إن لم يكن أحد المزارعين أعلاه',
          accent: true,
          onTap: enabled ? () => onNew(q) : null,
        ),
    ];
    if (rows.isEmpty) {
      if (farmers == null) {
        return const Padding(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: Text('جارٍ تحميل قائمة المزارعين…', style: UiText.small),
        );
      }
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(
          canAddNew
              ? 'المزارع «$q» مسجل بالفعل. اختره من القائمة.'
              : 'لا يوجد مزارع بهذا الاسم. إضافة مزارع جديد تحتاج صلاحية «إضافة المزارعين»؛ اطلبها من المدير.',
          style: UiText.small,
        ),
      );
    }
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: UiColors.cardBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(mainAxisSize: MainAxisSize.min, children: rows),
    );
  }
}

class _SuggestionRow extends StatelessWidget {
  const _SuggestionRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.accent = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    final color = accent ? AppColors.pomegranate : AppColors.ink;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 52),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: UiColors.divider))),
          child: Row(
            children: [
              Icon(icon, size: 20, color: accent ? AppColors.pomegranate : AppColors.inkSecondary),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(title, style: TextStyle(fontWeight: FontWeight.w700, color: color, height: 1.4)),
                    if (subtitle.isNotEmpty) Text(subtitle, style: UiText.small),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SelectedFarmer extends StatelessWidget {
  const _SelectedFarmer({required this.name, required this.subtitle, required this.isNew, required this.onClear});

  final String name;
  final String subtitle;
  final bool isNew;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 56),
      padding: const EdgeInsetsDirectional.only(start: 10, end: 4, top: 6, bottom: 6),
      decoration: BoxDecoration(
        color: isNew ? AppColors.pomegranateLight : AppColors.leafLight,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          InitialsAvatar(
            AppUser.initialsOf(name),
            size: 36,
            background: isNew ? AppColors.pomegranate : AppColors.leaf,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15.5, height: 1.4)),
                    ),
                    if (isNew) ...[
                      const SizedBox(width: 6),
                      const StatusChip(StatusKind.info, label: 'جديد', dense: true),
                    ],
                  ],
                ),
                if (subtitle.isNotEmpty) Text(subtitle, style: UiText.small),
              ],
            ),
          ),
          if (onClear != null)
            TextButton(
              onPressed: onClear,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.pomegranate,
                minimumSize: const Size(48, 48),
                textStyle: const TextStyle(fontFamily: AppFonts.body, fontWeight: FontWeight.w700, fontSize: 14),
              ),
              child: const Text('تغيير'),
            ),
        ],
      ),
    );
  }
}

class _SimilarNames extends StatelessWidget {
  const _SimilarNames({required this.farmers, required this.onSelect});

  final List<Farmer> farmers;
  final ValueChanged<Farmer>? onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
      decoration: BoxDecoration(color: AppColors.amberLight, borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.warning_amber_rounded, size: 20, color: AppColors.amber),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'أسماء مشابهة مسجلة بالفعل. إن كان المزارع أحدهم فاختره بدل إضافته مرة أخرى:',
                  style: TextStyle(fontSize: 13.5, color: AppColors.amber, fontWeight: FontWeight.w600, height: 1.45),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          for (final f in farmers)
            Row(
              children: [
                Expanded(
                  child: Text(
                    [f.name, if (f.no > 0) 'رقم ${f.no}', if (f.village != null) f.village!].join(' · '),
                    style: const TextStyle(fontSize: 14, color: AppColors.ink, height: 1.4),
                  ),
                ),
                if (onSelect != null)
                  TextButton(
                    onPressed: () => onSelect!(f),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.amber,
                      minimumSize: const Size(48, 44),
                      textStyle: const TextStyle(fontFamily: AppFonts.body, fontWeight: FontWeight.w700, fontSize: 13.5),
                    ),
                    child: Text('اختيار', semanticsLabel: 'اختيار ${f.name}'),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

// ============================================================================ العينة

/// أوزان صناديق العينة (القائم): صف لكل صندوق مع حذف، وإضافة صف بالضغط على «التالي».
class SampleWeightsEditor extends StatelessWidget {
  const SampleWeightsEditor({
    super.key,
    required this.controllers,
    required this.focusNodes,
    required this.rowErrors,
    required this.enabled,
    required this.onAdd,
    required this.onRemove,
    required this.onChanged,
    required this.onSubmittedRow,
    this.errorText,
  });

  final List<TextEditingController> controllers;
  final List<FocusNode> focusNodes;
  final List<String?> rowErrors;
  final bool enabled;
  final VoidCallback onAdd;
  final ValueChanged<int> onRemove;
  final ValueChanged<String> onChanged;
  final ValueChanged<int> onSubmittedRow;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    final full = controllers.length >= PurchaseLimits.sampleMaxCount;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < controllers.length; i++) ...[
          if (i > 0) const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 50,
                alignment: Alignment.center,
                child: Text('${i + 1}', style: UiText.number(size: 15, color: AppColors.inkSecondary)),
              ),
              Expanded(
                child: TextField(
                  controller: controllers[i],
                  focusNode: focusNodes[i],
                  enabled: enabled,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [decimalInputFormatter],
                  textInputAction: TextInputAction.next,
                  onChanged: onChanged,
                  onSubmitted: (_) => onSubmittedRow(i),
                  decoration: uiInputDecoration(
                    hint: 'وزن الصندوق ${i + 1} (كغ)',
                    errorText: i < rowErrors.length ? rowErrors[i] : null,
                    suffixIcon: const _UnitSuffix('كغ'),
                  ),
                ),
              ),
              IconButton(
                tooltip: 'حذف وزن الصندوق ${i + 1}',
                onPressed: enabled ? () => onRemove(i) : null,
                icon: const Icon(Icons.remove_circle_outline),
                color: AppColors.inkSecondary,
                style: IconButton.styleFrom(minimumSize: const Size(48, 50)),
              ),
            ],
          ),
        ],
        if (errorText != null) ...[const SizedBox(height: 6), FieldError(errorText!)],
        const SizedBox(height: 4),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: TextButton.icon(
            onPressed: enabled && !full ? onAdd : null,
            icon: const Icon(Icons.add),
            label: Text(full ? 'الحد الأقصى ${PurchaseLimits.sampleMaxCount} وزنًا' : 'إضافة وزن صندوق'),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.pomegranate,
              minimumSize: const Size(48, 48),
              textStyle: const TextStyle(fontFamily: AppFonts.body, fontWeight: FontWeight.w700, fontSize: 14),
            ),
          ),
        ),
      ],
    );
  }
}

/// وحدة صغيرة داخل الحقل («كغ»، «ج.م»).
class _UnitSuffix extends StatelessWidget {
  const _UnitSuffix(this.unit);

  final String unit;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsetsDirectional.only(end: 12, start: 4),
        child: Center(widthFactor: 1, child: Text(unit, style: UiText.small)),
      );
}

/// وحدة داخل حقل رقمي.
Widget unitSuffix(String unit) => _UnitSuffix(unit);

/// ملخص العينة: «متوسط القائم 13 كغ (2 صندوق) − الفارغ 1.9 كغ = 11.1 كغ صافي».
class SampleSummary extends StatelessWidget {
  const SampleSummary({super.key, required this.count, required this.grossMeanGrams, required this.tareGrams, this.netGrams});

  final int count;
  final int? grossMeanGrams;
  final int tareGrams;
  final int? netGrams;

  @override
  Widget build(BuildContext context) {
    final net = netGrams;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(color: AppColors.ivory, borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('متوسط الوزن الصافي للصندوق', style: UiText.label),
          if (net == null || grossMeanGrams == null)
            const Text('أدخل وزن صندوق واحد على الأقل ليُحسب المتوسط.', style: UiText.small)
          else ...[
            NumberText(kgExact(net), unit: kWeightUnit, fontSize: 20, color: net > 0 ? AppColors.ink : AppColors.error),
            Text(
              'متوسط القائم ${kgExact(grossMeanGrams!)} كغ من $count ${count == 1 ? 'صندوق' : 'صناديق'}'
              ' − الفارغ ${kgExact(tareGrams)} كغ',
              style: UiText.small,
            ),
          ],
        ],
      ),
    );
  }
}

// ============================================================================ الحساب الحي

/// بطاقة الحساب: الوزن الإجمالي والقيمة، ثم المدفوع والمتبقي.
class PurchaseTotalsCard extends StatelessWidget {
  const PurchaseTotalsCard({
    super.key,
    required this.boxes,
    required this.avgGrams,
    required this.weightGrams,
    required this.pricePiasters,
    required this.valuePiasters,
    this.paymentMode,
    this.paidNowPiasters,
    this.alreadyPaidPiasters,
    this.valueError,
  });

  final int? boxes;
  final int? avgGrams;
  final int? weightGrams;
  final int? pricePiasters;
  final int? valuePiasters;

  /// null في التعديل (لا قسم دفع).
  final PaymentMode? paymentMode;
  final int? paidNowPiasters;

  /// في التعديل: المدفوع من قبل.
  final int? alreadyPaidPiasters;
  final String? valueError;

  @override
  Widget build(BuildContext context) {
    final w = weightGrams;
    final v = valuePiasters;
    final paid = paymentMode != null ? paidNowPiasters : alreadyPaidPiasters;
    final remaining = v == null || paid == null ? null : v - paid;
    return AppCard(
      color: Colors.white,
      borderColor: UiColors.currentBorder,
      borderWidth: 1.5,
      child: Semantics(
        container: true,
        liveRegion: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('الحساب', style: UiText.cardTitle),
            const SizedBox(height: 10),
            _line(
              'الوزن الإجمالي',
              boxes != null && avgGrams != null ? '${formatCount(boxes!)} صندوق × ${kgExact(avgGrams!)} كغ' : null,
              w == null ? null : NumberText(kgExact(w), unit: kWeightUnit, fontSize: 18),
            ),
            const Divider(height: 18, color: UiColors.divider),
            _line(
              'القيمة',
              w != null && pricePiasters != null ? '${kgExact(w)} كغ × ${formatMoney(pricePiasters!)} ج.م/كغ' : null,
              v == null ? null : MoneyText(v, fontSize: 24, unitFontSize: 14, color: AppColors.pomegranateDark),
            ),
            if (w == null || v == null)
              const Padding(
                padding: EdgeInsets.only(top: 6),
                child: Text('تظهر القيمة فور كتابة عدد الصناديق ومتوسط الوزن وسعر الكيلو.', style: UiText.small),
              ),
            if (valueError != null) ...[const SizedBox(height: 8), FieldError(valueError!)],
            if (paid != null || paymentMode != null) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _money(
                      paymentMode != null ? 'المدفوع الآن' : 'المدفوع حتى الآن',
                      paid,
                      AppColors.leaf,
                      UiColors.paidBg,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _money(
                      paymentMode != null ? 'المتبقي للمزارع' : 'المتبقي بعد التعديل',
                      remaining,
                      AppColors.amber,
                      UiColors.remainingBg,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _line(String label, String? detail, Widget? value) => Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: UiText.label),
                if (detail != null) Text(detail, style: UiText.small),
              ],
            ),
          ),
          const SizedBox(width: 10),
          value ?? Text('—', style: UiText.number(size: 18, color: AppColors.inkMuted)),
        ],
      );

  Widget _money(String label, int? piasters, Color color, Color bg) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: UiText.small.copyWith(color: color, fontWeight: FontWeight.w600)),
            if (piasters == null)
              Text('—', style: UiText.number(size: 16, color: color))
            else
              MoneyText(piasters, fontSize: 16, color: color, unitFontSize: 11.5),
          ],
        ),
      );
}

/// الشريط السفلي على الهاتف: القيمة الحية وأزرار الحفظ (تختفي الأزرار أثناء ظهور لوحة المفاتيح).
class PurchaseBottomBar extends StatelessWidget {
  const PurchaseBottomBar({
    super.key,
    required this.weightGrams,
    required this.valuePiasters,
    required this.buttons,
  });

  final int? weightGrams;
  final int? valuePiasters;
  final List<Widget> buttons;

  @override
  Widget build(BuildContext context) {
    final keyboard = MediaQuery.viewInsetsOf(context).bottom > 0;
    final v = valuePiasters;
    final w = weightGrams;
    return Material(
      color: Colors.white,
      elevation: 6,
      shadowColor: const Color(0x331C1714),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(16, keyboard ? 6 : 10, 16, keyboard ? 6 : 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Text('القيمة', style: UiText.label),
                  const SizedBox(width: 8),
                  if (w != null) Expanded(child: Text('${kgExact(w)} كغ', style: UiText.small)) else const Spacer(),
                  if (v == null)
                    Text('—', style: UiText.number(size: 18, color: AppColors.inkMuted))
                  else
                    MoneyText(v, fontSize: 19, unitFontSize: 12, color: AppColors.pomegranateDark),
                ],
              ),
              if (!keyboard && buttons.isNotEmpty) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    for (var i = 0; i < buttons.length; i++) ...[
                      if (i > 0) const SizedBox(width: 10),
                      Expanded(flex: i == 0 && buttons.length > 1 ? 2 : 3, child: buttons[i]),
                    ],
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
