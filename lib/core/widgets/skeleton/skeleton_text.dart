import 'package:flutter/material.dart';

import 'skeleton_box.dart';

/// Placeholder text line or multi-line paragraph skeleton
class SkeletonText extends StatelessWidget {
  final int lines;
  final double lineHeight;
  final double spacing;
  final double? width;
  final double lastLineWidthRatio;
  final BorderRadiusGeometry borderRadius;
  final EdgeInsetsGeometry? margin;

  const SkeletonText({
    super.key,
    this.lines = 1,
    this.lineHeight = 14.0,
    this.spacing = 8.0,
    this.width,
    this.lastLineWidthRatio = 0.65,
    this.borderRadius = const BorderRadius.all(Radius.circular(4.0)),
    this.margin,
  }) : assert(lines >= 1, 'lines must be at least 1');

  /// Convenience constructor for title-style text skeletons
  const SkeletonText.title({
    super.key,
    this.lines = 1,
    this.lineHeight = 20.0,
    this.spacing = 8.0,
    this.width = 160.0,
    this.lastLineWidthRatio = 0.65,
    this.borderRadius = const BorderRadius.all(Radius.circular(6.0)),
    this.margin,
  });

  /// Convenience constructor for subtitle / caption text skeletons
  const SkeletonText.caption({
    super.key,
    this.lines = 1,
    this.lineHeight = 11.0,
    this.spacing = 6.0,
    this.width = 100.0,
    this.lastLineWidthRatio = 0.5,
    this.borderRadius = const BorderRadius.all(Radius.circular(3.0)),
    this.margin,
  });

  @override
  Widget build(BuildContext context) {
    if (lines == 1) {
      return Padding(
        padding: margin ?? EdgeInsets.zero,
        child: SkeletonBox(
          width: width,
          height: lineHeight,
          borderRadius: borderRadius,
        ),
      );
    }

    return Padding(
      padding: margin ?? EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: List.generate(lines, (index) {
          final isLast = index == lines - 1;
          final double? lineWidth = isLast && width != null
              ? width! * lastLineWidthRatio
              : (isLast ? null : width);

          return Padding(
            padding: EdgeInsets.only(bottom: isLast ? 0 : spacing),
            child: FractionallySizedBox(
              widthFactor: (lineWidth == null && isLast)
                  ? lastLineWidthRatio
                  : null,
              alignment: Alignment.centerLeft,
              child: SkeletonBox(
                width: lineWidth,
                height: lineHeight,
                borderRadius: borderRadius,
              ),
            ),
          );
        }),
      ),
    );
  }
}
