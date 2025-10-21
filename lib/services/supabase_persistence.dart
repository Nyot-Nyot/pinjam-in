import 'dart:convert';
import 'dart:io';

import 'package:flutter_dotenv/flutter_dotenv.dart' show dotenv;
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/loan_item.dart';
import 'persistence_service.dart';

/// Minimal Supabase-backed PersistenceService implementation.
///
/// This implementation uses the `items` table with schema:
/// id (UUID primary key), user_id (UUID), name (text), borrower_name (text),
/// borrower_contact_id (text), borrow_date (timestamptz), return_date (date),
/// status (text: 'borrowed'|'returned'), notes (text), photo_url (text),
/// created_at (timestamptz)
class SupabasePersistence implements PersistenceService {
  SupabasePersistence._(this._client);

  final SupabaseClient _client;

  static Future<SupabasePersistence> init({
    required String url,
    required String anonKey,
  }) async {
    try {
      await Supabase.initialize(url: url, anonKey: anonKey);
    } catch (e) {
      final s = e.toString();
      if (s.contains('already initialized') ||
          s.contains('already been initialized') ||
          s.contains('this instance is already initialized')) {
        // ignore
      } else {
        rethrow;
      }
    }

    return SupabasePersistence._(Supabase.instance.client);
  }

  SupabasePersistence.fromClient(this._client);

  /// Default storage bucket to use for uploaded images. Create this bucket in
  /// your Supabase project (public or with appropriate policies).
  static const _kImagesBucket = 'item_photos';
  // Optional: an external upload server you can run (see server/upload_server)
  static final _kUploadServerUrl = dotenv.env['SUPABASE_UPLOAD_SERVER'];

  static Map<String, dynamic> _toMap(LoanItem item) => {
    'id': item.id,
    'user_id': item.ownerId,
    'name': item.title,
    'borrower_name': item.borrower,
    'borrower_contact_id': item.contact,
    'borrow_date': item.createdAt?.toIso8601String(),
    'return_date': item.returnedAt != null
        ? item.returnedAt!.toIso8601String().split('T')[0] // Date only
        : null,
    'status': item.status == 'active' ? 'borrowed' : item.status,
    'notes': item.note,
    'photo_url': item.imageUrl,
    'created_at': item.createdAt?.toIso8601String(),
  };

  static LoanItem _fromMap(Map<String, dynamic> m) {
    // Parse timestamps
    DateTime? parseTimestamp(dynamic value) {
      if (value == null) return null;
      if (value is String) return DateTime.tryParse(value);
      if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
      return null;
    }

    final borrowDate = parseTimestamp(m['borrow_date']);
    final returnDate = parseTimestamp(m['return_date']);
    final createdAt = parseTimestamp(m['created_at']) ?? borrowDate;

    // Map 'borrowed' status to 'active' for internal use
    final status = (m['status'] as String?) == 'borrowed'
        ? 'active'
        : (m['status'] as String? ?? 'active');

    return LoanItem.fromJson({
      'id': m['id'] as String,
      'title': m['name'] as String,
      'borrower': m['borrower_name'] as String,
      'daysRemaining': null, // Will be computed from due_date if needed
      'createdAt': createdAt?.millisecondsSinceEpoch,
      'dueDate': borrowDate?.millisecondsSinceEpoch,
      'returnedAt': returnDate?.millisecondsSinceEpoch,
      'note': m['notes'] as String?,
      'contact': m['borrower_contact_id'] as String?,
      'imagePath': null,
      'imageUrl': m['photo_url'] as String?,
      'ownerId': m['user_id'] as String?,
      'status': status,
    });
  }

  @override
  Future<List<LoanItem>> loadActive() async {
    final res = await _client
        .from('items')
        .select()
        .eq('status', 'borrowed')
        .order('borrow_date', ascending: false)
        .limit(100);

    // The supabase client may return either a raw List or a response wrapper
    // depending on package version. Handle both dynamically.
    try {
      if (res is List) {
        final data = List<Map<String, dynamic>>.from(res);
        return data.map(_fromMap).toList();
      }
      // Fallback: try to access .data dynamically
      final dyn = res as dynamic;
      final d = dyn.data as List<dynamic>?;
      if (d == null) return [];
      final data = List<Map<String, dynamic>>.from(d);
      return data.map(_fromMap).toList();
    } catch (e) {
      throw Exception('Failed to load active loans: $e');
    }
  }

  @override
  Future<List<LoanItem>> loadHistory() async {
    final res = await _client
        .from('items')
        .select()
        .eq('status', 'returned')
        .order('created_at', ascending: false)
        .limit(200);
    try {
      if (res is List) {
        final data = List<Map<String, dynamic>>.from(res);
        return data.map(_fromMap).toList();
      }
      final dyn = res as dynamic;
      final d = dyn.data as List<dynamic>?;
      if (d == null) return [];
      final data = List<Map<String, dynamic>>.from(d);
      return data.map(_fromMap).toList();
    } catch (e) {
      throw Exception('Failed to load history loans: $e');
    }
  }

  @override
  Future<void> saveActive(List<LoanItem> active) async {
    // Upsert all items (simplest approach). For production prefer batched upserts
    for (final item in active) {
      var itemToUpsert = item;
      // If ownerId is not set, obtain current user id and set it so RLS
      // owner policies can match. If there's no authenticated user, fail
      // early so the caller sees a useful error instead of a DB 403.
      if (item.ownerId == null) {
        final uid = await currentUserId();
        if (uid == null) {
          throw Exception(
            'Tidak terautentikasi: tidak dapat menyimpan item ke server. Silakan masuk terlebih dahulu.',
          );
        }
        itemToUpsert = item.copyWith(ownerId: uid);
      }
      final m = _toMap(itemToUpsert);
      try {
        final res = await _client.from('items').upsert(m);
        // some versions return List, some return wrapper with .error/.data
        if (res is Map && res['error'] != null) {
          throw Exception(res['error']);
        }
      } catch (e) {
        throw Exception('Failed to upsert active item ${item.id}: $e');
      }
    }
  }

  @override
  Future<void> saveHistory(List<LoanItem> history) async {
    for (final item in history) {
      var itemToUpsert = item;
      if (item.ownerId == null) {
        final uid = await currentUserId();
        if (uid == null) {
          throw Exception(
            'Tidak terautentikasi: tidak dapat menyimpan riwayat ke server. Silakan masuk terlebih dahulu.',
          );
        }
        itemToUpsert = item.copyWith(ownerId: uid);
      }
      final m = _toMap(itemToUpsert);
      try {
        final res = await _client.from('items').upsert(m);
        if (res is Map && res['error'] != null) throw Exception(res['error']);
      } catch (e) {
        throw Exception('Failed to upsert history item ${item.id}: $e');
      }
    }
  }

  @override
  Future<void> saveAll({
    required List<LoanItem> active,
    required List<LoanItem> history,
  }) async {
    await Future.wait([saveActive(active), saveHistory(history)]);
  }

  @override
  Future<String?> uploadImage(String localPath, String itemId) async {
    // many supabase clients expose storage via client.storage
    final storage = _client.storage;
    // Ensure an authenticated user exists before attempting to upload. If
    // there's no user, Supabase storage will typically return 401/403 which
    // can be confusing; fail early with a clearer message.
    final uid = await currentUserId();
    if (uid == null) {
      throw Exception(
        'Tidak terautentikasi: tidak dapat mengunggah gambar. Silakan masuk terlebih dahulu.',
      );
    }

    // Create object name following RLS policy pattern: user_id/{filename}
    // Add timestamp to avoid 409 Duplicate errors when updating item photos
    // This allows RLS policy to check: auth.uid()::text = (storage.foldername(name))[1]
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final key = '$uid/${itemId}_$timestamp.jpg';

    // Try to upload using several possible APIs and inspect responses.
    final from = (storage as dynamic).from(_kImagesBucket);

    // Helper to interpret a response object for errors
    bool responseHasError(dynamic r) {
      if (r == null) {
        return false;
      }
      try {
        if (r is Map && r['error'] != null) {
          return true;
        }
        if (r is Map &&
            r['statusCode'] != null &&
            (r['statusCode'] as int) >= 400) {
          return true;
        }
      } catch (_) {}
      return false;
    }

    try {
      try {
        final res = await (from as dynamic).upload(key, File(localPath));
        if (responseHasError(res)) {
          throw Exception('Upload failed (upload API): $res');
        }
      } catch (e1) {
        // try older method: uploadBinary/uploadFile
        try {
          final bytes = await File(localPath).readAsBytes();
          final res2 = await (from as dynamic).uploadBinary(key, bytes);
          if (responseHasError(res2)) {
            throw Exception('Upload failed (uploadBinary): $res2');
          }
        } catch (e2) {
          // All upload attempts failed — include context to help debugging
          final msg =
              'All storage upload attempts failed for bucket="$_kImagesBucket" key="$key" user="$uid": $e1 / $e2';
          // If an upload server URL is configured, try it as a fallback.
          if ((_kUploadServerUrl ?? '').isNotEmpty) {
            try {
              final uri = Uri.parse('$_kUploadServerUrl/upload');
              final request = http.MultipartRequest('POST', uri);
              request.files.add(
                await http.MultipartFile.fromPath('file', localPath),
              );
              request.fields['bucket'] = _kImagesBucket;
              final streamed = await request.send();
              final resp = await http.Response.fromStream(streamed);
              if (resp.statusCode >= 200 && resp.statusCode < 300) {
                final body = resp.body;
                try {
                  final Map<String, dynamic> parsed = body.isNotEmpty
                      ? Map<String, dynamic>.from(jsonDecode(body) as Map)
                      : <String, dynamic>{};
                  if (parsed['url'] is String) return parsed['url'] as String;
                } catch (_) {
                  // ignore parse error and fall through to return null
                }
                return null;
              } else {
                // upload server failed — include its response in message
                throw Exception(
                  'Upload server responded ${resp.statusCode}: ${resp.body}',
                );
              }
            } catch (uploadServerErr) {
              throw Exception(
                '$msg; fallback upload server failed: $uploadServerErr',
              );
            }
          }
          throw Exception(msg);
        }
      }

      // Try to obtain a public URL
      try {
        final pub = (from as dynamic).getPublicUrl(key);
        if (pub is Map && pub['publicUrl'] != null) {
          return pub['publicUrl'] as String;
        }
        if (pub is String) {
          return pub;
        }
      } catch (_) {}

      // Fallback to signed URL
      try {
        final signed = await (from as dynamic).createSignedUrl(
          key,
          60 * 60 * 24 * 365,
        );
        if (signed is Map &&
            (signed['signedURL'] != null || signed['signedUrl'] != null)) {
          return (signed['signedURL'] ?? signed['signedUrl']) as String;
        }
        if (signed is String) return signed;
      } catch (_) {}

      // If we reach here return null so callers can use local path
      return null;
    } catch (e, st) {
      // Write a debug file with full details to help investigation.
      try {
        final now = DateTime.now().toUtc().millisecondsSinceEpoch;
        final path = '/tmp/supabase_upload_debug_$now.log';
        final f = File(path);
        final contents = StringBuffer()
          ..writeln('uploadImage debug')
          ..writeln('time: ${DateTime.now().toUtc().toIso8601String()}')
          ..writeln('bucket: $_kImagesBucket')
          ..writeln('key: $key')
          ..writeln('user: $uid')
          ..writeln('\nexception:')
          ..writeln(e.toString())
          ..writeln('\nstacktrace:')
          ..writeln(st.toString());
        await f.writeAsString(contents.toString());
        throw Exception('uploadImage failed: $e (debug log: $path)');
      } catch (fsErr) {
        // If writing the file failed, still throw the original error.
        throw Exception(
          'uploadImage failed: $e (also failed to write debug file: $fsErr)',
        );
      }
    }
  }

  @override
  Future<String?> currentUserId() async {
    try {
      final auth = _client.auth as dynamic;
      // newer client: auth.currentUser?.id
      try {
        final u = auth.currentUser;
        return u?.id as String?;
      } catch (_) {}

      // older client: auth.user()?.id or session
      try {
        final maybe = await (auth as dynamic).getUser();
        final user = maybe?.user ?? maybe;
        return user?.id as String?;
      } catch (_) {}
    } catch (_) {}
    return null;
  }

  /// Get a signed URL for a photo stored in the bucket.
  /// The photoUrl should be the storage path (e.g., "user_id/item_id_timestamp.jpg")
  /// Returns a signed URL that works with private buckets.
  Future<String?> getSignedUrl(String photoUrl) async {
    if (photoUrl.isEmpty) return null;

    try {
      final storage = _client.storage;
      final from = (storage as dynamic).from(_kImagesBucket);

      // Extract just the path if it's a full URL
      String path = photoUrl;
      if (photoUrl.contains('/storage/v1/object/')) {
        // Extract path from full URL
        final parts = photoUrl.split('/storage/v1/object/');
        if (parts.length > 1) {
          // Remove bucket prefix (public/bucket_name/ or authenticated/bucket_name/)
          final afterObject = parts[1];
          final pathParts = afterObject.split('/');
          if (pathParts.length > 2) {
            path = pathParts.sublist(2).join('/');
          }
        }
      }

      // Create a signed URL valid for 1 year
      final signed = await (from as dynamic).createSignedUrl(
        path,
        60 * 60 * 24 * 365, // 1 year in seconds
      );

      if (signed is Map &&
          (signed['signedURL'] != null || signed['signedUrl'] != null)) {
        return (signed['signedURL'] ?? signed['signedUrl']) as String;
      }
      if (signed is String) {
        return signed;
      }
    } catch (e) {
      print('Error creating signed URL for $photoUrl: $e');
    }

    return null;
  }

  @override
  Future<void> deleteItem(String itemId) async {
    try {
      // First, get the item to check if it has a photo
      final queryRes = await _client
          .from('items')
          .select('photo_url')
          .eq('id', itemId)
          .maybeSingle();

      String? photoUrl;
      if (queryRes is Map<String, dynamic> && queryRes['photo_url'] != null) {
        photoUrl = queryRes['photo_url'] as String;
      }

      // If there's a photo, delete it from storage
      if (photoUrl != null && photoUrl.isNotEmpty) {
        try {
          // Extract the file path from the URL
          // URL format: https://[project].supabase.co/storage/v1/object/public/item_photos/[path]
          // or: https://[project].supabase.co/storage/v1/object/sign/item_photos/[path]?token=...
          String? storagePath;

          if (photoUrl.contains('/storage/v1/object/')) {
            final parts = photoUrl.split('/storage/v1/object/');
            if (parts.length > 1) {
              final afterObject = parts[1];
              // Remove 'public/' or 'sign/' prefix
              final pathParts = afterObject.split('/');
              if (pathParts.length > 2) {
                // Skip 'public' or 'sign', then bucket name, get the rest
                storagePath = pathParts.sublist(2).join('/');
                // Remove query parameters if present (for signed URLs)
                if (storagePath.contains('?')) {
                  storagePath = storagePath.split('?')[0];
                }
              }
            }
          }

          if (storagePath != null && storagePath.isNotEmpty) {
            // Delete from storage bucket
            await _client.storage.from(_kImagesBucket).remove([storagePath]);

            print('Photo deleted successfully from storage: $storagePath');
          }
        } catch (storageError) {
          // Log but don't fail the whole operation if storage deletion fails
          print('Warning: Failed to delete photo from storage: $storageError');
        }
      }

      // Delete the item record from database
      final res = await _client.from('items').delete().eq('id', itemId);
      if (res is Map && res['error'] != null) {
        throw Exception(res['error']);
      }
    } catch (e) {
      throw Exception('Failed to delete item $itemId: $e');
    }
  }
}
