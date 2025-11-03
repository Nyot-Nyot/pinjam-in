import 'dart:async';

import 'package:http/http.dart' as http;

/// Lightweight connectivity checker.
/// Performs a periodic HTTP HEAD to a well-known host and exposes current
/// status via a stream and a synchronous getter.
class ConnectivityService {
  ConnectivityService._internal() {
    _start();
  }

  static final ConnectivityService _instance = ConnectivityService._internal();
  static ConnectivityService get instance => _instance;

  final StreamController<bool> _controller = StreamController.broadcast();
  bool _isOnline = true;
  Timer? _timer;

  bool get isOnline => _isOnline;
  Stream<bool> get onStatusChanged => _controller.stream;

  void _start() {
    // initial check
    _checkOnce();
    // periodic check every 10s
    _timer = Timer.periodic(const Duration(seconds: 10), (_) => _checkOnce());
  }

  Future<void> _checkOnce() async {
    try {
      final resp = await http
          .head(Uri.parse('https://example.com'))
          .timeout(const Duration(seconds: 4));
      final online = resp.statusCode >= 200 && resp.statusCode < 500;
      if (online != _isOnline) {
        _isOnline = online;
        _controller.add(_isOnline);
      }
    } catch (_) {
      if (_isOnline) {
        _isOnline = false;
        _controller.add(false);
      }
    }
  }

  Future<void> checkNow() async => _checkOnce();

  void dispose() {
    _timer?.cancel();
    _controller.close();
  }
}
