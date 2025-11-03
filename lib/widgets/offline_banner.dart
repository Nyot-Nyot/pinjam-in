import 'package:flutter/material.dart';

import '../services/connectivity_service.dart';

class OfflineBanner extends StatefulWidget {
  const OfflineBanner({super.key});

  @override
  State<OfflineBanner> createState() => _OfflineBannerState();
}

class _OfflineBannerState extends State<OfflineBanner> {
  late bool _online;
  late final Stream<bool> _stream;

  @override
  void initState() {
    super.initState();
    _online = ConnectivityService.instance.isOnline;
    _stream = ConnectivityService.instance.onStatusChanged;
    _stream.listen((v) {
      if (mounted) setState(() => _online = v);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_online) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
      color: Colors.orange.shade700,
      child: Text(
        'Anda sedang offline — beberapa fitur mungkin tidak tersedia',
        style: const TextStyle(color: Colors.white),
        textAlign: TextAlign.center,
      ),
    );
  }
}
