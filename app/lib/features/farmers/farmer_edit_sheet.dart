import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/app_scope.dart';
import '../../core/api/api_exception.dart';
import '../../core/api/request_id.dart';
import '../../core/models/records.dart';
import '../../theme/app_theme.dart';
import '../../ui/ui.dart';
import 'text_search.dart';

/// يضيف مزارعًا ([farmer] == null) أو يعدّله، ويعيد السجل المحفوظ أو null.
///
/// لوحة من الأسفل على الهاتف، ونافذة على الشاشات العريضة. [initialName] يملأ الاسم مسبقًا (مثل نص البحث).
Future<Farmer?> showFarmerEditSheet(BuildContext context, {Farmer? farmer, String? initialName}) {
  final editor = FarmerEditor(farmer: farmer, initialName: initialName);
  if (isWideLayout(context)) {
    return showDialog<Farmer>(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 560, maxHeight: 820), child: editor),
      ),
    );
  }
  return showModalBottomSheet<Farmer>(
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

/// رقم هاتف اختياري كما يقبله الخادم: أرقام مع + ومسافات وشرطات وأقواس، حتى 20 رقمًا.
/// يعيد النص بأرقام لاتينية، أو null إن كان غير صحيح.
String? normalizePhone(String raw) {
  final s = raw
      .replaceAllMapped(RegExp('[٠-٩۰-۹]'), (m) => digitsOnly(m[0]))
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  if (s.isEmpty) return '';
  final digits = s.replaceAll(RegExp(r'\D'), '');
  if (!RegExp(r'^\+?[\d\s\-()]+$').hasMatch(s) || digits.isEmpty || digits.length > 20) return null;
  return s;
}

/// نموذج المزارع: الاسم (مطلوب)، الهاتف، القرية، الملاحظات.
class FarmerEditor extends StatefulWidget {
  const FarmerEditor({super.key, this.farmer, this.initialName});

  final Farmer? farmer;
  final String? initialName;

  @override
  State<FarmerEditor> createState() => _FarmerEditorState();
}

class _FarmerEditorState extends State<FarmerEditor> {
  /// النسخة التي يُقارن بها التعديل (تتحدث بعد CONFLICT).
  late Farmer? _base = widget.farmer;
  late final _name = TextEditingController(text: widget.farmer?.name ?? widget.initialName?.trim() ?? '');
  late final _phone = TextEditingController(text: widget.farmer?.phone ?? '');
  late final _village = TextEditingController(text: widget.farmer?.village ?? '');
  late final _notes = TextEditingController(text: widget.farmer?.notes ?? '');

  bool _saving = false;
  String? _nameError;
  String? _phoneError;
  String? _villageError;
  String? _notesError;
  String? _error;

  /// رفض الخادم الاسم لأنه مكرر: يظهر «إضافة رغم ذلك».
  bool _duplicate = false;

  /// بعد CONFLICT: السجل الحالي من الخادم لدمجه في النموذج.
  Farmer? _conflictCurrent;
  String? _info;

  /// requestId للحفظ: يُعاد مع الحمولة نفسها عند إعادة المحاولة بعد فشل، فلا يُضاف المزارع مرتين.
  final _request = SubmissionRequestId();

  bool get _isNew => _base == null;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _village.dispose();
    _notes.dispose();
    super.dispose();
  }

  /// الحقول التي تغيّرت عن [_base] (نص فارغ = مسح الحقل). null للمزارع الجديد.
  Map<String, String> _changedFields() {
    final b = _base!;
    final out = <String, String>{};
    void cmp(String key, String now, String? was) {
      if (now != (was ?? '')) out[key] = now;
    }

    cmp('name', _name.text.trim(), b.name);
    cmp('phone', normalizePhone(_phone.text) ?? _phone.text.trim(), b.phone);
    cmp('village', _village.text.trim(), b.village);
    cmp('notes', _notes.text.trim(), b.notes);
    return out;
  }

  bool get _canSave => _isNew ? _name.text.trim().isNotEmpty : _changedFields().isNotEmpty;

  void _clearErrors() {
    _nameError = null;
    _phoneError = null;
    _villageError = null;
    _notesError = null;
    _error = null;
    _duplicate = false;
    _conflictCurrent = null;
    _info = null;
  }

  bool _validate() {
    final name = _name.text.trim();
    if (name.isEmpty) _nameError = 'اكتب اسم المزارع كما يُعرف في السوق، مثل حسن البدري.';
    if (normalizePhone(_phone.text) == null) {
      _phoneError = 'رقم الهاتف «${_phone.text.trim()}» غير صحيح. اكتب الأرقام فقط مثل 01001234567.';
    }
    return _nameError == null && _phoneError == null;
  }

  Future<void> _save({bool allowDuplicate = false}) async {
    if (_saving) return;
    setState(_clearErrors);
    if (!_validate()) {
      setState(() {});
      return;
    }
    final scope = AppScope.of(context);
    final navigator = Navigator.of(context);
    setState(() => _saving = true);
    try {
      final Farmer saved;
      if (_isNew) {
        final payload = {
          'name': _name.text.trim(),
          'phone': normalizePhone(_phone.text)!,
          'village': _village.text.trim(),
          'notes': _notes.text.trim(),
          if (allowDuplicate) 'allowDuplicate': true,
        };
        saved = await scope.api.createFarmer(
          name: payload['name'] as String,
          phone: payload['phone'] as String,
          village: payload['village'] as String,
          notes: payload['notes'] as String,
          allowDuplicate: allowDuplicate,
          requestId: _request.idFor(payload),
        );
      } else {
        final b = _base!;
        final changed = _changedFields();
        final payload = {
          'id': b.id,
          'expectedVersion': b.version,
          ...changed,
          if (allowDuplicate) 'allowDuplicate': true,
        };
        final requestId = _request.idFor(payload);
        if (allowDuplicate) {
          // updateFarmer لا يرسل allowDuplicate، والخادم يقبله (docs/API.md §6 farmers.update).
          final data = await scope.api.call('farmers.update', payload: payload, mutation: true, requestId: requestId);
          saved = Farmer.fromJson((data['farmer'] as Map).cast<String, dynamic>());
        } else {
          saved = await scope.api.updateFarmer(
            id: b.id,
            expectedVersion: b.version,
            name: changed['name'],
            phone: changed['phone'],
            village: changed['village'],
            notes: changed['notes'],
            requestId: requestId,
          );
        }
      }
      _request.reset();
      scope.changes.bump();
      if (!mounted) return;
      navigator.pop(saved);
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
      _error = 'عدّل شخص آخر هذا السجل، حدّث وأعد المحاولة.';
      return;
    }
    if (e.code != ApiErrorCode.validation) {
      _error = e.message;
      return;
    }
    switch (e.field) {
      case 'name':
        _nameError = e.message;
        _duplicate = e.details['existing'] is Map || e.message.contains('مكرر');
      case 'phone':
        _phoneError = e.message;
      case 'village':
        _villageError = e.message;
      case 'notes':
        _notesError = e.message;
      default:
        _error = e.message;
    }
  }

  static Farmer? _tryParse(Map<String, dynamic> j) {
    try {
      return Farmer.fromJson(j);
    } catch (_) {
      return null;
    }
  }

  /// يدمج السجل الحالي من الخادم: الحقول التي لم يغيّرها المستخدم تأخذ القيمة الجديدة، وما غيّره يبقى كما كتبه.
  void _refreshFromServer() {
    final current = _conflictCurrent;
    final old = _base;
    if (current == null || old == null) return;
    void merge(TextEditingController c, String? was, String? now) {
      if (c.text.trim() == (was ?? '')) c.text = now ?? '';
    }

    setState(() {
      merge(_name, old.name, current.name);
      merge(_phone, old.phone, current.phone);
      merge(_village, old.village, current.village);
      merge(_notes, old.notes, current.notes);
      _base = current;
      _clearErrors();
      _info = 'حُدّثت البيانات من الملف. راجع الحقول ثم احفظ مرة أخرى.';
    });
  }

  @override
  Widget build(BuildContext context) {
    final b = _base;
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
                        b == null ? 'إضافة مزارع' : 'تعديل بيانات المزارع',
                        style: const TextStyle(fontFamily: AppFonts.display, fontSize: 19, fontWeight: FontWeight.w700),
                      ),
                    ),
                    Text(
                      b == null ? 'يأخذ المزارع رقمًا تلقائيًا عند الحفظ.' : 'مزارع رقم ${b.no}',
                      style: UiText.small,
                    ),
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
          if (_info != null) ...[
            InlineBanner(kind: BannerKind.info, message: _info!),
            const SizedBox(height: 12),
          ],
          if (_error != null) ...[
            InlineBanner(
              kind: BannerKind.error,
              message: _error!,
              actionLabel: _conflictCurrent != null ? 'تحديث البيانات' : null,
              onAction: _conflictCurrent != null ? _refreshFromServer : null,
            ),
            const SizedBox(height: 12),
          ],
          LabeledField(
            label: 'اسم المزارع',
            child: TextField(
              controller: _name,
              enabled: !_saving,
              autofocus: b == null && (widget.initialName ?? '').trim().isEmpty,
              maxLength: 80,
              textInputAction: TextInputAction.next,
              onChanged: (_) => setState(() {
                _nameError = null;
                _duplicate = false;
              }),
              decoration: uiInputDecoration(hint: 'مثل: حسن البدري', errorText: _nameError).copyWith(counterText: ''),
            ),
          ),
          if (_duplicate) ...[
            const SizedBox(height: 8),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: AppButton(
                label: b == null ? 'إضافة رغم ذلك' : 'حفظ رغم ذلك',
                icon: Icons.person_add_alt,
                height: 48,
                variant: AppButtonVariant.secondary,
                onPressed: _saving ? null : () => _save(allowDuplicate: true),
              ),
            ),
          ],
          const SizedBox(height: 14),
          LabeledField(
            label: 'رقم الهاتف (اختياري)',
            child: TextField(
              controller: _phone,
              enabled: !_saving,
              maxLength: 30,
              keyboardType: TextInputType.phone,
              textDirection: TextDirection.ltr,
              textAlign: TextAlign.left,
              textInputAction: TextInputAction.next,
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9٠-٩۰-۹+\-() ]'))],
              onChanged: (_) => setState(() => _phoneError = null),
              decoration: uiInputDecoration(
                hint: '01001234567',
                errorText: _phoneError,
                prefixIcon: const Icon(Icons.phone_outlined, color: AppColors.inkMuted, size: 20),
              ).copyWith(counterText: ''),
            ),
          ),
          const SizedBox(height: 14),
          LabeledField(
            label: 'القرية / المنطقة (اختياري)',
            child: TextField(
              controller: _village,
              enabled: !_saving,
              maxLength: 80,
              textInputAction: TextInputAction.next,
              onChanged: (_) => setState(() => _villageError = null),
              decoration: uiInputDecoration(hint: 'مثل: بني عدي', errorText: _villageError).copyWith(counterText: ''),
            ),
          ),
          const SizedBox(height: 14),
          LabeledField(
            label: 'ملاحظات (اختياري)',
            child: TextField(
              controller: _notes,
              enabled: !_saving,
              maxLength: 1000,
              minLines: 2,
              maxLines: 4,
              onChanged: (_) => setState(() => _notesError = null),
              decoration: uiInputDecoration(errorText: _notesError).copyWith(counterText: ''),
            ),
          ),
          const SizedBox(height: 18),
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
                  label: b == null ? 'إضافة المزارع' : 'حفظ التغييرات',
                  icon: b == null ? Icons.person_add_alt_1_outlined : Icons.check,
                  busy: _saving,
                  busyLabel: 'جارٍ الحفظ',
                  onPressed: _canSave ? _save : null,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
