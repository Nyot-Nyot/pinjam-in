import 'dart:io';
import 'dart:typed_data';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;

class ImageService {
  ImageService({FirebaseStorage? storage})
    : _storage = storage ?? FirebaseStorage.instance;

  final FirebaseStorage _storage;

  /// Upload a local image file to storage under 'images/{id}{ext}' and
  /// also create a small thumbnail under 'images/thumbs/{id}{ext}'. Returns the public URL of the uploaded image.
  Future<String> uploadImage(String localPath, String id) async {
    final file = File(localPath);
    if (!await file.exists()) throw Exception('file not found');

    final ext = p.extension(localPath).toLowerCase();
    final storagePath = 'images/$id$ext';
    final thumbPath = 'images/thumbs/${id}_thumb$ext';

    // upload original
    final ref = _storage.ref(storagePath);
    await ref.putFile(file);
    final url = await ref.getDownloadURL();

    // generate thumbnail and upload
    try {
      final bytes = await file.readAsBytes();
      final decoded = img.decodeImage(bytes);
      if (decoded != null) {
        final thumb = img.copyResize(decoded, width: 300);
        final thumbBytes = Uint8List.fromList(
          img.encodeJpg(thumb, quality: 80),
        );
        final thumbRef = _storage.ref(thumbPath);
        await thumbRef.putData(
          thumbBytes,
          SettableMetadata(contentType: 'image/jpeg'),
        );
      }
    } catch (_) {
      // non-fatal
    }

    return url;
  }
}
