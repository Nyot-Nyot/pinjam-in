import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_contacts/flutter_contacts.dart';

import '../utils/error_handler.dart';

/// A small helper service to encapsulate contact permission and selection.
class ContactService {
  /// Requests permission and, if granted, shows a simple dialog allowing the
  /// user to pick a contact. Returns a display string like `Name • phone` or
  /// just the phone number, or null if cancelled.
  static Future<String?> pickContact(BuildContext context) async {
    try {
      final permitted = await FlutterContacts.requestPermission();
      if (!permitted) {
        ErrorHandler.showError(context, 'Izin kontak ditolak');
        return null;
      }

      final contacts = await FlutterContacts.getContacts(withProperties: true);
      if (contacts.isEmpty) {
        ErrorHandler.showInfo(context, 'Tidak ada kontak di perangkat');
        return null;
      }

      final choice = await showDialog<Contact?>(
        context: context,
        builder: (ctx) => SimpleDialog(
          title: const Text('Pilih Kontak'),
          children: contacts.take(20).map((c) {
            final subtitle = c.phones.isNotEmpty ? c.phones.first.number : '';
            return SimpleDialogOption(
              onPressed: () => Navigator.of(ctx).pop(c),
              child: ListTile(
                title: Text(c.displayName),
                subtitle: Text(subtitle),
              ),
            );
          }).toList(),
        ),
      );

      if (choice == null) return null;

      final name = choice.displayName;
      final phone = choice.phones.isNotEmpty ? choice.phones.first.number : '';
      final display = name.isNotEmpty ? '$name • $phone' : phone;
      return display;
    } catch (e) {
      if (e is MissingPluginException) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Picker kontak tidak tersedia pada build saat ini. Jalankan ulang aplikasi di perangkat mobile.',
            ),
          ),
        );
        return null;
      }
      ErrorHandler.showError(context, 'Gagal memilih kontak: $e');
      return null;
    }
  }
}
