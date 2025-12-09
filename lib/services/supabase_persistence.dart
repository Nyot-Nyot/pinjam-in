import 'dart:convert';
import 'dart:io';

import 'package:flutter_dotenv/flutter_dotenv.dart' show dotenv;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../constants/storage_keys.dart';
import '../models/loan_item.dart';
import '../utils/logger.dart';
import '../utils/retry.dart';
import 'persistence_service.dart';

/// Simple cache entry for signed URLs.
class _SignedUrlCacheEntry {
  final String url;
  final DateTime ts;
  _SignedUrlCacheEntry(this.url) : ts = DateTime.now();
}

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
  // In-memory caches to reduce repeated network calls for common queries.
  List<LoanItem>? _cachedActive;
  DateTime? _cachedActiveTs;
  List<LoanItem>? _cachedHistory;
  DateTime? _cachedHistoryTs;
  final Duration _queryCacheTtl = const Duration(seconds: 30);

  final Map<String, _SignedUrlCacheEntry> _signedUrlCache = {};

  /// Invalidate in-memory and persisted caches. If [itemId] is provided attempt
  /// to remove any signed-url entries referencing that id; otherwise clear all.
  Future<void> _invalidateCaches({String? itemId}) async {
    _cachedActive = null;
    _cachedActiveTs = null;
    _cachedHistory = null;
    _cachedHistoryTs = null;

    // Remove persisted copies
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(StorageKeys.activeLoansKey);
      await prefs.remove(StorageKeys.historyLoansKey);
    } catch (_) {}

    // Remove signed url cache entries matching itemId if provided, else clear all
    if (itemId == null) {
      _signedUrlCache.clear();
    } else {
      try {
        final keysToRemove = <String>[];
        _signedUrlCache.forEach((k, v) {
          if (k.contains(itemId)) keysToRemove.add(k);
        });
        for (final k in keysToRemove) {
          _signedUrlCache.remove(k);
        }
      } catch (_) {}
    }
  }

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
  static final _kImagesBucket = StorageKeys.imagesBucket;
  // Optional: an external upload server you can run (see server/upload_server)
  static final _kUploadServerUrl = dotenv.env[StorageKeys.envUploadServerUrl];

  /// Helper method to extract error messages from Supabase auth responses
  static String? authErrorFromResponse(dynamic res, [dynamic caught]) {
    try {
      if (res == null) return caught?.toString();
    } catch (_) {}
    try {
      final err = (res as dynamic).error;
      if (err != null) return err.toString();
    } catch (_) {}
    try {
      final sm = (res as dynamic).statusMessage;
      if (sm != null) return sm.toString();
    } catch (_) {}
    try {
      final data = (res as dynamic).data;
      if (data != null) {
        try {
          final derr = (data as dynamic).error;
          if (derr != null) return derr.toString();
        } catch (_) {}
        try {
          final user = (data as dynamic).user;
          if (user == null) return 'Authentication failed';
        } catch (_) {}
      }
    } catch (_) {}
    return caught?.toString();
  }

  static Map<String, dynamic> _toMap(LoanItem item) => {
    StorageKeys.columnId: item.id,
    StorageKeys.columnUserId: item.ownerId,
    StorageKeys.columnName: item.title,
    StorageKeys.columnBorrowerName: item.borrower,
    StorageKeys.columnBorrowerContactId: item.contact,
    StorageKeys.columnBorrowDate: item.createdAt?.toIso8601String(),
    'due_date': item.dueDate != null
        ? item.dueDate!.toLocal().toIso8601String().split(
            'T',
          )[0] // Date only in local time
        : null,
    StorageKeys.columnReturnDate: item.returnedAt != null
        ? item.returnedAt!.toLocal().toIso8601String().split(
            'T',
          )[0] // Date only in local time
        : null,
    StorageKeys.columnStatus: item.status == 'active'
        ? 'borrowed'
        : item.status,
    StorageKeys.columnNotes: item.note,
    StorageKeys.columnPhotoUrl: item.imageUrl,
    StorageKeys.columnCreatedAt: item.createdAt?.toIso8601String(),
  };

  static LoanItem _fromMap(Map<String, dynamic> m) {
    // Parse timestamps
    DateTime? parseTimestamp(dynamic value) {
      if (value == null) return null;
      if (value is String) return DateTime.tryParse(value);
      if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
      return null;
    }

    final borrowDate = parseTimestamp(m[StorageKeys.columnBorrowDate]);
    final dueDate = parseTimestamp(m['due_date']);
    final returnDate = parseTimestamp(m[StorageKeys.columnReturnDate]);
    final createdAt =
        parseTimestamp(m[StorageKeys.columnCreatedAt]) ?? borrowDate;

    // Map 'borrowed' status to 'active' for internal use
    final status = (m[StorageKeys.columnStatus] as String?) == 'borrowed'
        ? 'active'
        : (m[StorageKeys.columnStatus] as String? ?? 'active');

    return LoanItem.fromJson({
      'id': m[StorageKeys.columnId] as String,
      'title': m[StorageKeys.columnName] as String,
      'borrower': m[StorageKeys.columnBorrowerName] as String,
      'daysRemaining': null, // Will be computed from due_date if needed
      'createdAt': createdAt?.millisecondsSinceEpoch,
      'dueDate': dueDate?.millisecondsSinceEpoch,
      'returnedAt': returnDate?.millisecondsSinceEpoch,
      'note': m[StorageKeys.columnNotes] as String?,
      'contact': m[StorageKeys.columnBorrowerContactId] as String?,
      'imagePath': null,
      'imageUrl': m[StorageKeys.columnPhotoUrl] as String?,
      'ownerId': m[StorageKeys.columnUserId] as String?,
      'status': status,
    });
  }

  @override
  Future<List<LoanItem>> loadActive() async {
    // Return cached result if fresh
    try {
      if (_cachedActive != null && _cachedActiveTs != null) {
        if (DateTime.now().difference(_cachedActiveTs!) < _queryCacheTtl) {
          return _cachedActive!;
        }
      }
    } catch (_) {}
    dynamic res;
    Exception? lastErr;
    // Retry loop with small backoff
    for (var attempt = 1; attempt <= 3; attempt++) {
      try {
        res = await _client
            .from(StorageKeys.itemsTable)
            .select()
            .eq('status', 'borrowed')
            .order('borrow_date', ascending: false)
            .limit(100);
        lastErr = null;
        break;
      } catch (e) {
        lastErr = Exception('Attempt $attempt failed: $e');
        if (attempt < 3) {
          await Future.delayed(Duration(milliseconds: 200 * attempt));
        }
      }
    }

    if (res == null && lastErr != null) {
      // Try to return persisted cache from SharedPreferences as offline fallback
      try {
        final prefs = await SharedPreferences.getInstance();
        final s = prefs.getString(StorageKeys.activeLoansKey);
        if (s != null && s.isNotEmpty) {
          final decoded = jsonDecode(s) as List<dynamic>;
          final list = decoded
              .map((e) => LoanItem.fromJson(Map<String, dynamic>.from(e)))
              .toList();
          _cachedActive = list;
          _cachedActiveTs = DateTime.now();
          return list;
        }
      } catch (_) {}
      throw lastErr;
    }

    // The supabase client may return either a raw List or a response wrapper
    // depending on package version. Handle both dynamically.
    try {
      List<LoanItem> list;
      if (res is List) {
        final data = List<Map<String, dynamic>>.from(res);
        list = data.map(_fromMap).toList();
      } else {
        final dyn = res as dynamic;
        final d = dyn.data as List<dynamic>?;
        if (d == null) return [];
        final data = List<Map<String, dynamic>>.from(d);
        list = data.map(_fromMap).toList();
      }
      _cachedActive = list;
      _cachedActiveTs = DateTime.now();
      // Persist to SharedPreferences for offline fallback
      try {
        final prefs = await SharedPreferences.getInstance();
        final enc = jsonEncode(list.map((e) => e.toJson()).toList());
        await prefs.setString(StorageKeys.activeLoansKey, enc);
      } catch (_) {}
      return list;
    } catch (e) {
      throw Exception('Failed to load active loans: $e');
    }
  }

  @override
  Future<List<LoanItem>> loadHistory() async {
    // Return cached result if fresh
    try {
      if (_cachedHistory != null && _cachedHistoryTs != null) {
        if (DateTime.now().difference(_cachedHistoryTs!) < _queryCacheTtl) {
          return _cachedHistory!;
        }
      }
    } catch (_) {}
    dynamic res;
    Exception? lastErr;
    // Retry loop with small backoff
    for (var attempt = 1; attempt <= 3; attempt++) {
      try {
        res = await _client
            .from(StorageKeys.itemsTable)
            .select()
            .eq(StorageKeys.columnStatus, 'returned')
            .order(StorageKeys.columnCreatedAt, ascending: false)
            .limit(200);
        lastErr = null;
        break;
      } catch (e) {
        lastErr = Exception('Attempt $attempt failed: $e');
        if (attempt < 3) {
          await Future.delayed(Duration(milliseconds: 200 * attempt));
        }
      }
    }

    if (res == null && lastErr != null) {
      // Try to return persisted cache from SharedPreferences as offline fallback
      try {
        final prefs = await SharedPreferences.getInstance();
        final s = prefs.getString(StorageKeys.historyLoansKey);
        if (s != null && s.isNotEmpty) {
          final decoded = jsonDecode(s) as List<dynamic>;
          final list = decoded
              .map((e) => LoanItem.fromJson(Map<String, dynamic>.from(e)))
              .toList();
          _cachedHistory = list;
          _cachedHistoryTs = DateTime.now();
          return list;
        }
      } catch (_) {}
      throw lastErr;
    }

    try {
      List<LoanItem> list;
      if (res is List) {
        final data = List<Map<String, dynamic>>.from(res);
        list = data.map(_fromMap).toList();
      } else {
        final dyn = res as dynamic;
        final d = dyn.data as List<dynamic>?;
        if (d == null) return [];
        final data = List<Map<String, dynamic>>.from(d);
        list = data.map(_fromMap).toList();
      }
      _cachedHistory = list;
      _cachedHistoryTs = DateTime.now();
      // Persist to SharedPreferences for offline fallback
      try {
        final prefs = await SharedPreferences.getInstance();
        final enc = jsonEncode(list.map((e) => e.toJson()).toList());
        await prefs.setString(StorageKeys.historyLoansKey, enc);
      } catch (_) {}
      return list;
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
        final res = await _client.from(StorageKeys.itemsTable).upsert(m);
        // some versions return List, some return wrapper with .error/.data
        if (res is Map && res['error'] != null) {
          throw Exception(res['error']);
        }
      } catch (e) {
        throw Exception('Failed to upsert active item ${item.id}: $e');
      }
    }
    // Invalidate caches because we changed server state
    await _invalidateCaches();
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
        final res = await _client.from(StorageKeys.itemsTable).upsert(m);
        if (res is Map && res['error'] != null) throw Exception(res['error']);
      } catch (e) {
        throw Exception('Failed to upsert history item ${item.id}: $e');
      }
    }
    // Invalidate caches because we changed server state
    await _invalidateCaches();
  }

  @override
  Future<void> saveAll({
    required List<LoanItem> active,
    required List<LoanItem> history,
  }) async {
    await Future.wait([saveActive(active), saveHistory(history)]);
    // ensure caches cleared after batch save
    await _invalidateCaches();
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
      // Wrap upload logic in a retry in case of transient failures
      await retry(() async {
        try {
          final res = await (from as dynamic).upload(key, File(localPath));
          if (responseHasError(res)) {
            throw Exception('Upload failed (upload API): $res');
          }
          return res;
        } catch (e1) {
          // try older method: uploadBinary/uploadFile
          try {
            final bytes = await File(localPath).readAsBytes();
            final res2 = await (from as dynamic).uploadBinary(key, bytes);
            if (responseHasError(res2)) {
              throw Exception('Upload failed (uploadBinary): $res2');
            }
            return res2;
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
      }, attempts: 3);

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

    AppLogger.debug(
      'getSignedUrl: Input URL: $photoUrl',
      'SupabasePersistence',
    );

    // Check in-memory cache first
    try {
      final cached = _signedUrlCache[photoUrl];
      if (cached != null) {
        // signed URLs are set to be long-lived; reuse if not too old (7 days)
        if (DateTime.now().difference(cached.ts) < const Duration(days: 7)) {
          AppLogger.debug(
            'getSignedUrl: Using cached URL',
            'SupabasePersistence',
          );
          return cached.url;
        } else {
          _signedUrlCache.remove(photoUrl);
        }
      }
    } catch (_) {}

    AppLogger.debug(
      'getSignedUrl: Creating new signed URL',
      'SupabasePersistence',
    );

    try {
      final storage = _client.storage;
      final from = (storage as dynamic).from(_kImagesBucket);

      // Extract just the path from the URL
      String path = photoUrl;

      // If it's a full URL, extract the path after the bucket name
      if (photoUrl.contains('/storage/v1/object/')) {
        // For URLs like:
        // https://xxx.supabase.co/storage/v1/object/public/item_photos/user_id/file.jpg
        // We need to extract: user_id/file.jpg

        final parts = photoUrl.split('/storage/v1/object/');
        if (parts.length > 1) {
          final afterObject = parts[1];
          // Split by '/' and skip 'public' or 'authenticated' and bucket name
          final pathParts = afterObject.split('/');

          // Find where our bucket name is
          int bucketIndex = -1;
          for (int i = 0; i < pathParts.length; i++) {
            if (pathParts[i] == _kImagesBucket) {
              bucketIndex = i;
              break;
            }
          }

          // If found, take everything after the bucket name
          if (bucketIndex >= 0 && bucketIndex + 1 < pathParts.length) {
            path = pathParts.sublist(bucketIndex + 1).join('/');
          }
        }
      }

      AppLogger.debug(
        'getSignedUrl: Extracted path: $path',
        'SupabasePersistence',
      );

      // Create a signed URL valid for 1 year
      final signed = await (from as dynamic).createSignedUrl(
        path,
        60 * 60 * 24 * 365, // 1 year in seconds
      );

      AppLogger.debug(
        'getSignedUrl: Signed result: $signed',
        'SupabasePersistence',
      );

      if (signed is Map &&
          (signed['signedURL'] != null || signed['signedUrl'] != null)) {
        final url = (signed['signedURL'] ?? signed['signedUrl']) as String;
        _signedUrlCache[photoUrl] = _SignedUrlCacheEntry(url);
        return url;
      }
      if (signed is String) {
        _signedUrlCache[photoUrl] = _SignedUrlCacheEntry(signed);
        return signed;
      }
    } catch (e) {
      AppLogger.error('getSignedUrl: Error - $e', e, 'SupabasePersistence');
      AppLogger.error(
        'Error creating signed URL for $photoUrl',
        e,
        'SupabasePersistence',
      );
    }

    return null;
  }

  /// Return a public URL if the bucket/object is publicly accessible.
  /// This is an optional helper to avoid using signed URLs for public buckets.
  Future<String?> getPublicUrl(String photoUrl) async {
    if (photoUrl.isEmpty) return null;
    try {
      final storage = _client.storage;
      final from = (storage as dynamic).from(_kImagesBucket);

      // If we've been given a full URL, try to extract the path
      String path = photoUrl;
      if (photoUrl.contains('/storage/v1/object/')) {
        final parts = photoUrl.split('/storage/v1/object/');
        if (parts.length > 1) {
          final afterObject = parts[1];
          final pathParts = afterObject.split('/');
          int bucketIndex = -1;
          for (int i = 0; i < pathParts.length; i++) {
            if (pathParts[i] == _kImagesBucket) {
              bucketIndex = i;
              break;
            }
          }
          if (bucketIndex >= 0 && bucketIndex + 1 < pathParts.length) {
            path = pathParts.sublist(bucketIndex + 1).join('/');
          }
        }
      }

      final pub = (from as dynamic).getPublicUrl(path);
      if (pub is Map && pub['publicUrl'] != null) {
        return pub['publicUrl'] as String;
      }
      if (pub is String) return pub;
    } catch (e) {
      AppLogger.debug('getPublicUrl: error $e', 'SupabasePersistence');
    }
    return null;
  }

  @override
  Future<void> invalidateCache({String? itemId}) async {
    await _invalidateCaches(itemId: itemId);
  }

  @override
  Future<void> deleteItem(String itemId) async {
    try {
      // First, get the item to check if it has a photo
      final queryRes = await _client
          .from(StorageKeys.itemsTable)
          .select(StorageKeys.columnPhotoUrl)
          .eq(StorageKeys.columnId, itemId)
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
            // Delete from storage bucket (retry on transient failures)
            await retry(() async {
              return await _client.storage.from(_kImagesBucket).remove([
                storagePath!,
              ]);
            }, attempts: 3);

            AppLogger.success(
              'Photo deleted successfully from storage: $storagePath',
              'SupabasePersistence',
            );
          }
        } catch (storageError) {
          // Log but don't fail the whole operation if storage deletion fails
          AppLogger.warning(
            'Failed to delete photo from storage: $storageError',
            'SupabasePersistence',
          );
        }
      }

      // Delete the item record from database
      await retry(() async {
        final r = await _client
            .from(StorageKeys.itemsTable)
            .delete()
            .eq(StorageKeys.columnId, itemId);
        if (r is Map && r['error'] != null) throw Exception(r['error']);
        return r;
      }, attempts: 3);
      // Invalidate caches related to this item
      await _invalidateCaches(itemId: itemId);
    } catch (e) {
      throw Exception('Failed to delete item $itemId: $e');
    }
  }
}
