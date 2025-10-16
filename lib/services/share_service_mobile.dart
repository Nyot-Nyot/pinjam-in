// Mobile implementation placeholder.
// Right now we don't import `share_plus` to avoid pulling platform-specific
// transitive dependencies during desktop builds. When you're ready to enable
// native mobile sharing, re-add `share_plus` to pubspec and reintroduce the
// implementation below.

import 'package:flutter/services.dart';

class ShareService {
  /// Currently a fallback that copies text to clipboard and returns true.
  static Future<bool> share(String text, {String? subject}) async {
    await Clipboard.setData(ClipboardData(text: text));
    return true;
  }
}
