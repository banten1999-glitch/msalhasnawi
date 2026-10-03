import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../core/api/api_exception.dart';
import '../../core/api/request_id.dart';
import '../../core/models/dashboard.dart';
import '../../theme/app_theme.dart';
import '../../ui/ui.dart';
import 'cooler_format.dart';
import 'cooler_widgets.dart';

/// ينشئ برادًا جديدًا (coolers.create) ويعيده، أو null إن أُلغي.
///
/// لوحة من الأسفل على الهاتف، ونافذة على الشاشات العريضة. كل الحقول اختيارية: الخادم يعطي البراد الرقم
/// التالي ووقت الفتح.
Future<CoolerSummary?> showCreateCoolerSheet(BuildContext context) async {
  final messenger = ScaffoldMessenger.maybeOf(context);
  final cooler = await showAdaptiveSheet<CoolerSummary>(context, const CreateCoolerForm());
  if (cooler != null) {
    messenger?.showSnackBar(SnackBar(content: Text('تم إنشاء ${cooler.title} وفتحه لتسجيل المشتريات.')));
  }
  return cooler;
}

/// نموذج «إنشاء براد».
class CreateCoolerForm extends StatefulWidget {
  const CreateCoolerForm({super.key});

  @override
  State<CreateCoolerForm> createState() => _CreateCoolerFormState();
}

class _CreateCoolerFormState extends State<CreateCoolerForm> {
  final _name = TextEditingController();
  final _carNo = TextEditingController();
  final _driver = TextEditingController();
  final _notes = TextEditingController();

  /// المعرّف نفسه عند إعادة إرسال الحمولة نفسها بعد فشل، فلا يُفتح براد ثانٍ.
  final _request = SubmissionRequestId();

  bool _saving = false;
  String? _error;
  final _fieldErrors = <String, String>{};

  @override
  void dispose() {
    _name.dispose();
    _carNo.dispose();
    _driver.dispose();
    _notes.dispose();
    super.dispose();
  }

  String? _lengthError(String field, String label, TextEditingController c, int max) {
    final v = c.text.trim();
    if (v.length > max) return '«$label» أطول من المسموح ($max حرفًا). اختصره ثم أعد المحاولة.';
    return _fieldErrors[field];
  }

  Future<void> _submit() async {
    if (_saving) return;
    final errors = {
      'name': _lengthError('name', 'اسم البراد / الوصف', _name, PurchaseLimits.coolerNameMax),
      'carNo': _lengthError('carNo', 'رقم السيارة', _carNo, PurchaseLimits.carNoMax),
      'driver': _lengthError('driver', 'اسم السائق', _driver, PurchaseLimits.driverMax),
      'notes': _lengthError('notes', 'الملاحظات', _notes, PurchaseLimits.notesMax),
    };
    if (errors.values.any((e) => e != null)) {
      setState(() {});
      return;
    }
    String? v(TextEditingController c) => c.text.trim().isEmpty ? null : c.text.trim();
    final payload = {'name': v(_name), 'carNo': v(_carNo), 'driver': v(_driver), 'notes': v(_notes)};
    final requestId = _request.idFor(payload);
    final scope = AppScope.of(context);
    setState(() {
      _saving = true;
      _error = null;
      _fieldErrors.clear();
    });
    try {
      final cooler = await scope.api.createCooler(
        name: payload['name'],
        carNo: payload['carNo'],
        driver: payload['driver'],
        notes: payload['notes'],
        requestId: requestId,
      );
      _request.reset();
      scope.changes.bump();
      if (!mounted) return;
      Navigator.of(context).pop(cooler);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        if (e is ApiException && e.code == ApiErrorCode.validation && e.field != null &&
            const {'name', 'carNo', 'driver', 'notes'}.contains(e.field)) {
          _fieldErrors[e.field!] = e.message;
        } else {
          _error = errorMessage(e);
        }
      });
    }
  }

  Widget _field(
    String field,
    String label,
    TextEditingController c,
    int max, {
    String? hint,
    int maxLines = 1,
    TextInputAction action = TextInputAction.next,
    bool autofocus = false,
  }) {
    return LabeledField(
      label: '$label (اختياري)',
      child: TextField(
        controller: c,
        enabled: !_saving,
        autofocus: autofocus,
        minLines: maxLines > 1 ? 2 : 1,
        maxLines: maxLines,
        textInputAction: maxLines > 1 ? TextInputAction.newline : action,
        onChanged: (_) {
          if (_fieldErrors.remove(field) != null) setState(() {});
        },
        onSubmitted: action == TextInputAction.done ? (_) => _submit() : null,
        decoration: uiInputDecoration(hint: hint, errorText: _lengthError(field, label, c, max)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(color: AppColors.pomegranateLight, borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.local_shipping_outlined, color: AppColors.pomegranate),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Semantics(
                  header: true,
                  child: const Text(
                    'إنشاء براد',
                    style: TextStyle(fontFamily: AppFonts.display, fontSize: 19, fontWeight: FontWeight.w700),
                  ),
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
          const SizedBox(height: 6),
          const Text(
            'يأخذ البراد الرقم التالي تلقائيًا ويُسجَّل وقت فتحه الآن. كل الحقول اختيارية ويمكن تركها فارغة.',
            style: UiText.muted,
          ),
          const SizedBox(height: 14),
          if (_error != null) ...[
            InlineBanner(kind: BannerKind.error, title: 'لم يُنشأ البراد', message: _error!),
            const SizedBox(height: 12),
          ],
          _field('name', 'اسم البراد / الوصف', _name, PurchaseLimits.coolerNameMax, hint: 'مثل: شحنة دمياط'),
          const SizedBox(height: 12),
          _field('carNo', 'رقم السيارة', _carNo, PurchaseLimits.carNoMax, hint: 'مثل: ن ق ر 7316'),
          const SizedBox(height: 12),
          _field('driver', 'اسم السائق', _driver, PurchaseLimits.driverMax, hint: 'مثل: سامي عطية'),
          const SizedBox(height: 12),
          _field('notes', 'الملاحظات', _notes, PurchaseLimits.notesMax, hint: 'أي معلومة تفيد الفريق', maxLines: 4),
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
                  label: 'إنشاء البراد',
                  icon: Icons.add,
                  busy: _saving,
                  busyLabel: 'جارٍ الإنشاء',
                  onPressed: _submit,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
