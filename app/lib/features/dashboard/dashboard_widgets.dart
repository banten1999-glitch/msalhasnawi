import 'package:flutter/material.dart';

import '../../core/format/numbers.dart';
import '../../core/models/dashboard.dart';
import '../../theme/app_theme.dart';
import '../../ui/ui.dart';
import 'dashboard_format.dart';

// ============================================================================ الفلاتر

/// زر فلتر بقائمة اختيارات («الفترة: هذا الموسم»). القيمة '' تعني «الكل».
class DashboardFilterButton extends StatelessWidget {
  const DashboardFilterButton({
    super.key,
    required this.icon,
    required this.label,
    required this.options,
    required this.selected,
    required this.onSelected,
    required this.tooltip,
  });

  final IconData icon;
  final String label;
  final List<(String, String)> options;
  final String selected;
  final ValueChanged<String> onSelected;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: tooltip,
      position: PopupMenuPosition.under,
      color: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      constraints: const BoxConstraints(minWidth: 200, maxWidth: 340),
      onSelected: (v) {
        if (v != selected) onSelected(v);
      },
      itemBuilder: (context) => [
        for (final o in options)
          PopupMenuItem<String>(
            value: o.$1,
            height: 48,
            child: Row(
              children: [
                SizedBox(
                  width: 24,
                  child: o.$1 == selected ? const Icon(Icons.check, size: 20, color: AppColors.pomegranate) : null,
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    o.$2,
                    style: TextStyle(
                      fontWeight: o.$1 == selected ? FontWeight.w700 : FontWeight.w500,
                      color: AppColors.ink,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
      child: Container(
        constraints: const BoxConstraints(minHeight: 48),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: UiColors.fieldBorder, width: 1.5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: AppColors.ink),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.ink),
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.keyboard_arrow_down, size: 20, color: AppColors.inkSecondary),
          ],
        ),
      ),
    );
  }
}

// ============================================================================ الإجراءات

enum ActionTone { pomegranate, leaf, neutral }

/// إجراء سريع في لوحة التحكم.
class DashboardAction {
  const DashboardAction(this.label, this.icon, this.tone, this.onTap, {this.wideLabel});

  final String label;

  /// نص أطول على الشاشات العريضة («إضافة شراء من مزارع»).
  final String? wideLabel;
  final IconData icon;
  final ActionTone tone;
  final VoidCallback onTap;
}

(Color, Color) _toneColors(ActionTone t) => switch (t) {
      ActionTone.pomegranate => (AppColors.pomegranateLight, AppColors.pomegranate),
      ActionTone.leaf => (AppColors.leafLight, AppColors.leaf),
      ActionTone.neutral => (UiColors.beige, UiColors.label),
    };

/// شبكة الإجراءات السريعة على الهاتف (ثلاثة في الصف).
class QuickActionsGrid extends StatelessWidget {
  const QuickActionsGrid({super.key, required this.actions});

  final List<DashboardAction> actions;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeader('إجراءات سريعة'),
        const SizedBox(height: 10),
        ResponsiveGrid(
          minTileWidth: 100,
          maxColumns: 3,
          minColumns: 3,
          spacing: 10,
          children: [for (final a in actions) _QuickActionTile(action: a)],
        ),
      ],
    );
  }
}

class _QuickActionTile extends StatelessWidget {
  const _QuickActionTile({required this.action});

  final DashboardAction action;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = _toneColors(action.tone);
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 12),
      onTap: action.onTap,
      child: Semantics(
        button: true,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 68),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
                child: Icon(action.icon, size: 22, color: fg),
              ),
              const SizedBox(height: 8),
              Text(
                action.label,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, height: 1.3),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// صف أزرار الإجراءات على الشاشات العريضة (الأول رئيسي).
class QuickActionsBar extends StatelessWidget {
  const QuickActionsBar({super.key, required this.actions});

  final List<DashboardAction> actions;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (var i = 0; i < actions.length; i++)
          AppButton(
            label: actions[i].wideLabel ?? actions[i].label,
            icon: actions[i].icon,
            height: 48,
            variant: i == 0 ? AppButtonVariant.primary : AppButtonVariant.secondary,
            onPressed: actions[i].onTap,
          ),
      ],
    );
  }
}

// ============================================================================ البراد الحالي

/// بطاقة البراد الجاري تحميله (أو البراد المختار في الفلتر).
class CurrentCoolerCard extends StatelessWidget {
  const CurrentCoolerCard({
    super.key,
    required this.cooler,
    required this.others,
    required this.filtered,
    required this.onAddPurchase,
    required this.onOpenCooler,
    required this.onSwitch,
    this.wide = false,
  });

  final CoolerSummary cooler;

  /// برادات أخرى مفتوحة يمكن التبديل إليها.
  final List<CoolerSummary> others;

  /// اختاره المستخدم من الفلتر (لا «الجاري تحميله» تلقائيًا).
  final bool filtered;

  /// null يخفي زر «إضافة شراء» (لا صلاحية، أو البراد مقفّل).
  final VoidCallback? onAddPurchase;
  final VoidCallback onOpenCooler;
  final ValueChanged<CoolerSummary> onSwitch;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    final c = cooler;
    final kicker = !c.isOpen ? 'البراد المحدد' : (filtered ? 'البراد المحدد' : 'البراد الجاري تحميله');
    final subtitle = coolerSubtitle(c);
    final value = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('قيمة الرمان', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.inkMuted)),
        MoneyText(c.valuePiasters, fontSize: wide ? 26 : 28, unitFontSize: 15),
      ],
    );
    return AppCard(
      borderColor: UiColors.currentBorder,
      borderWidth: 1.5,
      padding: EdgeInsets.all(wide ? 18 : 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(kicker, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.pomegranate)),
                    Semantics(
                      header: true,
                      child: Text(
                        c.title,
                        style: const TextStyle(fontFamily: AppFonts.display, fontSize: 21, fontWeight: FontWeight.w700, height: 1.35),
                      ),
                    ),
                    if (subtitle.isNotEmpty) Text(subtitle, style: UiText.muted),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              StatusChip(c.isOpen ? StatusKind.open : StatusKind.closed),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
            decoration: BoxDecoration(color: AppColors.ivory, borderRadius: BorderRadius.circular(12)),
            child: Row(
              children: [
                _stat(formatCount(c.boxes), 'صندوق'),
                _stat(kg(c.weightGrams), 'كغ'),
                _stat(formatCount(c.farmers), 'مزارعين'),
                _stat(formatCount(c.purchases), 'عمليات'),
              ],
            ),
          ),
          const SizedBox(height: 14),
          value,
          const SizedBox(height: 10),
          PaidProgressBar(paid: c.paidPiasters, total: c.valuePiasters),
          const SizedBox(height: 6),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            spacing: 12,
            runSpacing: 4,
            children: [
              _amountLabel('مدفوع', c.paidPiasters, AppColors.leaf),
              _amountLabel('متبقي', c.remainingPiasters, AppColors.amber),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              if (onAddPurchase != null) ...[
                Expanded(child: AppButton(label: 'إضافة شراء', icon: Icons.add, onPressed: onAddPurchase)),
                const SizedBox(width: 10),
              ],
              if (onAddPurchase == null)
                Expanded(
                  child: AppButton(label: 'فتح البراد', variant: AppButtonVariant.secondary, onPressed: onOpenCooler),
                )
              else
                AppButton(label: 'فتح البراد', variant: AppButtonVariant.secondary, onPressed: onOpenCooler),
            ],
          ),
          for (final o in others) ...[
            const SizedBox(height: 10),
            const Divider(height: 1, thickness: 1, color: UiColors.divider),
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'براد ${o.no} مفتوح أيضًا · ${operationsCount(o.purchases)}',
                      style: const TextStyle(fontSize: 13.5, color: AppColors.inkMuted),
                    ),
                  ),
                  TextButton(
                    onPressed: () => onSwitch(o),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.pomegranate,
                      minimumSize: const Size(48, 48),
                      textStyle: const TextStyle(fontFamily: AppFonts.body, fontWeight: FontWeight.w700, fontSize: 13.5),
                    ),
                    child: Text('تبديل إلى براد ${o.no}', semanticsLabel: 'تبديل إلى براد ${o.no}'),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _stat(String value, String unit) => Expanded(
        child: Column(
          children: [
            Text(value, textAlign: TextAlign.center, style: UiText.number(size: 18)),
            Text(unit, style: const TextStyle(fontSize: 12, color: AppColors.inkMuted, height: 1.3)),
          ],
        ),
      );

  Widget _amountLabel(String label, int piasters, Color color) => Text.rich(
        TextSpan(
          children: [
            TextSpan(text: '$label '),
            TextSpan(
              text: formatMoney(piasters),
              style: UiText.number(size: 14, color: color),
            ),
          ],
        ),
        style: const TextStyle(fontSize: 13.5, color: AppColors.ink),
      );
}

/// لا يوجد براد مفتوح.
class NoOpenCoolerCard extends StatelessWidget {
  const NoOpenCoolerCard({super.key, required this.onCreate});

  final VoidCallback? onCreate;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(color: UiColors.beige, borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.local_shipping_outlined, color: UiColors.label),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('لا يوجد براد مفتوح الآن', style: UiText.cardTitle),
                    Text('افتح برادًا جديدًا لبدء تسجيل مشتريات الرمان فيه.', style: UiText.muted),
                  ],
                ),
              ),
            ],
          ),
          if (onCreate != null) ...[
            const SizedBox(height: 14),
            AppButton(label: 'إنشاء براد', icon: Icons.add, onPressed: onCreate),
          ],
        ],
      ),
    );
  }
}

/// قائمة البرادات المفتوحة (الشاشات العريضة).
class OpenCoolersCard extends StatelessWidget {
  const OpenCoolersCard({super.key, required this.coolers, required this.currentId, required this.onSelect});

  final List<CoolerSummary> coolers;
  final String? currentId;
  final ValueChanged<CoolerSummary> onSelect;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SectionHeader('البرادات المفتوحة', style: UiText.cardTitle),
          const SizedBox(height: 6),
          for (final c in coolers)
            InkWell(
              onTap: c.id == currentId ? null : () => onSelect(c),
              child: Container(
                constraints: const BoxConstraints(minHeight: 56),
                decoration: const BoxDecoration(border: Border(top: BorderSide(color: UiColors.divider))),
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(c.title, style: const TextStyle(fontWeight: FontWeight.w700, height: 1.4)),
                          Text(
                            '${operationsCount(c.purchases)} · ${formatCount(c.boxes)} صندوق',
                            style: UiText.small,
                          ),
                        ],
                      ),
                    ),
                    MoneyText(c.valuePiasters, fontSize: 15, showCurrency: false),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ============================================================================ المؤشرات والمال

List<KpiTile> seasonKpiTiles(DashboardKpis k) => [
      KpiTile(label: 'برادات مقفّلة ومحمّلة', value: formatCount(k.closedCoolers)),
      KpiTile(label: 'برادات مفتوحة', value: formatCount(k.openCoolers)),
      KpiTile(label: 'مزارعون مختلفون', value: formatCount(k.distinctFarmers)),
      KpiTile(label: 'عمليات شراء الرمان', value: formatCount(k.purchases)),
      KpiTile(label: 'إجمالي الصناديق', value: formatCount(k.boxes)),
      KpiTile(label: 'إجمالي وزن الرمان', value: kg(k.weightGrams), unit: kWeightUnit),
    ];

int totalDue(DashboardKpis k) => k.purchaseValuePiasters + k.packagingApprovedPiasters;

String remainingSplit(DashboardKpis k) =>
    'للمزارعين ${formatMoney(k.remainingFarmersPiasters)} · للموردين ${formatMoney(k.remainingSuppliersPiasters)}';

/// مؤشرات المال كمربعات (الشاشات العريضة).
List<KpiTile> moneyKpiTiles(DashboardKpis k) => [
      KpiTile(label: 'قيمة شراء الرمان', value: formatMoney(k.purchaseValuePiasters), unit: kCurrencySymbol),
      KpiTile(label: 'مشتريات التعبئة المعتمدة', value: formatMoney(k.packagingApprovedPiasters), unit: kCurrencySymbol),
      KpiTile(
        label: 'إجمالي المستحق',
        value: formatMoney(totalDue(k)),
        unit: kCurrencySymbol,
        note: 'قيمة الرمان + التعبئة المعتمدة',
      ),
      KpiTile(
        label: 'المدفوع فعليًا',
        value: formatMoney(k.paidPiasters),
        unit: kCurrencySymbol,
        accent: KpiAccent.paid,
        note: 'مجموع الدفعات المسجلة فقط',
      ),
      KpiTile(
        label: 'المتبقي',
        value: formatMoney(k.remainingPiasters),
        unit: kCurrencySymbol,
        accent: KpiAccent.remaining,
        note: remainingSplit(k),
      ),
      KpiTile(
        label: 'متوسط سعر الكيلو',
        value: formatMoney(k.avgPricePerKgPiasters),
        unit: '$kCurrencySymbol/كغ',
        note: 'مرجّح بالوزن',
      ),
    ];

/// بطاقة «الحساب المالي» على الهاتف.
class MoneyCard extends StatelessWidget {
  const MoneyCard({super.key, required this.kpis});

  final DashboardKpis kpis;

  @override
  Widget build(BuildContext context) {
    final k = kpis;
    return AppCard(
      padding: EdgeInsets.zero,
      clip: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 14, 16, 6),
            child: SectionHeader('الحساب المالي', trailing: Text('بالجنيه المصري', style: UiText.small)),
          ),
          _row('قيمة شراء الرمان', k.purchaseValuePiasters),
          _row('مشتريات التعبئة المعتمدة', k.packagingApprovedPiasters),
          _row('إجمالي المستحق', totalDue(k), note: 'قيمة الرمان + التعبئة المعتمدة'),
          _row('متوسط سعر الكيلو', k.avgPricePerKgPiasters, note: 'مرجّح بالوزن', unit: '$kCurrencySymbol/كغ'),
          _row(
            'المدفوع فعليًا',
            k.paidPiasters,
            note: 'مجموع الدفعات المسجلة فقط',
            color: AppColors.leaf,
            background: UiColors.paidBg,
            big: true,
          ),
          _row(
            'المتبقي',
            k.remainingPiasters,
            note: remainingSplit(k),
            color: AppColors.amber,
            background: UiColors.remainingBg,
            big: true,
          ),
        ],
      ),
    );
  }

  Widget _row(
    String label,
    int piasters, {
    String? note,
    String? unit,
    Color color = AppColors.ink,
    Color? background,
    bool big = false,
  }) {
    return Semantics(
      container: true,
      child: Container(
        decoration: BoxDecoration(
          color: background,
          border: background == null ? const Border(top: BorderSide(color: UiColors.divider)) : null,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: UiText.label.copyWith(color: background == null ? AppColors.inkSecondary : color)),
                  if (note != null) Text(note, style: const TextStyle(fontSize: 12, color: AppColors.inkMuted, height: 1.4)),
                ],
              ),
            ),
            const SizedBox(width: 12),
            NumberText(
              formatMoney(piasters),
              unit: unit,
              fontSize: big ? 20 : 18,
              color: color,
              unitFontSize: 12,
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================ آخر العمليات

(IconData, Color, Color) _typeStyle(String type) => switch (type) {
      'payment' => (Icons.payments_outlined, AppColors.leafLight, AppColors.leaf),
      'packaging' => (Icons.inventory_2_outlined, AppColors.leafLight, AppColors.leaf),
      _ => (Icons.scale_outlined, AppColors.pomegranateLight, AppColors.pomegranate),
    };

String _typeLabel(String type) => switch (type) {
      'payment' => 'دفعة',
      'packaging' => 'تعبئة',
      _ => 'شراء رمان',
    };

Color _amountColor(ActivityItem a) {
  if (a.status == 'cancelled' || a.status == 'draft') return AppColors.inkMuted;
  if (a.type == 'payment') return AppColors.leaf;
  return AppColors.ink;
}

Widget _statusWidget(ActivityItem a, {bool dense = true}) {
  // الدفعة الفعّالة لا تحتاج شارة لونية؛ الملغاة تظهر بشارة مشطوبة.
  if (a.type == 'payment' && a.status == 'active') {
    return Text(a.statusLabel.isEmpty ? 'مسجّلة' : a.statusLabel, style: UiText.small);
  }
  if (a.status.isEmpty) return const SizedBox.shrink();
  return StatusChip.fromStatus(a.status, label: a.statusLabel, dense: dense);
}

/// قائمة آخر العمليات (الهاتف).
class RecentOperationsCard extends StatelessWidget {
  const RecentOperationsCard({super.key, required this.items});

  final List<ActivityItem> items;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SectionHeader('آخر العمليات'),
          const SizedBox(height: 6),
          if (items.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Text('لا توجد عمليات في هذه الفترة.', style: UiText.muted),
            ),
          for (final a in items) _RecentRow(item: a),
        ],
      ),
    );
  }
}

class _RecentRow extends StatelessWidget {
  const _RecentRow({required this.item});

  final ActivityItem item;

  @override
  Widget build(BuildContext context) {
    final a = item;
    final (icon, bg, fg) = _typeStyle(a.type);
    final when = relativeDateTime(a.at);
    final subtitle = [if (a.subtitle.isNotEmpty) a.subtitle, if (when.isNotEmpty) when].join(' · ');
    final cancelled = a.status == 'cancelled';
    return Container(
      decoration: const BoxDecoration(border: Border(top: BorderSide(color: UiColors.divider))),
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, size: 22, color: fg, semanticLabel: _typeLabel(a.type)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  a.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5, height: 1.4),
                ),
                if (subtitle.isNotEmpty) Text(subtitle, style: UiText.small),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              NumberText(formatMoney(a.amountPiasters), fontSize: 15, color: _amountColor(a), strike: cancelled),
              const SizedBox(height: 4),
              _statusWidget(a),
            ],
          ),
        ],
      ),
    );
  }
}

/// جدول آخر العمليات (الشاشات العريضة).
class RecentOperationsTable extends StatelessWidget {
  const RecentOperationsTable({super.key, required this.items});

  final List<ActivityItem> items;

  @override
  Widget build(BuildContext context) {
    const head = TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.inkMuted);
    return AppCard(
      padding: const EdgeInsets.only(top: 16, bottom: 4),
      clip: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(18, 0, 18, 10),
            child: SectionHeader('آخر العمليات', style: UiText.cardTitle),
          ),
          if (items.isEmpty)
            const Padding(
              padding: EdgeInsets.fromLTRB(18, 8, 18, 20),
              child: Text('لا توجد عمليات في هذه الفترة.', style: UiText.muted),
            )
          else
            LayoutBuilder(
              builder: (context, c) => SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: ConstrainedBox(
                  constraints: BoxConstraints(minWidth: c.maxWidth),
                  child: DataTable(
                    headingRowColor: const WidgetStatePropertyAll(UiColors.tableHead),
                    headingRowHeight: 44,
                    dataRowMinHeight: 52,
                    dataRowMaxHeight: 64,
                    horizontalMargin: 18,
                    columnSpacing: 20,
                    dividerThickness: 1,
                    headingTextStyle: head,
                    columns: const [
                      DataColumn(label: Text('النوع')),
                      DataColumn(label: Text('الطرف')),
                      DataColumn(label: Text('البراد')),
                      DataColumn(label: Text('الوقت')),
                      DataColumn(label: Text('المبلغ (ج.م)'), numeric: true),
                      DataColumn(label: Text('الحالة')),
                    ],
                    rows: [
                      for (final a in items)
                        DataRow(cells: [
                          DataCell(Text(_typeLabel(a.type))),
                          DataCell(Text(a.title, style: const TextStyle(fontWeight: FontWeight.w700))),
                          DataCell(Text(a.coolerNo == null ? '—' : 'براد ${a.coolerNo}')),
                          DataCell(Text(relativeDateTime(a.at))),
                          DataCell(NumberText(
                            formatMoney(a.amountPiasters),
                            fontSize: 14,
                            color: _amountColor(a),
                            strike: a.status == 'cancelled',
                          )),
                          DataCell(_statusWidget(a, dense: false)),
                        ]),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ============================================================================ البداية

/// لا توجد أي بيانات: شرح البداية في ثلاث خطوات.
class DashboardOnboarding extends StatelessWidget {
  const DashboardOnboarding({super.key, required this.onCreateCooler});

  /// null للمستخدم الذي لا يملك صلاحية التسجيل (مشاهدة فقط).
  final VoidCallback? onCreateCooler;

  @override
  Widget build(BuildContext context) {
    final canCreate = onCreateCooler != null;
    return EmptyState(
      icon: Icons.local_shipping_outlined,
      title: 'لا توجد بيانات بعد',
      message: canCreate
          ? 'ابدأ بإنشاء أول براد، ثم سجّل مشتريات الرمان من المزارعين داخله. ستظهر الإجماليات هنا تلقائيًا.'
          : 'لم يُسجَّل أي براد أو عملية بعد. ستظهر الإجماليات هنا تلقائيًا عندما يبدأ الفريق التسجيل.',
      actionLabel: canCreate ? 'إنشاء أول براد' : null,
      actionIcon: Icons.add,
      onAction: onCreateCooler,
      footer: const AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Step(1, 'أنشئ برادًا', 'يأخذ رقمًا تلقائيًا ووقت فتح.'),
            SizedBox(height: 12),
            _Step(2, 'سجّل الشراء من كل مزارع', 'الصناديق والوزن والسعر، والقيمة تُحسب فورًا.'),
            SizedBox(height: 12),
            _Step(3, 'قفّل البراد بعد التحميل', 'تُحفظ خلاصته ويُستخرج تقريره.'),
          ],
        ),
      ),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step(this.n, this.title, this.body);

  final int n;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 28,
          height: 28,
          alignment: Alignment.center,
          decoration: const BoxDecoration(color: AppColors.pomegranateLight, shape: BoxShape.circle),
          child: Text('$n', style: UiText.number(size: 14, color: AppColors.pomegranate)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w700, height: 1.4)),
              Text(body, style: const TextStyle(fontSize: 13.5, color: AppColors.inkMuted, height: 1.5)),
            ],
          ),
        ),
      ],
    );
  }
}
