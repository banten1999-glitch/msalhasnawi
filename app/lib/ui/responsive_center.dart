import 'package:flutter/material.dart';

/// يحدّ عرض المحتوى ويضعه في المنتصف على الشاشات العريضة.
class ResponsiveCenter extends StatelessWidget {
  const ResponsiveCenter({super.key, required this.child, this.maxWidth = 1200, this.padding = EdgeInsets.zero});

  final Widget child;
  final double maxWidth;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

/// شبكة بعدد أعمدة يتغير مع العرض، وكل صف بارتفاع أطول عناصره.
class ResponsiveGrid extends StatelessWidget {
  const ResponsiveGrid({
    super.key,
    required this.children,
    this.minTileWidth = 160,
    this.spacing = 10,
    this.maxColumns = 6,
    this.minColumns = 1,
  });

  final List<Widget> children;
  final double minTileWidth;
  final double spacing;
  final int maxColumns;
  final int minColumns;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      var cols = ((c.maxWidth + spacing) / (minTileWidth + spacing)).floor();
      cols = cols.clamp(minColumns, maxColumns);
      final rows = <Widget>[];
      for (var i = 0; i < children.length; i += cols) {
        final slice = children.sublist(i, (i + cols).clamp(0, children.length));
        rows.add(IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var j = 0; j < cols; j++) ...[
                if (j > 0) SizedBox(width: spacing),
                Expanded(child: j < slice.length ? slice[j] : const SizedBox.shrink()),
              ],
            ],
          ),
        ));
        if (i + cols < children.length) rows.add(SizedBox(height: spacing));
      }
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: rows);
    });
  }
}
