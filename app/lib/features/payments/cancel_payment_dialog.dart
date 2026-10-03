import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../core/api/api_exception.dart';
import '../../core/api/request_id.dart';
import '../../core/format/numbers.dart';
import '../../core/models/records.dart';
import '../../theme/app_theme.dart';
import '../../ui/ui.dart';
import 'payments_logic.dart';

/// يطلب سبب الإلغاء (مطلوب) ويرسل payments.cancel. يعيد النتيجة بعد رد الخادم الناجح، أو null عند التراجع.
Future<PaymentResult?> showCancelPaymentDialog(BuildContext context, Payment payment) => showDialog<PaymentResult>(
      context: context,
      barrierDismissible: false,
      builder: (_) => CancelPaymentDialog(payment: payment),
    );

class CancelPaymentDialog extends StatefulWidget {
  const CancelPaymentDialog({super.key, required this.payment});

  final Payment payment;

  @override
  State<CancelPaymentDialog> createState() => _CancelPaymentDialogState();
}

class _CancelPaymentDialogState extends State<CancelPaymentDialog> {
  final _reason = TextEditingController();
  bool _saving = false;
  String? _reasonError;
  String? _error;

  /// requestId للإلغاء: نفسه عند إعادة المحاولة بالسبب نفسه بعد انقطاع.
  final _request = SubmissionRequestId();

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_saving) return;
    final p = widget.payment;
    final reason = _reason.text.trim();
    if (reason.isEmpty) {
      setState(() => _reasonError = 'اكتب سبب إلغاء الدفعة، مثل: سُجّلت مرتين بالخطأ.');
      return;
    }
    final scope = AppScope.of(context);
    final navigator = Navigator.of(context);
    setState(() {
      _saving = true;
      _reasonError = null;
      _error = null;
    });
    try {
      final result = await scope.api.cancelPayment(
        id: p.id,
        reason: reason,
        requestId: _request.idFor({'id': p.id, 'reason': reason}),
      );
      _request.reset();
      scope.changes.bump();
      if (!mounted) return;
      navigator.pop(result);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        if (e is ApiException && e.code == ApiErrorCode.validation && e.field == 'reason') {
          _reasonError = e.message;
        } else {
          _error = errorMessage(e);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.payment;
    return AlertDialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      icon: const Icon(Icons.block, color: AppColors.error, size: 32),
      title: Text(
        'إلغاء الدفعة ${p.no}؟',
        textAlign: TextAlign.center,
        style: const TextStyle(fontFamily: AppFonts.display, fontSize: 20, fontWeight: FontWeight.w700),
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '${p.payeeName} · ${formatMoney(p.amountPiasters)} ج.م · ${paymentOperationLabel(p)}',
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, height: 1.5),
              ),
              const SizedBox(height: 6),
              const Text(
                'لا تُحذف الدفعة من الملف: تبقى ظاهرة بحالة «ملغاة» مع السبب، ويعود مبلغها إلى المتبقي.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: AppColors.inkSecondary, height: 1.6),
              ),
              const SizedBox(height: 14),
              LabeledField(
                label: 'سبب الإلغاء',
                child: TextField(
                  controller: _reason,
                  enabled: !_saving,
                  autofocus: true,
                  maxLength: 500,
                  minLines: 2,
                  maxLines: 4,
                  onChanged: (_) {
                    if (_reasonError != null) setState(() => _reasonError = null);
                  },
                  decoration: uiInputDecoration(hint: 'مثل: سُجّلت مرتين بالخطأ', errorText: _reasonError)
                      .copyWith(counterText: ''),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 10),
                InlineBanner(kind: BannerKind.error, message: _error!),
              ],
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
                onPressed: _saving ? null : () => Navigator.of(context).pop(),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: AppButton(
                label: 'إلغاء الدفعة',
                variant: AppButtonVariant.danger,
                busy: _saving,
                busyLabel: 'جارٍ الإلغاء',
                onPressed: _submit,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
