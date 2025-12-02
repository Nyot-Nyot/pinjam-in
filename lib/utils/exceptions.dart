/// Custom exceptions untuk aplikasi Pinjam In
library;

/// Exception untuk unauthorized access
class UnauthorizedException implements Exception {
  UnauthorizedException([this.message = 'Unauthorized access']);

  final String message;

  @override
  String toString() => 'UnauthorizedException: $message';
}

/// Exception untuk forbidden access (authenticated tapi tidak punya permission)
class ForbiddenException implements Exception {
  ForbiddenException([this.message = 'Forbidden: insufficient permissions']);

  final String message;

  @override
  String toString() => 'ForbiddenException: $message';
}
