import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pinjam_in/src/features/auth/data/provider/auth_provider.dart';
import 'package:pinjam_in/src/features/items/data/repository/item_repository_impl.dart';
import 'package:pinjam_in/src/features/items/domain/models/item_model.dart';
import 'package:pinjam_in/src/features/items/domain/repository/item_repository.dart';

// Provider for ItemRepository
final itemRepositoryProvider = Provider<ItemRepository>((ref) {
  final supabaseClient = ref.watch(supabaseClientProvider);
  return ItemRepositoryImpl(supabaseClient);
});

// Provider to get all items
final itemsProvider = FutureProvider<List<Item>>((ref) {
  final itemRepository = ref.watch(itemRepositoryProvider);
  return itemRepository.getItems();
});

// Provider to get a single item by ID
final itemProvider = FutureProvider.family<Item, String>((ref, id) {
  final itemRepository = ref.watch(itemRepositoryProvider);
  return itemRepository.getItem(id);
});
