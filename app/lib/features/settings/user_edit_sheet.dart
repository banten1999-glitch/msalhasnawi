import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../core/api/api_exception.dart';
import '../../core/models/user.dart';
import '../../theme/app_theme.dart';
import '../../ui/ui.dart';
import 'settings_widgets.dart';
import 'user_rules.dart';

/// يفتح تعديل المستخدم: لوحة من الأسفل على الهاتف، ونافذة على الشاشات العريضة.
/// يعيد المستخدم بعد الحفظ، أو null عند الإلغاء.
Future<AppUser?> showUserEditor(
  BuildContext context, {
  required AppUser user,
  required List<AppUser> allUsers,
  required bool isSelf,
}) {
  final editor = UserEditor(user: user, allUsers: allUsers, isSelf: isSelf);
  if (isWideLayout(context)) {
    return showDialog<AppUser>(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 560, maxHeight: 820), child: editor),
      ),
    );
  }
  return showModalBottomSheet<AppUser>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.white,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (context) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: editor,
    ),
  );
}

/// نموذج تعديل مستخدم: الاسم، الدور، الحالة، وصلاحيات موظف الإدخال الست.
class UserEditor extends StatefulWidget {
  const UserEditor({super.key, required this.user, required this.allUsers, required this.isSelf});

  final AppUser user;
  final List<AppUser> allUsers;
  final bool isSelf;

  @override
  State<UserEditor> createState() => _UserEditorState();
}

class _UserEditorState extends State<UserEditor> {
  late AppUser _base = widget.user;
  late final _name = TextEditingController(text: widget.user.name);
  late UserRole _role = widget.user.role;
  late bool _active = widget.user.active;
  late UserPermissions _perms = widget.user.permissions;

  bool _saving = false;
  String? _nameError;
  String? _roleError;
  String? _statusError;
  String? _permsError;
  String? _error;

  /// عند CONFLICT: النسخة الحالية من الخادم لعرضها.
  AppUser? _conflictCurrent;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  String? get _locked => lockedReason(_base, widget.allUsers);

  bool get _changed =>
      _name.text.trim() != _base.name ||
      _role != _base.role ||
      _active != _base.active ||
      (_role == UserRole.entry && !samePermissions(_perms, _base.permissions));

  void _clearErrors() {
    _nameError = null;
    _roleError = null;
    _statusError = null;
    _permsError = null;
    _error = null;
  }

  void _loadFrom(AppUser u) {
    setState(() {
      _base = u;
      _name.text = u.name;
      _role = u.role;
      _active = u.active;
      _perms = u.permissions;
      _conflictCurrent = null;
      _clearErrors();
    });
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    setState(_clearErrors);
    if (name.isEmpty) {
      setState(() => _nameError = 'اكتب اسم المستخدم كما سيظهر في السجلات، مثل كريم عبد الله.');
      return;
    }
    final roleChanged = _role != _base.role;
    final permsChanged = !samePermissions(_perms, _base.permissions);
    setState(() => _saving = true);
    try {
      final updated = await AppScope.of(context).api.updateUser(
        id: _base.id,
        expectedVersion: _base.version,
        name: name != _base.name ? name : null,
        role: roleChanged ? _role : null,
        active: _active != _base.active ? _active : null,
        permissions: _role == UserRole.entry && (roleChanged || permsChanged) ? _perms : null,
      );
      if (!mounted) return;
      Navigator.of(context).pop(updated);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _applyError(e);
      });
    }
  }

  void _applyError(Object e) {
    if (e is! ApiException) {
      _error = errorMessage(e);
      return;
    }
    if (e.code == ApiErrorCode.conflict) {
      final current = e.details['current'];
      _conflictCurrent = current is Map ? _tryParse(current.cast<String, dynamic>()) : null;
      _error = e.message;
      return;
    }
    final field = e.field ?? '';
    if (e.code == ApiErrorCode.validation && field == 'name') {
      _nameError = e.message;
    } else if (e.code == ApiErrorCode.validation && field == 'role') {
      _roleError = e.message;
    } else if (e.code == ApiErrorCode.validation && field == 'status') {
      _statusError = e.message;
    } else if (e.code == ApiErrorCode.validation && field.startsWith('permissions')) {
      _permsError = e.message;
    } else {
      _error = e.message;
    }
  }

  static AppUser? _tryParse(Map<String, dynamic> j) {
    try {
      return AppUser.fromJson(j);
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final locked = _locked;
    final u = _base;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Semantics(
                      header: true,
                      child: Text(
                        'صلاحيات ${u.name}',
                        style: const TextStyle(fontFamily: AppFonts.display, fontSize: 19, fontWeight: FontWeight.w700),
                      ),
                    ),
                    Text(u.email, textDirection: TextDirection.ltr, style: UiText.small),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'إغلاق',
                onPressed: _saving ? null : () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close),
                style: IconButton.styleFrom(minimumSize: const Size(48, 48)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (widget.isSelf) ...[
            const InlineBanner(
              kind: BannerKind.info,
              title: 'هذا حسابك',
              message: 'حفظ أي تغيير على حسابك يُنهي جلستك الحالية، وسيُطلب منك تسجيل الدخول بحساب Google من جديد.',
            ),
            const SizedBox(height: 12),
          ],
          if (_error != null) ...[
            InlineBanner(
              kind: BannerKind.error,
              message: _error!,
              actionLabel: _conflictCurrent != null ? 'عرض البيانات الحالية' : null,
              onAction: _conflictCurrent != null ? () => _loadFrom(_conflictCurrent!) : null,
            ),
            const SizedBox(height: 12),
          ],
          TextField(
            controller: _name,
            enabled: !_saving,
            textInputAction: TextInputAction.done,
            onChanged: (_) => setState(() => _nameError = null),
            decoration: uiInputDecoration(errorText: _nameError).copyWith(labelText: 'الاسم'),
          ),
          const SizedBox(height: 14),
          LabeledField(
            label: 'الدور',
            errorText: _roleError,
            child: SegmentedChoice<UserRole>(
              semanticLabel: 'الدور',
              hasError: _roleError != null,
              options: [for (final r in UserRole.values) SegmentOption(r, r.label)],
              value: _role,
              onChanged: locked != null || _saving
                  ? null
                  : (r) => setState(() {
                      _role = r;
                      _roleError = null;
                    }),
            ),
          ),
          if (locked != null) ...[const SizedBox(height: 8), IconNote(icon: Icons.lock_outline, text: locked)],
          const SizedBox(height: 6),
          _SwitchRow(
            title: 'الحساب نشط',
            subtitle: 'التعطيل يمنع الدخول فورًا دون حذف سجله',
            value: _active,
            onChanged: locked != null || _saving
                ? null
                : (v) => setState(() {
                    _active = v;
                    _statusError = null;
                  }),
          ),
          if (_statusError != null) FieldError(_statusError!),
          const SizedBox(height: 10),
          Text(_role == UserRole.entry ? 'صلاحيات موظف الإدخال' : 'الصلاحيات', style: UiText.fieldLabel),
          if (_role == UserRole.admin)
            const Padding(
              padding: EdgeInsets.only(top: 4),
              child: Text('المدير يملك كل الصلاحيات، ومنها إدارة المستخدمين والإعدادات.', style: UiText.small),
            )
          else if (_role == UserRole.viewer)
            const Padding(
              padding: EdgeInsets.only(top: 4),
              child: Text('«مشاهدة فقط» يقرأ البيانات والتقارير دون أي إضافة أو تعديل.', style: UiText.small),
            ),
          for (final p in editablePermissions)
            _SwitchRow(
              title: p.$2,
              value: _role == UserRole.admin || (_role == UserRole.entry && permissionValue(_perms, p.$1)),
              highlight:
                  _role == UserRole.entry && permissionValue(_perms, p.$1) != permissionValue(u.permissions, p.$1),
              onChanged: _role != UserRole.entry || _saving
                  ? null
                  : (v) => setState(() {
                      _perms = withPermission(_perms, p.$1, v);
                      _permsError = null;
                    }),
            ),
          const _LockedRow(title: 'إعادة فتح البرادات', subtitle: 'للمدير فقط'),
          if (_permsError != null) FieldError(_permsError!),
          const SizedBox(height: 14),
          const ServerEnforcedNote(),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: AppButton(
                  label: 'إلغاء',
                  variant: AppButtonVariant.secondary,
                  onPressed: _saving ? null : () => Navigator.of(context).pop(),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: AppButton(
                  label: 'حفظ التغييرات',
                  busy: _saving,
                  busyLabel: 'جارٍ الحفظ',
                  onPressed: _changed && !_saving ? _save : null,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.title,
    required this.value,
    required this.onChanged,
    this.subtitle,
    this.highlight = false,
  });

  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final enabled = onChanged != null;
    return Container(
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: UiColors.divider)),
      ),
      // الخلفية على Material حتى يظهر أثر اللمس فوقها.
      child: Material(
        color: highlight ? UiColors.paidBg : Colors.transparent,
        child: SwitchListTile(
          value: value,
          onChanged: onChanged,
          contentPadding: const EdgeInsetsDirectional.only(start: 4, end: 0),
          activeThumbColor: Colors.white,
          activeTrackColor: AppColors.leaf,
          inactiveTrackColor: UiColors.fieldBorder,
          inactiveThumbColor: Colors.white,
          trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
          title: Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: enabled ? AppColors.ink : AppColors.inkMuted,
              height: 1.4,
            ),
          ),
          subtitle: subtitle == null ? null : Text(subtitle!, style: UiText.small),
        ),
      ),
    );
  }
}

class _LockedRow extends StatelessWidget {
  const _LockedRow({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 56),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: UiColors.divider)),
      ),
      padding: const EdgeInsetsDirectional.only(start: 4, end: 12, top: 8, bottom: 8),
      child: Semantics(
        container: true,
        label: '$title — $subtitle',
        excludeSemantics: true,
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.inkMuted),
                  ),
                  Text(subtitle, style: UiText.small),
                ],
              ),
            ),
            const Icon(Icons.lock_outline, size: 20, color: AppColors.inkMuted),
          ],
        ),
      ),
    );
  }
}
