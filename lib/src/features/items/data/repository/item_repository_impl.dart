import 'dart:io';

import 'package:pinjam_in/src/features/items/domain/models/item_model.dart';
import 'package:pinjam_in/src/features/items/domain/repository/item_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ItemRepositoryImpl implements ItemRepository {
  final SupabaseClient _supabaseClient;
  final String _bucketName = 'item_photos';

  ItemRepositoryImpl(this._supabaseClient);

  String get _userId => _supabaseClient.auth.currentUser!.id;

  Future<String?> _uploadPhoto(File photo, String itemId) async {
    final fileExtension = photo.path.split('.').last;
    final fileName = '$itemId.$fileExtension';
    final filePath = '$_userId/$fileName';

    try {
      await _supabaseClient.storage
          .from(_bucketName)
          .upload(
            filePath,
            photo,
            fileOptions: const FileOptions(cacheControl: '3600', upsert: true),
          );
      return _supabaseClient.storage.from(_bucketName).getPublicUrl(filePath);
    } catch (e) {
      // TODO: Handle exception properly
      throw Exception('Failed to upload photo: $e');
    }
  }

  @override
  Future<void> addItem(Item item, {File? photo}) async {
    try {
      String? photoUrl;
      if (photo != null) {
        photoUrl = await _uploadPhoto(photo, item.id);
      }
      final itemWithUser = item.toMap()..['photo_url'] = photoUrl;
      await _supabaseClient.from('items').insert(itemWithUser);
    } catch (e) {
      // TODO: Handle exception properly
      throw Exception('Failed to add item: $e');
    }
  }

  @override
  Future<void> deleteItem(String id) async {
    try {
      await _supabaseClient.from('items').delete().match({
        'id': id,
        'user_id': _userId,
      });
    } catch (e) {
      // TODO: Handle exception properly
      throw Exception('Failed to delete item: $e');
    }
  }

  @override
  Future<Item> getItem(String id) async {
    try {
      final response = await _supabaseClient.from('items').select().match({
        'id': id,
        'user_id': _userId,
      }).single();
      return Item.fromMap(response);
    } catch (e) {
      // TODO: Handle exception properly
      throw Exception('Failed to get item: $e');
    }
  }

  @override
  Future<List<Item>> getItems() async {
    try {
      final response = await _supabaseClient
          .from('items')
          .select()
          .eq('user_id', _userId)
          .order('borrowed_at', ascending: false);
      return (response as List).map((item) => Item.fromMap(item)).toList();
    } catch (e) {
      // TODO: Handle exception properly
      throw Exception('Failed to get items: $e');
    }
  }

  @override
  Future<void> updateItem(Item item, {File? photo}) async {
    try {
      String? photoUrl;
      if (photo != null) {
        photoUrl = await _uploadPhoto(photo, item.id);
      }
      final itemMap = item.toMap();
      if (photoUrl != null) {
        itemMap['photo_url'] = photoUrl;
      }

      await _supabaseClient.from('items').update(itemMap).match({
        'id': item.id,
        'user_id': _userId,
      });
    } catch (e) {
      // TODO: Handle exception properly
      throw Exception('Failed to update item: $e');
    }
  }
}
