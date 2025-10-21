import 'dart:io';

import 'package:pinjam_in/src/features/items/domain/models/item_model.dart';

abstract class ItemRepository {
  Future<List<Item>> getItems();
  Future<Item> getItem(String id);
  Future<void> addItem(Item item, {File? photo});
  Future<void> updateItem(Item item, {File? photo});
  Future<void> deleteItem(String id);
}
