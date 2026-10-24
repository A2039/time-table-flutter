import 'package:flutter/material.dart';

import 'shimmer.dart';

/// Reusable rounded placeholder block with configurable dimensions and shape
/// Synchronizes with the parent [Shimmer] animation and adapts to light/dark themes
class SkeletonBox extends StatelessWidget {
  final double? width;
  final double? height;
  final BorderRadiusGeometry? borderRadius;
  final BoxShape shape;
  final EdgeInsetsGeometry? margin;
  final EdgeInsetsGeometry? padding;
  final Widget? child;

  const SkeletonBox({
    super.key,
    this.width,
    this.height,
    this.borderRadius = const BorderRadius.all(Radius.circular(8)),
    this.shape = BoxShape.rectangle,
    this.margin,
    this.padding,
    this.child,
  });

  /// Factory for a rectangular block with border radius (cards, buttons)
  SkeletonBox.rounded({
    super.key,
    this.width,
    this.height,
    double radius = 12.0,
    this.margin,
    this.padding,
    this.child,
  }) : borderRadius = BorderRadius.all(Radius.circular(radius)),
       shape = BoxShape.rectangle;

  /// Factory for a circular block (avatars, icons)
  const SkeletonBox.circle({
    super.key,
    required double size,
    this.margin,
    this.padding,
    this.child,
  }) : width = size,
       height = size,
       borderRadius = null,
       shape = BoxShape.circle;

  @override
  Widget build(BuildContext context) {
    final shimmerScope = ShimmerScope.maybeOf(context);

    // Fallback colors if outside a ShimmerScope
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final defaultBase = isDark
        ? theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35)
        : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.55);
    final defaultHighlight = isDark
        ? theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.75)
        : theme.colorScheme.surface.withValues(alpha: 0.95);

    final baseColor = shimmerScope?.baseColor ?? defaultBase;
    final highlightColor = shimmerScope?.highlightColor ?? defaultHighlight;
    final isAnimated = shimmerScope?.isAnimated ?? false;

    if (!isAnimated || shimmerScope == null) {
      return Container(
        width: width,
        height: height,
        margin: margin,
        padding: padding,
        decoration: BoxDecoration(
          color: baseColor,
          borderRadius: shape == BoxShape.circle ? null : borderRadius,
          shape: shape,
        ),
        child: child,
      );
    }

    return AnimatedBuilder(
      animation: shimmerScope.animation,
      builder: (context, staticChild) {
        final slide = shimmerScope.animation.value * 2.6 - 1.3;
        return Container(
          width: width,
          height: height,
          margin: margin,
          padding: padding,
          decoration: BoxDecoration(
            borderRadius: shape == BoxShape.circle ? null : borderRadius,
            shape: shape,
            gradient: LinearGradient(
              colors: [baseColor, highlightColor, baseColor],
              stops: const [0.1, 0.5, 0.9],
              begin: const Alignment(-1.0, -0.3),
              end: const Alignment(1.0, 0.3),
              transform: SlidingGradientTransform(slidePercent: slide),
            ),
          ),
          child: staticChild,
        );
      },
      child: child,
    );
  }
}
