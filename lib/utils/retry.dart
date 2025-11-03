import 'dart:async';

/// Simple retry helper with exponential backoff.
/// Usage:
/// await retry(() async { return await someAsync(); }, attempts: 3);
Future<T> retry<T>(
  Future<T> Function() fn, {
  int attempts = 3,
  Duration delay = const Duration(milliseconds: 200),
  double backoffFactor = 2.0,
}) async {
  dynamic lastErr;
  var currentDelay = delay;
  for (var attempt = 1; attempt <= attempts; attempt++) {
    try {
      return await fn();
    } catch (e) {
      lastErr = e;
      if (attempt == attempts) rethrow;
      await Future.delayed(currentDelay);
      currentDelay = Duration(
        milliseconds: (currentDelay.inMilliseconds * backoffFactor).round(),
      );
    }
  }
  // unreachable
  throw lastErr ?? Exception('Unknown retry error');
}
