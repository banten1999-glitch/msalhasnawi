import 'package:flutter/material.dart';

import 'app_card.dart';
import 'ui_tokens.dart';

/// مستطيل رمادي يحجز مكان المحتوى أثناء التحميل.
class SkeletonBox extends StatelessWidget {
  const SkeletonBox({super.key, this.width, this.height = 12, this.radius = 6});

  final double? width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) => Container(
        width: width,
        height: height,
        decoration: BoxDecoration(color: UiColors.greyBg, borderRadius: BorderRadius.circular(radius)),
      );
}

/// هيكل تحميل ثابت (بلا حركة مستمرة) يشبه شكل الصفحة: بطاقة رئيسية ثم مربعات ثم أسطر.
class LoadingSkeleton extends StatelessWidget {
  const LoadingSkeleton({super.key, this.tiles = 4, this.lines = 3, this.showHeaderCard = true});

  final int tiles;
  final int lines;
  final bool showHeaderCard;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'جارٍ تحميل البيانات',
      liveRegion: true,
      child: ExcludeSemantics(
        child: SingleChildScrollView(
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (showHeaderCard) ...[
                const AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SkeletonBox(width: 120),
                      SizedBox(height: 10),
                      SkeletonBox(width: 220, height: 18),
                      SizedBox(height: 16),
                      SkeletonBox(height: 56, radius: 12),
                      SizedBox(height: 16),
                      SkeletonBox(width: 160, height: 24),
                      SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(child: SkeletonBox(height: 48, radius: 12)),
                          SizedBox(width: 10),
                          Expanded(child: SkeletonBox(height: 48, radius: 12)),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
              LayoutBuilder(builder: (context, c) {
                final cols = c.maxWidth >= 700 ? 4 : 2;
                final w = (c.maxWidth - (cols - 1) * 10) / cols;
                return Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    for (var i = 0; i < tiles; i++)
                      SizedBox(
                        width: w,
                        child: const AppCard(
                          padding: EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [SkeletonBox(width: 90), SizedBox(height: 10), SkeletonBox(width: 60, height: 20)],
                          ),
                        ),
                      ),
                  ],
                );
              }),
              const SizedBox(height: 16),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (var i = 0; i < lines; i++) ...[
                      SkeletonBox(width: i.isEven ? 240 : 180),
                      const SizedBox(height: 12),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
