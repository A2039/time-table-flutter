import 'package:flutter/material.dart';

import 'skeleton_box.dart';

/// Circular placeholder for avatars, icon buttons, and circular status indicators
class SkeletonCircle extends StatelessWidget {
  final double size;
  final EdgeInsetsGeometry? margin;
  final Widget? child;

  const SkeletonCircle({
    super.key,
    required this.size,
    this.margin,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    return SkeletonBox.circle(size: size, margin: margin, child: child);
  }
}
