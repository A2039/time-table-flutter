import 'package:flutter/material.dart';

import 'skeleton_box.dart';
import 'skeleton_card.dart';
import 'skeleton_circle.dart';
import 'skeleton_text.dart';

/// Placeholder matching an activity card or history row
/// Mirrors the layout: leading avatar/badge, title, subtitle/time, and trailing status badge
class SkeletonListItem extends StatelessWidget {
  final bool hasLeading;
  final bool hasTrailing;
  final int subtitleLines;
  final EdgeInsetsGeometry? margin;
  final EdgeInsetsGeometry padding;

  const SkeletonListItem({
    super.key,
    this.hasLeading = true,
    this.hasTrailing = true,
    this.subtitleLines = 1,
    this.margin = const EdgeInsets.only(bottom: 12),
    this.padding = const EdgeInsets.all(16),
  });

  @override
  Widget build(BuildContext context) {
    return SkeletonCard(
      margin: margin,
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (hasLeading) ...[
                const SkeletonCircle(size: 28),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          flex: 3,
                          child: SkeletonText(
                            lines: 1,
                            lineHeight: 15,
                            width: 140,
                          ),
                        ),
                        const SizedBox(width: 8),
                        SkeletonBox(
                          width: 48,
                          height: 18,
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SkeletonText.caption(lines: subtitleLines, width: 110),
                  ],
                ),
              ),
              if (hasTrailing) ...[
                const SizedBox(width: 12),
                SkeletonBox(
                  width: 60,
                  height: 24,
                  borderRadius: BorderRadius.circular(12),
                ),
              ],
            ],
          ),
          const SizedBox(height: 10),
          // Subtle time/duration bar
          Row(
            children: [
              SkeletonBox(
                width: 14,
                height: 14,
                borderRadius: BorderRadius.circular(4),
              ),
              const SizedBox(width: 6),
              const SkeletonText(lines: 1, lineHeight: 12, width: 120),
            ],
          ),
        ],
      ),
    );
  }
}
