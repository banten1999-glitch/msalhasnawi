import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../core/api/api_exception.dart';
import '../../core/models/sheet_status.dart';
import '../../theme/app_theme.dart';
import '../../ui/ui.dart';

/// يستخرج معرّف الملف من رابط Google Sheets أو يقبله كما هو (نفس قاعدة الخادم). '' إن لم يكن صالحًا.
String parseSpreadsheetId(String raw) {
  final s = raw.trim();
  final m = RegExp(r'/spreadsheets/(?:u/\d+/)?d/([A-Za-z0-9_-]{20,})').firstMatch(s);
  if (m != null) return m.group(1)!;
  final q = RegExp(r'[?&]id=([A-Za-z0-9_-]{20,})').firstMatch(s);
  if (q != null) return q.group(1)!;
  if (RegExp(r'^[A-Za-z0-9_-]{20,}$').hasMatch(s)) return s;
  return '';
}

/// نافذة ربط ملف آخر: تطلب الرابط، وتنبّه أن البيانات القديمة لا تُنقل، وتشترط تأكيدًا صريحًا.
/// تعيد حالة الملف الجديد (مع التنبيه من الخادم) أو null عند الإلغاء.
Future<SheetStatus?> showChangeSheetDialog(BuildContext context, {SheetStatus? current}) {
  return showDialog<SheetStatus>(
    context: context,
    barrierDismissible: false,
    builder: (_) => ChangeSheetDialog(current: current),
  );
}

class ChangeSheetDialog extends StatefulWidget {
  const ChangeSheetDialog({super.key, this.current});

  final SheetStatus? current;

  @override
  State<ChangeSheetDialog> createState() => _ChangeSheetDialogState();
}

class _ChangeSheetDialogState extends State<ChangeSheetDialog> {
  final _controller = TextEditingController();
  bool _confirmed = false;
  bool _busy = false;
  String? _fieldError;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _hasCurrent => widget.current?.configured == true;

  Future<void> _submit() async {
    final raw = _controller.text.trim();
    if (raw.isEmpty) {
      setState(() => _fieldError = 'الصق رابط ملف Google Sheets الجديد أو معرّفه في هذا الحقل.');
      return;
    }
    final id = parseSpreadsheetId(raw);
    if (id.isEmpty) {
      setState(() => _fieldError = 'هذا ليس رابط ملف Google Sheets. انسخ الرابط كاملًا من شريط العنوان '
          '(يبدأ بـ https://docs.google.com/spreadsheets/d/) والصقه هنا.');
      return;
    }
    if (id == widget.current?.spreadsheetId) {
      setState(() => _fieldError = 'هذا هو الملف المتصل حاليًا. الصق رابط الملف الآخر الذي تريد الربط به.');
      return;
    }
    if (!_confirmed) {
      setState(() => _error = 'أكّد أولًا أنك فهمت أن البيانات القديمة لن تُنقل إلى الملف الجديد.');
      return;
    }
    setState(() {
      _busy = true;
      _fieldError = null;
      _error = null;
    });
    try {
      final status = await AppScope.of(context).api.sheetConnect(raw);
      if (!mounted) return;
      Navigator.of(context).pop(status);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        final fieldProblem = e is ApiException &&
            (e.field == 'spreadsheet' || e.code == ApiErrorCode.sheetUnreachable || e.code == ApiErrorCode.validation);
        if (fieldProblem) {
          _fieldError = e.message;
        } else {
          _error = errorMessage(e);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final connectedAs = widget.current?.connectedAs;
    final canSubmit = _confirmed && !_busy;
    return Dialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Semantics(
                header: true,
                child: Text(
                  _hasCurrent ? 'تغيير ملف Google Sheets' : 'ربط ملف Google Sheets',
                  style: const TextStyle(fontFamily: AppFonts.display, fontSize: 20, fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(height: 14),
              LabeledField(
                label: 'رابط الملف الجديد أو معرّفه',
                child: TextField(
                  controller: _controller,
                  enabled: !_busy,
                  textDirection: TextDirection.ltr,
                  textAlign: TextAlign.left,
                  keyboardType: TextInputType.url,
                  autocorrect: false,
                  onChanged: (_) {
                    if (_fieldError != null) setState(() => _fieldError = null);
                  },
                  decoration: uiInputDecoration(
                    hint: 'docs.google.com/spreadsheets/d/…',
                    errorText: _fieldError,
                    helperText: 'انسخ الرابط من شريط العنوان في المتصفح وأنت تفتح الملف.',
                  ),
                ),
              ),
              const SizedBox(height: 14),
              InlineBanner(
                kind: BannerKind.warning,
                title: 'البيانات القديمة لا تُنقل تلقائيًا',
                message: 'البرادات والمشتريات والمدفوعات والمستخدمون المسجلون في الملف الحالي يبقون فيه. '
                    'بعد الربط تقرأ كل الأجهزة من الملف الجديد وتكتب فيه فقط.'
                    '${connectedAs == null ? '' : ' يجب أن يكون للحساب $connectedAs صلاحية «محرر» على الملف الجديد.'}',
              ),
              const SizedBox(height: 8),
              CheckboxListTile(
                value: _confirmed,
                onChanged: _busy
                    ? null
                    : (v) => setState(() {
                          _confirmed = v ?? false;
                          if (_confirmed) _error = null;
                        }),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
                activeColor: AppColors.pomegranate,
                title: const Text(
                  'فهمت أن البيانات القديمة لن تُنقل إلى الملف الجديد',
                  style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600, height: 1.45),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 4),
                InlineBanner(kind: BannerKind.error, message: _error!),
              ],
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: AppButton(
                      label: 'إلغاء',
                      variant: AppButtonVariant.secondary,
                      onPressed: _busy ? null : () => Navigator.of(context).pop(),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: AppButton(
                      label: 'ربط الملف الجديد',
                      busy: _busy,
                      busyLabel: 'جارٍ الربط',
                      onPressed: canSubmit ? _submit : null,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
