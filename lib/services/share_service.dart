// For now we always use the stub implementation to avoid pulling platform
// specific dependencies (like win32) during desktop builds. When you're
// ready to enable native mobile sharing, switch this export to the
// conditional form below and add share_plus back to pubspec.

export 'share_service_stub.dart';

// Conditional form (for future use):
// export 'share_service_stub.dart'
//     if (dart.library.io) 'share_service_mobile.dart';
