import 'package:flutter/material.dart';

import 'shimmer.dart';
import 'skeleton_box.dart';
import 'skeleton_card.dart';
import 'skeleton_circle.dart';
import 'skeleton_list_item.dart';
import 'skeleton_text.dart';

/// Full-page skeleton placeholder for [HomeScreen]
/// Replicates the date header, overview progress card with ring, reflection card, and activity list
class HomeSkeleton extends StatelessWidget {
  const HomeSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Shimmer(
      child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Date Bar
            Row(
              children: [
                const SkeletonText.title(width: 160),
                const Spacer(),
                SkeletonBox(
                  width: 76,
                  height: 28,
                  borderRadius: BorderRadius.circular(14),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Progress Overview Card
            SkeletonCard(
              borderRadius: BorderRadius.circular(20),
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Row(
                    children: [
                      SkeletonBox(
                        width: 70,
                        height: 24,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      const Spacer(),
                      SkeletonBox(
                        width: 110,
                        height: 20,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      // Progress Ring Placeholder
                      const SkeletonCircle(size: 96),
                      const SizedBox(width: 20),
                      // 4 Stat Rows
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: List.generate(4, (index) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Row(
                                children: [
                                  const SkeletonCircle(size: 14),
                                  const SizedBox(width: 8),
                                  SkeletonText(
                                    lines: 1,
                                    lineHeight: 12,
                                    width: 80 + (index * 8.0 % 24),
                                  ),
                                  const Spacer(),
                                  const SkeletonText(
                                    lines: 1,
                                    lineHeight: 12,
                                    width: 24,
                                  ),
                                ],
                              ),
                            );
                          }),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Progress Bar
                  SkeletonBox(
                    width: double.infinity,
                    height: 8,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Reflection Card Placeholder
            SkeletonCard(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SkeletonCircle(size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        SkeletonText(lines: 1, lineHeight: 14, width: 110),
                        SizedBox(height: 6),
                        SkeletonText(
                          lines: 2,
                          lineHeight: 12,
                          spacing: 4,
                          lastLineWidthRatio: 0.7,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  SkeletonBox(
                    width: 18,
                    height: 18,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Section Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: const [
                SkeletonText.title(width: 130, lineHeight: 18),
                SkeletonText.caption(width: 100),
              ],
            ),
            const SizedBox(height: 12),

            // Activity List Skeletons
            const SkeletonListItem(),
            const SkeletonListItem(),
            const SkeletonListItem(),
            const SkeletonListItem(),
          ],
        ),
      ),
    );
  }
}

/// Full-page skeleton placeholder for [DateTimetableScreen]
/// Replicates the timetable header, remark container, and activity list
class TimetableSkeleton extends StatelessWidget {
  const TimetableSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Shimmer(
      child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header info
            Row(
              children: [
                SkeletonBox(
                  width: 72,
                  height: 26,
                  borderRadius: BorderRadius.circular(13),
                ),
                const SizedBox(width: 10),
                const SkeletonText(lines: 1, lineHeight: 12, width: 90),
                const Spacer(),
                SkeletonBox(
                  width: 95,
                  height: 22,
                  borderRadius: BorderRadius.circular(10),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Daily Reflection Card
            SkeletonCard(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const SkeletonCircle(size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        SkeletonText(lines: 1, lineHeight: 13, width: 100),
                        SizedBox(height: 4),
                        SkeletonText(lines: 1, lineHeight: 11, width: 180),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // Section Title
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: const [
                SkeletonText.title(width: 140, lineHeight: 18),
                SkeletonText.caption(width: 90),
              ],
            ),
            const SizedBox(height: 12),

            // Activity Cards
            const SkeletonListItem(),
            const SkeletonListItem(),
            const SkeletonListItem(),
            const SkeletonListItem(),
            const SkeletonListItem(),
          ],
        ),
      ),
    );
  }
}

/// Full-page skeleton placeholder for [DashboardScreen]
/// Replicates the KPI grid, donut completion chart card, reflection, and activity breakdown
class DashboardSkeleton extends StatelessWidget {
  const DashboardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Shimmer(
      child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row
            Row(
              children: [
                SkeletonBox(
                  width: 76,
                  height: 26,
                  borderRadius: BorderRadius.circular(13),
                ),
                const Spacer(),
                SkeletonBox(
                  width: 88,
                  height: 22,
                  borderRadius: BorderRadius.circular(10),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // KPI Cards Grid (2x2)
            Row(
              children: [
                Expanded(
                  child: SkeletonCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        SkeletonCircle(size: 24),
                        SizedBox(height: 10),
                        SkeletonText(lines: 1, lineHeight: 22, width: 60),
                        SizedBox(height: 4),
                        SkeletonText.caption(width: 80),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SkeletonCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        SkeletonCircle(size: 24),
                        SizedBox(height: 10),
                        SkeletonText(lines: 1, lineHeight: 22, width: 60),
                        SizedBox(height: 4),
                        SkeletonText.caption(width: 80),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  child: SkeletonCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        SkeletonCircle(size: 24),
                        SizedBox(height: 10),
                        SkeletonText(lines: 1, lineHeight: 22, width: 60),
                        SizedBox(height: 4),
                        SkeletonText.caption(width: 80),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SkeletonCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        SkeletonCircle(size: 24),
                        SizedBox(height: 10),
                        SkeletonText(lines: 1, lineHeight: 22, width: 60),
                        SizedBox(height: 4),
                        SkeletonText.caption(width: 80),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Chart Card Placeholder
            SkeletonCard(
              borderRadius: BorderRadius.circular(20),
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SkeletonText.title(width: 150, lineHeight: 18),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      const SkeletonCircle(size: 110),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: List.generate(4, (index) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              children: const [
                                SkeletonCircle(size: 10),
                                SizedBox(width: 8),
                                SkeletonText(
                                  lines: 1,
                                  lineHeight: 12,
                                  width: 90,
                                ),
                              ],
                            ),
                          );
                        }),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Section Title: Activity Breakdown
            const SkeletonText.title(width: 160, lineHeight: 18),
            const SizedBox(height: 12),

            // Activity Items
            const SkeletonListItem(),
            const SkeletonListItem(),
            const SkeletonListItem(),
          ],
        ),
      ),
    );
  }
}

/// Full-page skeleton placeholder for [HistoryScreen]
/// Replicates the range summary, history cards, and pagination
class HistorySkeleton extends StatelessWidget {
  const HistorySkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Shimmer(
      child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Range summary row
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: const [
                  SkeletonText(lines: 1, lineHeight: 12, width: 140),
                  Spacer(),
                  SkeletonText(lines: 1, lineHeight: 12, width: 65),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // History Cards
            ...List.generate(5, (index) {
              return SkeletonCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const SkeletonText(
                          lines: 1,
                          lineHeight: 16,
                          width: 110,
                        ),
                        const SizedBox(width: 8),
                        SkeletonBox(
                          width: 58,
                          height: 20,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        const Spacer(),
                        SkeletonBox(
                          width: 48,
                          height: 22,
                          borderRadius: BorderRadius.circular(11),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Progress bar
                    SkeletonBox(
                      width: double.infinity,
                      height: 6,
                      borderRadius: BorderRadius.circular(3),
                    ),
                    const SizedBox(height: 12),
                    // Metric pills row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: List.generate(4, (_) {
                        return SkeletonBox(
                          width: 62,
                          height: 20,
                          borderRadius: BorderRadius.circular(8),
                        );
                      }),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

/// Inline skeleton placeholder for API Health & Diagnostics in [SettingsScreen]
class HealthStatusSkeleton extends StatelessWidget {
  const HealthStatusSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Shimmer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: List.generate(3, (index) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                const SkeletonCircle(size: 16),
                const SizedBox(width: 10),
                SkeletonText(
                  lines: 1,
                  lineHeight: 13,
                  width: 150 + (index * 20.0),
                ),
                const Spacer(),
                SkeletonBox(
                  width: 48,
                  height: 18,
                  borderRadius: BorderRadius.circular(8),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }
}

/// Skeleton placeholder for database integrity audit checks in [AdminScreen]
class AdminAuditSkeleton extends StatelessWidget {
  const AdminAuditSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Shimmer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Audit Summary Card Skeleton
          SkeletonCard(
            borderRadius: BorderRadius.circular(16),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    SkeletonBox(
                      width: 90,
                      height: 24,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    const SkeletonText.caption(width: 120),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: List.generate(3, (_) {
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: SkeletonBox(
                          height: 48,
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    );
                  }),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Section Title
          const SkeletonText.title(width: 160, lineHeight: 18),
          const SizedBox(height: 12),

          // 4 Detailed Check Cards
          ...List.generate(4, (_) {
            return SkeletonCard(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  const SkeletonCircle(size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        SkeletonText(lines: 1, lineHeight: 14, width: 140),
                        SizedBox(height: 4),
                        SkeletonText.caption(lines: 1, width: 200),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  SkeletonBox(
                    width: 50,
                    height: 22,
                    borderRadius: BorderRadius.circular(11),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

/// Compact loading indicator for bottom pagination in list views
class PaginationLoadingFooter extends StatelessWidget {
  const PaginationLoadingFooter({super.key});

  @override
  Widget build(BuildContext context) {
    return Shimmer(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SkeletonCircle(size: 16),
              const SizedBox(width: 10),
              SkeletonBox(
                width: 120,
                height: 14,
                borderRadius: BorderRadius.circular(7),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
