/// Retries [fn] up to [maxAttempts] times with [delay] between attempts.
/// Returns null silently if all attempts fail.
Future<T?> withRetry<T>(
  Future<T> Function() fn, {
  int      maxAttempts = 3,
  Duration delay       = const Duration(seconds: 2),
}) async {
  for (var attempt = 0; attempt < maxAttempts; attempt++) {
    try {
      return await fn();
    } catch (_) {
      if (attempt < maxAttempts - 1) await Future.delayed(delay);
    }
  }
  return null;
}
