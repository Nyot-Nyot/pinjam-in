import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pinjam_in/src/features/auth/data/provider/auth_provider.dart';
import 'package:pinjam_in/src/features/items/data/provider/item_provider.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itemsAsync = ref.watch(itemsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pinjam.in'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await ref.read(authRepositoryProvider).signOut();
            },
          ),
        ],
      ),
      body: itemsAsync.when(
        data: (items) {
          if (items.isEmpty) {
            return const Center(child: Text('Belum ada barang yang dipinjam.'));
          }
          return ListView.builder(
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              return ListTile(
                leading: item.photoUrl != null
                    ? Image.network(
                        item.photoUrl!,
                        width: 50,
                        height: 50,
                        fit: BoxFit.cover,
                      )
                    : const Icon(Icons.image_not_supported),
                title: Text(item.name),
                subtitle: Text('Dipinjam dari: ${item.borrowerName}'),
                // TODO: Add onTap to show item details
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text('Error: $error')),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.go('/add-item'),
        child: const Icon(Icons.add),
      ),
    );
  }
}
