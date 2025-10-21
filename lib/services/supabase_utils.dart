// Utilities for Supabase interactions

String? authErrorFromResponse(dynamic res, [dynamic caught]) {
  try {
    if (res == null) return caught?.toString();
  } catch (_) {}
  try {
    final err = (res as dynamic).error;
    if (err != null) return err.toString();
  } catch (_) {}
  try {
    final sm = (res as dynamic).statusMessage;
    if (sm != null) return sm.toString();
  } catch (_) {}
  try {
    final data = (res as dynamic).data;
    if (data != null) {
      try {
        final derr = (data as dynamic).error;
        if (derr != null) return derr.toString();
      } catch (_) {}
      try {
        final user = (data as dynamic).user;
        if (user == null) return 'Authentication failed';
      } catch (_) {}
    }
  } catch (_) {}
  return caught?.toString();
}
