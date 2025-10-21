import 'dart:convert';
import 'dart:io';

import 'package:flutter_dotenv/flutter_dotenv.dart' show dotenv;
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/loan_item.dart';
import 'persistence_service.dart';

/// Minimal Supabase-backed PersistenceService implementation.
///
/// This implementation assumes a `loans` table with columns roughly:
/// id (text primary key), title (text), borrower (text), created_at (bigint),
/// due_date (bigint), returned_at (bigint), note (text), contact (text),
/// image_url (text), owner_id (text), status (text), days_remaining (int)
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
  static const _kImagesBucket = 'public-images';
  // Optional: an external upload server you can run (see server/upload_server)
  static final _kUploadServerUrl = dotenv.env['SUPABASE_UPLOAD_SERVER'];

  static Map<String, dynamic> _toMap(LoanItem item) => {
    'id': item.id,
    'title': item.title,
    'borrower': item.borrower,
    'days_remaining': item.daysRemaining,
    'created_at': item.createdAt?.millisecondsSinceEpoch,
    'due_date': item.dueDate?.millisecondsSinceEpoch,
    'returned_at': item.returnedAt?.millisecondsSinceEpoch,
    'note': item.note,
    'contact': item.contact,
    'image_url': item.imageUrl,
    'owner_id': item.ownerId,
    'status': item.status,
  };

  static LoanItem _fromMap(Map<String, dynamic> m) => LoanItem.fromJson({
    'id': m['id'] as String,
    'title': m['title'] as String,
    'borrower': m['borrower'] as String,
    'daysRemaining': m['days_remaining'] as int?,
    'createdAt': m['created_at'] as int?,
    'dueDate': m['due_date'] as int?,
    'returnedAt': m['returned_at'] as int?,
    'note': m['note'] as String?,
    'contact': m['contact'] as String?,
    'imagePath': null,
    'imageUrl': m['image_url'] as String?,
    'ownerId': m['owner_id'] as String?,
    'status': m['status'] as String?,
  });

  @override
  Future<List<LoanItem>> loadActive() async {
    final res = await _client
        .from('loans')
        .select()
        .eq('status', 'active')
        .order('due_date', ascending: true)
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
        .from('loans')
        .select()
        .neq('status', 'active')
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
        final res = await _client.from('loans').upsert(m);
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
        final res = await _client.from('loans').upsert(m);
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

    // Create a deterministic object name to avoid collisions
    final key = 'items/$itemId/${DateTime.now().millisecondsSinceEpoch}.jpg';

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
}
