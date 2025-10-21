import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pinjam_in/src/features/auth/data/provider/auth_provider.dart';
import 'package:pinjam_in/src/features/items/data/provider/item_provider.dart';
import 'package:pinjam_in/src/features/items/domain/models/item_model.dart';
import 'package:uuid/uuid.dart';

class AddItemScreen extends ConsumerStatefulWidget {
  const AddItemScreen({super.key});

  @override
  ConsumerState<AddItemScreen> createState() => _AddItemScreenState();
}

class _AddItemScreenState extends ConsumerState<AddItemScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _borrowerNameController = TextEditingController();
  final _borrowerContactController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _borrowerNameController.dispose();
    _borrowerContactController.dispose();
    super.dispose();
  }

  Future<void> _saveItem() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      final user = ref.read(supabaseClientProvider).auth.currentUser;
      if (user == null) {
        // Handle user not logged in
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error: User not logged in.')),
        );
        setState(() {
          _isLoading = false;
        });
        return;
      }

      final newItem = Item(
        id: const Uuid().v4(),
        name: _nameController.text,
        description: _descriptionController.text,
        borrowedAt: DateTime.now(),
        borrowerName: _borrowerNameController.text,
        borrowerContact: _borrowerContactController.text,
        userId: user.id,
      );

      try {
        await ref.read(itemRepositoryProvider).addItem(newItem);
        // Invalidate provider to refetch the list
        ref.invalidate(itemsProvider);
        if (mounted) {
          context.pop();
        }
      } catch (e) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to add item: $e')));
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add New Item')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Item Name'),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter the item name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description (Optional)',
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _borrowerNameController,
                decoration: const InputDecoration(labelText: 'Borrower Name'),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter the borrower name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _borrowerContactController,
                decoration: const InputDecoration(
                  labelText: 'Borrower Contact (Optional)',
                ),
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _isLoading ? null : _saveItem,
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Save Item'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
