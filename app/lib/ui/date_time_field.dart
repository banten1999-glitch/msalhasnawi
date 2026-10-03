import 'package:flutter/material.dart';

import '../core/format/numbers.dart';
import '../theme/app_theme.dart';
import 'ui_tokens.dart';

/// حقل تاريخ ووقت العملية. [value] == null يعني «الآن» (يرسل النموذج null فيستخدم الخادم وقت الحفظ).
///
/// الضغط يفتح اختيار التاريخ ثم الوقت؛ زر «الآن» يعيده إلى null.
class DateTimeField extends StatelessWidget {
  const DateTimeField({super.key, required this.value, required this.onChanged, this.enabled = true, this.errorText});

  final DateTime? value;
  final ValueChanged<DateTime?> onChanged;
  final bool enabled;
  final String? errorText;

  Future<void> _pick(BuildContext context) async {
    final now = DateTime.now();
    final initial = value ?? now;
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(now.year - 2),
      lastDate: DateTime(now.year + 1, 12, 31),
      helpText: 'تاريخ العملية',
      cancelText: 'إلغاء',
      confirmText: 'التالي',
    );
    if (date == null || !context.mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
      helpText: 'وقت العملية',
      cancelText: 'إلغاء',
      confirmText: 'تم',
    );
    if (time == null) return;
    onChanged(DateTime(date.year, date.month, date.day, time.hour, time.minute));
  }

  @override
  Widget build(BuildContext context) {
    final v = value;
    final text = v == null ? 'الآن (وقت الحفظ)' : formatLocalTimestamp(toWallClockText(v).replaceFirst(' ', 'T'));
    return InputDecorator(
      isEmpty: false,
      decoration: uiInputDecoration(
        errorText: errorText,
        prefixIcon: const Icon(Icons.event_outlined, color: AppColors.inkSecondary),
        suffixIcon: v == null || !enabled
            ? null
            : IconButton(
                tooltip: 'الآن',
                icon: const Icon(Icons.restart_alt),
                onPressed: () => onChanged(null),
              ),
      ),
      child: InkWell(
        onTap: enabled ? () => _pick(context) : null,
        borderRadius: BorderRadius.circular(8),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 24),
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: Text(text, style: const TextStyle(fontSize: 15, color: AppColors.ink)),
          ),
        ),
      ),
    );
  }
}
