import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../app/routes.dart';
import '../../core/api/api_exception.dart';
import '../../core/api/request_id.dart';
import '../../core/format/numbers.dart';
import '../../core/models/records.dart';
import '../../core/models/user.dart';
import '../../core/sync/data_changes.dart';
import '../../theme/app_theme.dart';
import '../../ui/ui.dart';
import '../shell/shell_scope.dart';
import '../shell/shell_section.dart';
import 'farmer_figures.dart';
import 'filter_menu_button.dart';
import 'text_search.dart';

/// ترتيب قائمة المزارعين.
enum _Sort {
  number('رقم المزارع'),
  remaining('الأعلى متبقيًا'),
  name('الاسم');

  const _Sort(this.label);
  final String label;
}

/// رسالة أعلى القائمة بعد إجراء (نجاح أو خطأ)، مع «تحديث» اختياري.
typedef _Notice = ({BannerKind kind, String message, bool refresh});

/// قسم «المزارعون»: بحث، إضافة، تعديل، إيقاف، وفتح كشف حساب المزارع.
///
/// يُعرض داخل الواجهة الرئيسية (دون Scaffold): على الهاتف يأتي الشريط العلوي من HomeShell، وعلى الشاشات
/// العريضة يعرض القسم PageHeader بنفسه مثل لوحة التحكم.
class FarmersScreen extends StatefulWidget {
  const FarmersScreen({super.key});

  @override
  State<FarmersScreen> createState() => _FarmersScreenState();
}

class _FarmersScreenState extends State<FarmersScreen> {
  final _search = TextEditingController();
  String _query = '';
  bool _includeInactive = false;
  _Sort _sort = _Sort.number;

  List<Farmer>? _farmers;
  Object? _error;

  /// أرقام الموسم لكل مزارع، تُحسب مرة واحدة من purchases.list عند كل تحميل.
  Map<String, FarmerFigures>? _figures;
  Object? _figuresError;

  bool _loading = false;
  int _request = 0;
  bool _started = false;
  DataChanges? _changes;

  /// مزارعون يجري تغيير حالتهم الآن (يمنع الضغط المزدوج).
  final _busy = <String>{};
  final _statusRequest = SubmissionRequestId();
  _Notice? _notice;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final changes = AppScope.of(context).changes;
    if (!identical(changes, _changes)) {
      _changes?.removeListener(_onDataChanged);
      _changes = changes..addListener(_onDataChanged);
    }
    if (_started) return;
    _started = true;
    unawaited(_load());
  }

  @override
  void dispose() {
    _changes?.removeListener(_onDataChanged);
    _search.dispose();
    super.dispose();
  }

  void _onDataChanged() {
    if (mounted) unawaited(_load());
  }

  static Future<(T?, Object?)> _settle<T>(Future<T> f) async {
    try {
      return (await f, null);
    } catch (e) {
      return (null, e);
    }
  }

  Future<void> _load() async {
    final api = AppScope.of(context).api;
    final request = ++_request;
    setState(() => _loading = true);
    final farmersF = _settle(api.listFarmers(includeInactive: _includeInactive));
    final purchasesF = _settle(api.listPurchases());
    final (farmers, farmersError) = await farmersF;
    final (purchases, purchasesError) = await purchasesF;
    if (!mounted || request != _request) return;
    setState(() {
      _loading = false;
      if (farmers != null) {
        _farmers = farmers;
        _error = null;
      } else if (_farmers == null) {
        _error = farmersError;
      } else {
        _notice = (
          kind: BannerKind.error,
          message: 'تعذّر تحديث القائمة: ${errorMessage(farmersError!)} المعروض الآن آخر بيانات وصلت.',
          refresh: true,
        );
      }
      if (purchases != null) {
        _figures = farmerFiguresFrom(purchases);
        _figuresError = null;
      } else {
        _figuresError = purchasesError;
      }
    });
  }

  void _setIncludeInactive(bool v) {
    setState(() => _includeInactive = v);
    unawaited(_load());
  }

  // ------------------------------------------------------------------ الإجراءات

  Future<void> _add() async {
    final name = _query.trim();
    // نص البحث اسم مقترح فقط إن كان فيه حروف (لا رقم مزارع أو هاتف).
    final initial = RegExp(r'\p{L}', unicode: true).hasMatch(name) ? name : null;
    final saved = await AppRoutes.editFarmer(context, initialName: initial);
    if (saved == null || !mounted) return;
    setState(() {
      _farmers = [...?_farmers?.where((f) => f.id != saved.id), saved];
      _notice = (kind: BannerKind.success, message: 'أُضيف المزارع «${saved.name}» برقم ${saved.no}.', refresh: false);
    });
  }

  Future<void> _edit(Farmer f) async {
    final saved = await AppRoutes.editFarmer(context, farmer: f);
    if (saved == null || !mounted) return;
    setState(() {
      _farmers = [for (final x in _farmers ?? const <Farmer>[]) x.id == saved.id ? saved : x];
      _notice = (kind: BannerKind.success, message: 'حُفظت بيانات «${saved.name}».', refresh: false);
    });
  }

  Future<void> _setActive(Farmer f, bool active) async {
    if (_busy.contains(f.id)) return;
    final scope = AppScope.of(context);
    if (!active) {
      final ok = await showConfirmDialog(
        context,
        title: 'إيقاف المزارع؟',
        message: 'لن يظهر «${f.name}» في اختيار المزارع لعمليات جديدة، وتبقى عملياته ودفعاته كما هي. '
            'يمكنك إعادة تنشيطه لاحقًا.',
        confirmLabel: 'إيقاف المزارع',
        destructive: true,
        icon: Icons.person_off_outlined,
      );
      if (!ok || !mounted) return;
    }
    setState(() {
      _busy.add(f.id);
      _notice = null;
    });
    final requestId = _statusRequest.idFor({'id': f.id, 'expectedVersion': f.version, 'active': active});
    try {
      final updated = await scope.api.updateFarmer(
        id: f.id,
        expectedVersion: f.version,
        active: active,
        requestId: requestId,
      );
      _statusRequest.reset();
      if (!mounted) return;
      setState(() {
        _busy.remove(f.id);
        _farmers = [
          for (final x in _farmers ?? const <Farmer>[])
            if (x.id != updated.id)
              x
            else if (updated.active || _includeInactive)
              updated,
        ];
        _notice = (
          kind: BannerKind.success,
          message: active
              ? 'أُعيد تنشيط «${updated.name}».'
              : 'أُوقف «${updated.name}». فعّل «إظهار الموقوفين» لرؤيته وإعادة تنشيطه.',
          refresh: false,
        );
      });
      scope.changes.bump();
    } catch (e) {
      if (!mounted) return;
      final conflict = e is ApiException && e.code == ApiErrorCode.conflict;
      setState(() {
        _busy.remove(f.id);
        _notice = (
          kind: BannerKind.error,
          message: conflict ? 'عدّل شخص آخر هذا السجل، حدّث وأعد المحاولة.' : errorMessage(e),
          refresh: conflict,
        );
      });
    }
  }

  void _open(Farmer f) => unawaited(AppRoutes.openFarmerStatement(context, f.id));

  // ------------------------------------------------------------------ البناء

  List<Farmer> _visible(List<Farmer> all) {
    final list = all.where((f) => farmerMatches(f, _query)).toList();
    final figures = _figures ?? const {};
    int rem(Farmer f) => figures[f.id]?.remainingPiasters ?? 0;
    switch (_sort) {
      case _Sort.number:
        list.sort((a, b) => a.no.compareTo(b.no));
      case _Sort.remaining:
        list.sort((a, b) {
          final c = rem(b).compareTo(rem(a));
          return c != 0 ? c : a.no.compareTo(b.no);
        });
      case _Sort.name:
        list.sort((a, b) => normalizeArabic(a.name).compareTo(normalizeArabic(b.name)));
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final perms = AppScope.of(context).auth.user?.permissions ?? const UserPermissions();
    final canEdit = perms.addFarmers;
    final wide = isWideLayout(context);
    final farmers = _farmers;

    if (farmers == null) {
      if (_error != null) return _errorView(_error!, perms);
      return const LoadingSkeleton(tiles: 0, lines: 8, showHeaderCard: false);
    }

    if (farmers.isEmpty && !_includeInactive && _query.isEmpty && !_loading) {
      return _withHeader(
        wide,
        canEdit,
        EmptyState(
          icon: Icons.groups_outlined,
          title: 'لا يوجد مزارعون بعد',
          message: canEdit
              ? 'أضف المزارعين هنا، أو أثناء تسجيل أول شراء منهم. كل مزارع يأخذ رقمًا تلقائيًا.'
              : 'لم يُسجَّل أي مزارع بعد.',
          actionLabel: canEdit ? 'إضافة مزارع' : null,
          actionIcon: Icons.person_add_alt_1_outlined,
          onAction: canEdit ? _add : null,
          footer: _includeInactiveToggle(),
        ),
      );
    }

    final visible = _visible(farmers);
    final header = <Widget>[
      if (wide) ...[_pageHeader(canEdit, farmers), const SizedBox(height: 16)],
      ..._toolbar(canEdit, wide),
      ..._banners(),
      const SizedBox(height: 12),
      _summary(visible),
      const SizedBox(height: 10),
    ];

    final Widget body;
    if (visible.isEmpty) {
      body = ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: _padding(wide),
        children: [_center(wide, Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [...header, _noMatch(canEdit)]))],
      );
    } else if (wide) {
      body = ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: _padding(wide),
        children: [
          _center(
            wide,
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [...header, _FarmersTable(
                farmers: visible,
                figures: _figures,
                canEdit: canEdit,
                busy: _busy,
                onOpen: _open,
                onEdit: _edit,
                onSetActive: _setActive,
              )],
            ),
          ),
        ],
      );
    } else {
      body = ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: _padding(wide),
        itemCount: header.length + visible.length,
        itemBuilder: (context, i) {
          if (i < header.length) return _center(wide, header[i]);
          final f = visible[i - header.length];
          return _center(
            wide,
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _FarmerCard(
                farmer: f,
                figures: _figures == null ? null : (_figures![f.id] ?? FarmerFigures.zero),
                canEdit: canEdit,
                busy: _busy.contains(f.id),
                onOpen: () => _open(f),
                onEdit: () => _edit(f),
                onSetActive: (v) => _setActive(f, v),
              ),
            ),
          );
        },
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 3,
          child: _loading ? const LinearProgressIndicator(minHeight: 3, color: AppColors.pomegranate) : null,
        ),
        Expanded(
          child: wide ? body : RefreshIndicator(color: AppColors.pomegranate, onRefresh: _load, child: body),
        ),
      ],
    );
  }

  EdgeInsets _padding(bool wide) => wide ? const EdgeInsets.fromLTRB(32, 24, 32, 40) : const EdgeInsets.fromLTRB(16, 4, 16, 24);

  Widget _center(bool wide, Widget child) => ResponsiveCenter(maxWidth: wide ? 1400 : 720, child: child);

  /// الحالة الفارغة مع عنوان الصفحة على الشاشات العريضة.
  Widget _withHeader(bool wide, bool canEdit, Widget body) {
    if (!wide) return body;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(padding: const EdgeInsets.fromLTRB(32, 24, 32, 0), child: _pageHeader(canEdit, const [])),
        Expanded(child: body),
      ],
    );
  }

  Widget _errorView(Object error, UserPermissions perms) {
    final shell = ShellScope.maybeOf(context);
    final canOpenSettings = perms.manageSettings && (shell?.canOpen(ShellSection.settings) ?? false);
    return ErrorView.fromError(
      error,
      title: 'تعذّر تحميل المزارعين',
      onRetry: _load,
      onOpenSheetSettings: canOpenSettings ? () => shell!.select(ShellSection.settings) : null,
    );
  }

  Widget _pageHeader(bool canEdit, List<Farmer> farmers) => PageHeader(
        title: 'المزارعون',
        subtitle: farmers.isEmpty ? null : 'كل مزارع برقمه وأرقام موسمه. اضغط على المزارع لفتح كشف حسابه.',
        actions: [
          AppButton(
            label: 'تحديث',
            icon: Icons.refresh,
            height: 48,
            variant: AppButtonVariant.secondary,
            busy: _loading,
            busyLabel: 'جارٍ التحديث',
            onPressed: _load,
          ),
          if (canEdit) AppButton(label: 'إضافة مزارع', icon: Icons.person_add_alt_1_outlined, height: 48, onPressed: _add),
        ],
      );

  Widget _includeInactiveToggle() =>
      ToggleFilterButton(label: 'إظهار الموقوفين', value: _includeInactive, onChanged: _setIncludeInactive);

  List<Widget> _toolbar(bool canEdit, bool wide) {
    final search = SearchField(
      controller: _search,
      hint: 'ابحث بالاسم أو القرية أو الرقم أو الهاتف',
      onChanged: (v) => setState(() => _query = v),
    );
    final sort = FilterMenuButton<_Sort>(
      icon: Icons.sort,
      label: 'الترتيب: ${_sort.label}',
      tooltip: 'ترتيب القائمة',
      options: [for (final s in _Sort.values) (s, s.label)],
      selected: _sort,
      onSelected: (s) => setState(() => _sort = s),
    );
    if (wide) {
      return [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [SizedBox(width: 420, child: search), sort, _includeInactiveToggle()],
        ),
      ];
    }
    return [
      search,
      const SizedBox(height: 10),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          sort,
          _includeInactiveToggle(),
          if (canEdit)
            AppButton(label: 'إضافة مزارع', icon: Icons.person_add_alt_1_outlined, height: 48, onPressed: _add),
        ],
      ),
    ];
  }

  List<Widget> _banners() {
    final notice = _notice;
    return [
      if (notice != null) ...[
        const SizedBox(height: 12),
        InlineBanner(
          kind: notice.kind,
          message: notice.message,
          actionLabel: notice.refresh ? 'تحديث' : null,
          onAction: notice.refresh ? _load : null,
        ),
      ],
      if (_figuresError != null) ...[
        const SizedBox(height: 12),
        InlineBanner(
          kind: BannerKind.warning,
          title: 'تعذّر تحميل أرقام الموسم',
          message: errorMessage(_figuresError!),
          actionLabel: 'إعادة المحاولة',
          onAction: _load,
        ),
      ],
    ];
  }

  Widget _summary(List<Farmer> visible) {
    final figures = _figures;
    final count = farmersCountLabel(visible.length);
    final remaining = figures == null
        ? null
        : visible.fold<int>(0, (s, f) => s + (figures[f.id]?.remainingPiasters ?? 0));
    return Wrap(
      spacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(_query.isEmpty ? count : '$count يطابق البحث', style: UiText.label),
        if (remaining != null) ...[
          const Text('·', style: UiText.label),
          Text('المتبقي لهم', style: UiText.label.copyWith(color: AppColors.amber)),
          MoneyText(remaining, fontSize: 14, unitFontSize: 12, color: AppColors.amber),
        ],
      ],
    );
  }

  Widget _noMatch(bool canEdit) {
    final q = _query.trim();
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            q.isEmpty ? 'لا يوجد مزارعون في هذه القائمة.' : 'لا يوجد مزارع يطابق «$q».',
            style: UiText.cardTitle,
          ),
          const SizedBox(height: 4),
          Text(
            _includeInactive
                ? 'جرّب كتابة جزء من الاسم فقط، أو رقم المزارع، أو آخر أرقام هاتفه.'
                : 'جرّب كتابة جزء من الاسم فقط، أو فعّل «إظهار الموقوفين».',
            style: UiText.muted,
          ),
          if (canEdit && q.isNotEmpty) ...[
            const SizedBox(height: 12),
            AppButton(
              label: 'إضافة مزارع جديد',
              icon: Icons.person_add_alt_1_outlined,
              variant: AppButtonVariant.secondary,
              onPressed: _add,
            ),
          ],
        ],
      ),
    );
  }
}

// ============================================================================ عناصر القائمة

/// «رقم 12 · بني عدي» ثم الهاتف باتجاه LTR.
class _FarmerMeta extends StatelessWidget {
  const _FarmerMeta({required this.farmer});

  final Farmer farmer;

  @override
  Widget build(BuildContext context) {
    final f = farmer;
    return Wrap(
      spacing: 6,
      runSpacing: 2,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text('رقم ${f.no}', style: UiText.small),
        if (f.village != null) ...[const Text('·', style: UiText.small), Text(f.village!, style: UiText.small)],
        if (f.phone != null) ...[
          const Text('·', style: UiText.small),
          Text(f.phone!, textDirection: TextDirection.ltr, style: UiText.small),
        ],
      ],
    );
  }
}

/// قائمة إجراءات المزارع: تعديل، إيقاف أو إعادة تنشيط.
class _FarmerMenu extends StatelessWidget {
  const _FarmerMenu({required this.farmer, required this.busy, required this.onEdit, required this.onSetActive});

  final Farmer farmer;
  final bool busy;
  final VoidCallback onEdit;
  final ValueChanged<bool> onSetActive;

  @override
  Widget build(BuildContext context) {
    if (busy) {
      return const SizedBox(
        width: 48,
        height: 48,
        child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.5))),
      );
    }
    return PopupMenuButton<String>(
      tooltip: 'إجراءات ${farmer.name}',
      icon: const Icon(Icons.more_vert, color: AppColors.inkSecondary),
      style: IconButton.styleFrom(minimumSize: const Size(48, 48)),
      color: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      onSelected: (v) => switch (v) {
        'edit' => onEdit(),
        'deactivate' => onSetActive(false),
        _ => onSetActive(true),
      },
      itemBuilder: (context) => [
        const PopupMenuItem(
          value: 'edit',
          height: 48,
          child: Row(children: [Icon(Icons.edit_outlined, size: 20), SizedBox(width: 10), Text('تعديل البيانات')]),
        ),
        if (farmer.active)
          const PopupMenuItem(
            value: 'deactivate',
            height: 48,
            child: Row(
              children: [
                Icon(Icons.person_off_outlined, size: 20, color: AppColors.error),
                SizedBox(width: 10),
                Text('إيقاف المزارع', style: TextStyle(color: AppColors.error)),
              ],
            ),
          )
        else
          const PopupMenuItem(
            value: 'reactivate',
            height: 48,
            child: Row(
              children: [
                Icon(Icons.person_outline, size: 20, color: AppColors.leaf),
                SizedBox(width: 10),
                Text('إعادة تنشيط المزارع'),
              ],
            ),
          ),
      ],
    );
  }
}

Widget _statusChip(Farmer f, {bool dense = true}) => f.active
    ? StatusChip(StatusKind.active, dense: dense)
    : StatusChip(StatusKind.disabled, label: 'موقوف', dense: dense);

/// بطاقة مزارع (الهاتف): الاسم والرقم والقرية والهاتف، ثم أرقام الموسم والمتبقي بارزًا.
class _FarmerCard extends StatelessWidget {
  const _FarmerCard({
    required this.farmer,
    required this.figures,
    required this.canEdit,
    required this.busy,
    required this.onOpen,
    required this.onEdit,
    required this.onSetActive,
  });

  final Farmer farmer;

  /// null = لم تُحمَّل أرقام الموسم.
  final FarmerFigures? figures;
  final bool canEdit;
  final bool busy;
  final VoidCallback onOpen;
  final VoidCallback onEdit;
  final ValueChanged<bool> onSetActive;

  @override
  Widget build(BuildContext context) {
    final f = farmer;
    final fig = figures;
    return Semantics(
      button: true,
      hint: 'فتح كشف حساب المزارع',
      child: AppCard(
        onTap: onOpen,
        padding: const EdgeInsetsDirectional.fromSTEB(14, 12, 4, 12),
        child: Opacity(
          opacity: f.active ? 1 : 0.75,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  InitialsAvatar(
                    AppUser.initialsOf(f.name),
                    size: 40,
                    background: f.active ? UiColors.beige : UiColors.greyBg,
                    foreground: f.active ? UiColors.label : AppColors.inkMuted,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(f.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, height: 1.4)),
                            if (!f.active) _statusChip(f),
                          ],
                        ),
                        _FarmerMeta(farmer: f),
                      ],
                    ),
                  ),
                  if (canEdit)
                    _FarmerMenu(farmer: f, busy: busy, onEdit: onEdit, onSetActive: onSetActive)
                  else
                    const SizedBox(width: 10),
                ],
              ),
              if (fig != null) ...[
                const SizedBox(height: 10),
                Padding(padding: const EdgeInsetsDirectional.only(end: 10), child: _FiguresRow(figures: fig)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// «3 عمليات · 245.5 كغ · القيمة 3,500.00 · المدفوع 2,000.00» والمتبقي بارزًا في الطرف الآخر.
class _FiguresRow extends StatelessWidget {
  const _FiguresRow({required this.figures});

  final FarmerFigures figures;

  @override
  Widget build(BuildContext context) {
    final fig = figures;
    if (fig.operations == 0) {
      return const Text('لا عمليات شراء هذا الموسم.', style: UiText.small);
    }
    return Container(
      padding: const EdgeInsets.only(top: 10),
      decoration: const BoxDecoration(border: Border(top: BorderSide(color: UiColors.divider))),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${operationsLabel(fig.operations)} · ${formatWeight(fig.weightGrams)} كغ', style: UiText.small),
                Text(
                  'القيمة ${formatMoney(fig.valuePiasters)} · المدفوع ${formatMoney(fig.paidPiasters)}',
                  style: UiText.small,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _RemainingBlock(remaining: fig.remainingPiasters),
        ],
      ),
    );
  }
}

class _RemainingBlock extends StatelessWidget {
  const _RemainingBlock({required this.remaining});

  final int remaining;

  @override
  Widget build(BuildContext context) {
    if (remaining <= 0) return const StatusChip(StatusKind.paid, label: 'لا متبقي');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text('المتبقي', style: UiText.small.copyWith(color: AppColors.amber, fontWeight: FontWeight.w600)),
        MoneyText(remaining, fontSize: 17, color: AppColors.amber, unitFontSize: 12),
      ],
    );
  }
}

/// جدول المزارعين (الشاشات العريضة).
class _FarmersTable extends StatelessWidget {
  const _FarmersTable({
    required this.farmers,
    required this.figures,
    required this.canEdit,
    required this.busy,
    required this.onOpen,
    required this.onEdit,
    required this.onSetActive,
  });

  final List<Farmer> farmers;
  final Map<String, FarmerFigures>? figures;
  final bool canEdit;
  final Set<String> busy;
  final ValueChanged<Farmer> onOpen;
  final ValueChanged<Farmer> onEdit;
  final void Function(Farmer, bool) onSetActive;

  @override
  Widget build(BuildContext context) {
    const head = TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.inkMuted);
    final figs = figures;
    String money(int? v) => v == null ? '—' : formatMoney(v);
    return AppCard(
      padding: const EdgeInsets.symmetric(vertical: 4),
      clip: true,
      child: LayoutBuilder(
        builder: (context, c) => SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: c.maxWidth),
            child: DataTable(
              showCheckboxColumn: false,
              headingRowColor: const WidgetStatePropertyAll(UiColors.tableHead),
              headingRowHeight: 44,
              dataRowMinHeight: 52,
              dataRowMaxHeight: 64,
              horizontalMargin: 18,
              columnSpacing: 18,
              headingTextStyle: head,
              columns: [
                const DataColumn(label: Text('رقم'), numeric: true),
                const DataColumn(label: Text('المزارع')),
                const DataColumn(label: Text('القرية')),
                const DataColumn(label: Text('الهاتف')),
                const DataColumn(label: Text('العمليات'), numeric: true),
                const DataColumn(label: Text('الوزن (كغ)'), numeric: true),
                const DataColumn(label: Text('القيمة (ج.م)'), numeric: true),
                const DataColumn(label: Text('المدفوع (ج.م)'), numeric: true),
                const DataColumn(label: Text('المتبقي (ج.م)'), numeric: true),
                const DataColumn(label: Text('الحالة')),
                if (canEdit) const DataColumn(label: Text('')),
              ],
              rows: [
                for (final f in farmers)
                  () {
                    final fig = figs == null ? null : (figs[f.id] ?? FarmerFigures.zero);
                    final remaining = fig?.remainingPiasters;
                    return DataRow(
                      onSelectChanged: (_) => onOpen(f),
                      cells: [
                        DataCell(Text('${f.no}')),
                        DataCell(Text(f.name, style: const TextStyle(fontWeight: FontWeight.w700))),
                        DataCell(Text(f.village ?? '—')),
                        DataCell(Text(f.phone ?? '—', textDirection: TextDirection.ltr)),
                        DataCell(Text(fig == null ? '—' : formatCount(fig.operations))),
                        DataCell(Text(fig == null ? '—' : formatWeight(fig.weightGrams))),
                        DataCell(Text(money(fig?.valuePiasters))),
                        DataCell(Text(money(fig?.paidPiasters))),
                        DataCell(remaining == null
                            ? const Text('—')
                            : NumberText(
                                formatMoney(remaining),
                                fontSize: 14.5,
                                color: remaining > 0 ? AppColors.amber : AppColors.leaf,
                              )),
                        DataCell(_statusChip(f, dense: false)),
                        if (canEdit)
                          DataCell(_FarmerMenu(
                            farmer: f,
                            busy: busy.contains(f.id),
                            onEdit: () => onEdit(f),
                            onSetActive: (v) => onSetActive(f, v),
                          )),
                      ],
                    );
                  }(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
