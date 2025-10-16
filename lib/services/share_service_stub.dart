import 'package:flutter/services.dart';

class ShareService {
  /// Fallback share: copy text to clipboard and return true if copied.
  static Future<bool> share(String text, {String? subject}) async {
    await Clipboard.setData(ClipboardData(text: text));
    return true;
  }
}
