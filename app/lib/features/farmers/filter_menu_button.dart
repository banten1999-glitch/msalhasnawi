import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../../ui/ui.dart';

/// زر فلتر بقائمة اختيارات («الحالة: الكل»)، بارتفاع 48 على الأقل. يستخدمه قسما المزارعين والمدفوعات.
class FilterMenuButton<T> extends StatelessWidget {
  const FilterMenuButton({
    super.key,
    required this.icon,
    required this.label,
    required this.options,
    required this.selected,
    required this.onSelected,
    required this.tooltip,
  });

  final IconData icon;

  /// النص الظاهر على الزر، مثل «المستفيد: مزارعون».
  final String label;
  final List<(T, String)> options;
  final T selected;
  final ValueChanged<T> onSelected;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<T>(
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
          PopupMenuItem<T>(
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

/// زر تبديل على شكل قرص («إظهار الموقوفين»)، بارتفاع 48 على الأقل.
class ToggleFilterButton extends StatelessWidget {
  const ToggleFilterButton({super.key, required this.label, required this.value, required this.onChanged});

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      toggled: value,
      button: true,
      child: InkWell(
        onTap: () => onChanged(!value),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          constraints: const BoxConstraints(minHeight: 48),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: value ? AppColors.pomegranateLight : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: value ? AppColors.pomegranate : UiColors.fieldBorder, width: 1.5),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                value ? Icons.check_box : Icons.check_box_outline_blank,
                size: 20,
                color: value ? AppColors.pomegranate : AppColors.inkSecondary,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.ink),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// حقل بحث بأسلوب التصميم مع زر مسح.
class SearchField extends StatelessWidget {
  const SearchField({super.key, required this.controller, required this.hint, required this.onChanged});

  final TextEditingController controller;
  final String hint;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, _) => TextField(
        controller: controller,
        onChanged: onChanged,
        textInputAction: TextInputAction.search,
        decoration: uiInputDecoration(
          hint: hint,
          prefixIcon: const Icon(Icons.search, color: AppColors.inkMuted),
          suffixIcon: value.text.isEmpty
              ? null
              : IconButton(
                  tooltip: 'مسح البحث',
                  icon: const Icon(Icons.close),
                  onPressed: () {
                    controller.clear();
                    onChanged('');
                  },
                ),
        ),
      ),
    );
  }
}
