import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'ui_tokens.dart';

/// تبويبات على شكل أقراص (التبويب المختار داكن). مساحة اللمس 48 على الأقل.
class PillTabs extends StatelessWidget {
  const PillTabs({super.key, required this.labels, required this.selected, required this.onSelected});

  final List<String> labels;
  final int selected;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++) ...[
            if (i > 0) const SizedBox(width: 6),
            _pill(i),
          ],
        ],
      ),
    );
  }

  Widget _pill(int i) {
    final on = i == selected;
    return Semantics(
      selected: on,
      button: true,
      child: InkWell(
        onTap: on ? null : () => onSelected(i),
        borderRadius: BorderRadius.circular(999),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Center(
            child: Container(
              height: 40,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: on ? AppColors.ink : Colors.white,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: on ? AppColors.ink : UiColors.fieldBorder, width: 1.5),
              ),
              child: Text(
                labels[i],
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: on ? Colors.white : UiColors.label,
                  height: 1.2,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
