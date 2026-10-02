import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'ui_tokens.dart';

/// خيار في [SegmentedChoice].
class SegmentOption<T> {
  const SegmentOption(this.value, this.label);
  final T value;
  final String label;
}

/// مجموعة أزرار متلاصقة لاختيار قيمة واحدة (مثل الدور: مدير / موظف إدخال / مشاهدة فقط).
/// كل زر بارتفاع 48 على الأقل.
class SegmentedChoice<T> extends StatelessWidget {
  const SegmentedChoice({
    super.key,
    required this.options,
    required this.value,
    required this.onChanged,
    this.semanticLabel,
    this.hasError = false,
  });

  final List<SegmentOption<T>> options;
  final T value;

  /// null يعطّل الاختيار.
  final ValueChanged<T>? onChanged;
  final String? semanticLabel;
  final bool hasError;

  @override
  Widget build(BuildContext context) {
    final enabled = onChanged != null;
    return Semantics(
      container: true,
      label: semanticLabel,
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: UiColors.beige,
          borderRadius: BorderRadius.circular(14),
          border: hasError ? Border.all(color: AppColors.error, width: 1.5) : null,
        ),
        child: Row(
          children: [
            for (var i = 0; i < options.length; i++) ...[
              if (i > 0) const SizedBox(width: 4),
              Expanded(child: _segment(options[i], enabled)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _segment(SegmentOption<T> o, bool enabled) {
    final selected = o.value == value;
    final fg = !enabled
        ? (selected ? AppColors.inkSecondary : UiColors.hint)
        : (selected ? AppColors.pomegranate : UiColors.label);
    return Semantics(
      button: true,
      selected: selected,
      enabled: enabled,
      inMutuallyExclusiveGroup: true,
      child: Material(
        color: selected ? Colors.white : Colors.transparent,
        elevation: selected ? 1 : 0,
        shadowColor: const Color(0x331C1714),
        borderRadius: BorderRadius.circular(11),
        child: InkWell(
          borderRadius: BorderRadius.circular(11),
          onTap: enabled && !selected ? () => onChanged!(o.value) : null,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                child: Text(
                  o.label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                    color: fg,
                    height: 1.3,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
