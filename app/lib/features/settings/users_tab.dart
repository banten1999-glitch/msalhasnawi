import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../core/api/api_exception.dart';
import '../../core/models/user.dart';
import '../../theme/app_theme.dart';
import '../../ui/ui.dart';
import 'settings_widgets.dart';
import 'user_edit_sheet.dart';
import 'user_rules.dart';

/// تبويب «المستخدمون»: إضافة بريد إلى القائمة المسموح بها، وقائمة المستخدمين، وتعديل الدور والصلاحيات.
class UsersTab extends StatefulWidget {
  const UsersTab({super.key});

  @override
  State<UsersTab> createState() => _UsersTabState();
}

class _UsersTabState extends State<UsersTab> {
  List<AppUser>? _users;
  Object? _loadError;
  bool _started = false;

  final _email = TextEditingController();
  final _name = TextEditingController();
  UserRole _role = UserRole.entry;
  bool _adding = false;
  String? _emailError;
  String? _nameError;
  String? _roleError;
  String? _addError;

  ({BannerKind kind, String message})? _notice;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    unawaited(_load());
  }

  @override
  void dispose() {
    _email.dispose();
    _name.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loadError = null);
    try {
      final users = await AppScope.of(context).api.listUsers();
      if (!mounted) return;
      setState(() => _users = users);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        if (_users == null) {
          _loadError = e;
        } else {
          _notice = (kind: BannerKind.error, message: 'تعذّر تحديث القائمة: ${errorMessage(e)}');
        }
      });
    }
  }

  // ------------------------------------------------------------------ الإضافة

  String? _validateEmail(String email) {
    if (email.isEmpty) return 'اكتب بريد Gmail للمستخدم الجديد، مثل name@gmail.com.';
    if (!emailPattern.hasMatch(email)) {
      return 'البريد «$email» غير صحيح. اكتب بريد Gmail كاملًا مثل name@gmail.com.';
    }
    final exists = (_users ?? const <AppUser>[]).any((u) => u.email.toLowerCase() == email);
    if (exists) return 'البريد «$email» موجود في القائمة بالفعل. عدّل المستخدم من القائمة بدل إضافته مرة أخرى.';
    return null;
  }

  Future<void> _add() async {
    final email = _email.text.replaceAll(RegExp(r'\s+'), '').toLowerCase();
    final name = _name.text.trim();
    final emailError = _validateEmail(email);
    final nameError = name.isEmpty ? 'اكتب اسم المستخدم كما سيظهر في السجلات، مثل كريم عبد الله.' : null;
    setState(() {
      _emailError = emailError;
      _nameError = nameError;
      _roleError = null;
      _addError = null;
      _notice = null;
    });
    if (emailError != null || nameError != null) return;

    setState(() => _adding = true);
    try {
      final user = await AppScope.of(context).api.addUser(email: email, name: name, role: _role);
      if (!mounted) return;
      setState(() {
        _adding = false;
        _users = [...?_users, user];
        _email.clear();
        _name.clear();
        _notice = (
          kind: BannerKind.success,
          message: 'أُضيف ${user.name} (${user.email}) بدور «${user.role.label}». يمكنه الآن الدخول بحساب Google هذا.'
              '${user.role == UserRole.entry ? ' راجع صلاحياته من القائمة إن لزم.' : ''}',
        );
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _adding = false;
        final field = e is ApiException && e.code == ApiErrorCode.validation ? e.field : null;
        switch (field) {
          case 'email':
            _emailError = errorMessage(e);
          case 'name':
            _nameError = errorMessage(e);
          case 'role':
            _roleError = errorMessage(e);
          default:
            _addError = errorMessage(e);
        }
      });
    }
  }

  // ------------------------------------------------------------------ التعديل

  Future<void> _edit(AppUser user) async {
    final scope = AppScope.of(context);
    final users = _users ?? const <AppUser>[];
    final isSelf = scope.auth.user?.id == user.id;
    final updated = await showUserEditor(context, user: user, allUsers: users, isSelf: isSelf);
    if (updated == null || !mounted) return;
    setState(() {
      _users = [for (final u in users) u.id == updated.id ? updated : u];
      _notice = (kind: BannerKind.success, message: 'حُفظت تغييرات ${updated.name}.');
    });
    if (isSelf) scope.auth.updateUser(updated);
  }

  // ------------------------------------------------------------------ البناء

  @override
  Widget build(BuildContext context) {
    final users = _users;
    if (users == null) {
      if (_loadError != null) {
        return ErrorView.fromError(_loadError!, onRetry: _load, title: 'تعذّر تحميل المستخدمين');
      }
      return const LoadingSkeleton(tiles: 0, lines: 6);
    }
    final notice = _notice;
    return SettingsTabBody(
      onRefresh: _load,
      children: [
        if (notice != null) InlineBanner(kind: notice.kind, message: notice.message),
        _addCard(),
        _listCard(users),
        const ServerEnforcedNote(),
      ],
    );
  }

  Widget _addCard() {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const CardTitle('إضافة مستخدم'),
          const SizedBox(height: 10),
          LabeledField(
            label: 'بريد Gmail',
            child: TextField(
              controller: _email,
              enabled: !_adding,
              keyboardType: TextInputType.emailAddress,
              textDirection: TextDirection.ltr,
              textAlign: TextAlign.left,
              autocorrect: false,
              textInputAction: TextInputAction.next,
              onChanged: (_) {
                if (_emailError != null) setState(() => _emailError = null);
              },
              decoration: uiInputDecoration(
                hint: 'name@gmail.com',
                errorText: _emailError,
                helperText: 'حساب Google الذي سيدخل به المستخدم.',
                prefixIcon: const Icon(Icons.mail_outline, color: AppColors.inkMuted, size: 20),
              ),
            ),
          ),
          const SizedBox(height: 12),
          LabeledField(
            label: 'الاسم',
            child: TextField(
              controller: _name,
              enabled: !_adding,
              textInputAction: TextInputAction.done,
              onChanged: (_) {
                if (_nameError != null) setState(() => _nameError = null);
              },
              decoration: uiInputDecoration(hint: 'مثل: كريم عبد الله', errorText: _nameError),
            ),
          ),
          const SizedBox(height: 12),
          LabeledField(
            label: 'الدور',
            errorText: _roleError,
            child: SegmentedChoice<UserRole>(
              semanticLabel: 'الدور',
              hasError: _roleError != null,
              options: [for (final r in UserRole.values) SegmentOption(r, r.label)],
              value: _role,
              onChanged: _adding ? null : (r) => setState(() => _role = r),
            ),
          ),
          if (_addError != null) ...[
            const SizedBox(height: 10),
            InlineBanner(kind: BannerKind.error, message: _addError!),
          ],
          const SizedBox(height: 14),
          AppButton(
            label: 'إضافة إلى القائمة المسموح بها',
            icon: Icons.person_add_alt_1_outlined,
            busy: _adding,
            busyLabel: 'جارٍ الإضافة',
            onPressed: _add,
          ),
        ],
      ),
    );
  }

  Widget _listCard(List<AppUser> users) {
    final active = users.where((u) => u.active).length;
    final disabled = users.length - active;
    final me = AppScope.of(context).auth.user?.id;
    return AppCard(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CardTitle(
            'المستخدمون (${users.length})',
            trailing: Text('$active نشط · $disabled معطّل', style: UiText.small),
          ),
          const SizedBox(height: 4),
          if (users.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 14),
              child: Text('لا يوجد مستخدمون بعد. أضف أول مستخدم من النموذج أعلاه.', style: UiText.muted),
            ),
          for (final u in users) _UserRow(user: u, isSelf: u.id == me, locked: lockedReason(u, users), onTap: () => _edit(u)),
        ],
      ),
    );
  }
}

class _UserRow extends StatelessWidget {
  const _UserRow({required this.user, required this.isSelf, required this.locked, required this.onTap});

  final AppUser user;
  final bool isSelf;
  final String? locked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final u = user;
    final (Color avBg, Color avFg) = !u.active
        ? (UiColors.greyBg, AppColors.inkMuted)
        : u.role == UserRole.admin
            ? (AppColors.leaf, Colors.white)
            : (UiColors.beige, UiColors.label);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          button: true,
          hint: 'تعديل الدور والصلاحيات',
          child: InkWell(
            onTap: onTap,
            child: Container(
              constraints: const BoxConstraints(minHeight: 60),
              decoration: const BoxDecoration(border: Border(top: BorderSide(color: UiColors.divider))),
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Opacity(
                opacity: u.active ? 1 : 0.7,
                child: Row(
                  children: [
                    InitialsAvatar(u.initials, size: 40, background: avBg, foreground: avFg),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text.rich(
                            TextSpan(
                              children: [
                                TextSpan(
                                  text: u.name,
                                  style: TextStyle(decoration: u.active ? null : TextDecoration.lineThrough),
                                ),
                                if (isSelf)
                                  const TextSpan(
                                    text: ' (أنت)',
                                    style: TextStyle(fontWeight: FontWeight.w500, fontSize: 12.5, color: AppColors.inkMuted),
                                  ),
                              ],
                            ),
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5, height: 1.4),
                          ),
                          Text(
                            u.email,
                            textDirection: TextDirection.ltr,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12, color: AppColors.inkMuted, height: 1.4),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        RoleChip(u.role),
                        const SizedBox(height: 4),
                        StatusChip(u.active ? StatusKind.active : StatusKind.disabled, dense: true),
                      ],
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.chevron_right, color: AppColors.inkMuted, size: 20),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (locked != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: IconNote(icon: Icons.lock_outline, text: locked!),
          ),
      ],
    );
  }
}
