import 'dart:async';

/// Small retry helper used for transient operations (storage uploads, RPCs).
/// Uses exponential backoff between attempts.
Future<T> retry<T>(
  Future<T> Function() fn, {
  int attempts = 3,
  Duration initialDelay = const Duration(milliseconds: 300),
}) async {
  var attempt = 0;
  var delay = initialDelay;
  while (true) {
    try {
      return await fn();
    } catch (e) {
      attempt++;
      if (attempt >= attempts) rethrow;
      await Future.delayed(delay);
      delay *= 2;
    }
  }
}

/// Simple best-effort extraction of message from various error types.
String extractErrorMessage(Object? e) {
  if (e == null) return 'Unknown error';
  try {
    return e.toString();
  } catch (_) {
    return 'Unknown error';
  }
}
