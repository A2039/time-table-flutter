import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Extension helpers for Riverpod AsyncValue and general Result handling
extension AsyncValueExtensions<T> on AsyncValue<T> {
  /// Convenient accessor for value if in data state or previous data state
  T? get valueOrNull => asData?.value;
}
