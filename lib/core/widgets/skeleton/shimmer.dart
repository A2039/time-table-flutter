import 'package:flutter/material.dart';

/// Inherited scope providing synchronized shimmer animation values and theme colors
class ShimmerScope extends InheritedWidget {
  final Animation<double> animation;
  final Color baseColor;
  final Color highlightColor;
  final bool isAnimated;

  const ShimmerScope({
    super.key,
    required this.animation,
    required this.baseColor,
    required this.highlightColor,
    required this.isAnimated,
    required super.child,
  });

  static ShimmerScope? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<ShimmerScope>();
  }

  static ShimmerScope of(BuildContext context) {
    final scope = maybeOf(context);
    assert(
      scope != null,
      'No ShimmerScope found in context. Wrap widget in a Shimmer widget.',
    );
    return scope!;
  }

  @override
  bool updateShouldNotify(ShimmerScope oldWidget) {
    return baseColor != oldWidget.baseColor ||
        highlightColor != oldWidget.highlightColor ||
        isAnimated != oldWidget.isAnimated;
  }
}

/// Transform that slides a gradient horizontally based on animation progress
class SlidingGradientTransform extends GradientTransform {
  final double slidePercent;

  const SlidingGradientTransform({required this.slidePercent});

  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) {
    return Matrix4.translationValues(bounds.width * slidePercent, 0.0, 0.0);
  }
}

/// Orchestrator widget providing smooth horizontal shimmer wave animation
/// Automatically adapts colors to Light & Dark themes, and respects reduced-motion accessibility
class Shimmer extends StatefulWidget {
  final Widget child;
  final Duration duration;
  final Color? baseColor;
  final Color? highlightColor;
  final bool enabled;
  final String? semanticLabel;

  const Shimmer({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 1400),
    this.baseColor,
    this.highlightColor,
    this.enabled = true,
    this.semanticLabel = 'Loading content',
  });

  @override
  State<Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<Shimmer> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    if (widget.enabled) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(Shimmer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.enabled != oldWidget.enabled) {
      if (widget.enabled) {
        _controller.repeat();
      } else {
        _controller.stop();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final disableAnimations = MediaQuery.of(context).disableAnimations;

    final base =
        widget.baseColor ??
        (isDark
            ? theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35)
            : theme.colorScheme.surfaceContainerHighest.withValues(
                alpha: 0.55,
              ));

    final highlight =
        widget.highlightColor ??
        (isDark
            ? theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.75)
            : theme.colorScheme.surface.withValues(alpha: 0.95));

    final isAnimated = widget.enabled && !disableAnimations;
    if (!isAnimated && _controller.isAnimating) {
      _controller.stop();
    } else if (isAnimated && !_controller.isAnimating) {
      _controller.repeat();
    }

    return RepaintBoundary(
      child: Semantics(
        label: widget.semanticLabel,
        container: true,
        excludeSemantics: true,
        child: ShimmerScope(
          animation: _controller,
          baseColor: base,
          highlightColor: highlight,
          isAnimated: isAnimated,
          child: widget.child,
        ),
      ),
    );
  }
}
