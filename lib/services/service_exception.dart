class ServiceException implements Exception {
  final String message;
  final dynamic cause;

  ServiceException(this.message, {this.cause});

  @override
  String toString() => 'ServiceException: $message';
}
