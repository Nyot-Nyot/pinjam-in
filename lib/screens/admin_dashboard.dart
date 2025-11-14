import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/loan_item.dart';
import '../models/user_profile.dart';
import '../theme/app_theme.dart';
import '../utils/logger.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  bool _loading = true;
  List<LoanItem> _items = [];
  List<UserProfile> _profiles = [];
  String _error = '';

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() {
      _loading = true;
      _error = '';
    });
    try {
      final client = Supabase.instance.client;
      final itemsRes = await client
          .from('items')
          .select()
          .order('created_at', ascending: false)
          .limit(500);
      final profilesRes = await client
          .from('profiles')
          .select()
          .order('updated_at', ascending: false)
          .limit(200);

      final itemsList = <LoanItem>[];
      try {
        final data = itemsRes is List
            ? List<Map<String, dynamic>>.from(itemsRes)
            : List<Map<String, dynamic>>.from(
                (itemsRes as dynamic).data as List<dynamic>,
              );
        for (final m in data) {
          try {
            itemsList.add((SupabasePersistenceShim.fromMap(m)));
          } catch (_) {}
        }
      } catch (e) {
        // fallback: try to parse as dynamic list
      }

      final profList = <UserProfile>[];
      try {
        final pdata = profilesRes is List
            ? List<Map<String, dynamic>>.from(profilesRes)
            : List<Map<String, dynamic>>.from(
                (profilesRes as dynamic).data as List<dynamic>,
              );
        for (final p in pdata) {
          try {
            profList.add(UserProfile.fromMap(p));
          } catch (_) {}
        }
      } catch (_) {}

      setState(() {
        _items = itemsList;
        _profiles = profList;
      });
    } catch (e, st) {
      AppLogger.error('Failed to load admin data', e, 'AdminDashboard');
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        backgroundColor: AppTheme.primaryPurple,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error.isNotEmpty
          ? Center(child: Text('Error: $_error'))
          : RefreshIndicator(
              onRefresh: _loadAll,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  const Text(
                    'Profiles',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  ..._profiles.map(
                    (p) => ListTile(
                      title: Text(p.fullName ?? p.id),
                      subtitle: Text('role: ${p.role}'),
                      trailing: Text(
                        p.id,
                        style: const TextStyle(fontSize: 10),
                      ),
                    ),
                  ),
                  const Divider(),
                  const Text(
                    'Items',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  ..._items.map(
                    (it) => ListTile(
                      title: Text(it.title),
                      subtitle: Text(
                        'borrower: ${it.borrower} • owner: ${it.ownerId ?? 'unknown'}',
                      ),
                      trailing: Text(it.status),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

// SupabasePersistence shim to reuse existing mapping logic from SupabasePersistence
class SupabasePersistenceShim {
  static LoanItem fromMap(Map<String, dynamic> m) {
    // minimal mapping similar to SupabasePersistence._fromMap
    DateTime? parseTimestamp(dynamic value) {
      if (value == null) return null;
      if (value is String) return DateTime.tryParse(value);
      if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
      return null;
    }

    final borrowDate = parseTimestamp(m['borrow_date']);
    final dueDate = parseTimestamp(m['due_date']);
    final returnDate = parseTimestamp(m['return_date']);
    final createdAt = parseTimestamp(m['created_at']) ?? borrowDate;
    final status = (m['status'] as String?) == 'borrowed'
        ? 'active'
        : (m['status'] as String? ?? 'active');

    return LoanItem.fromJson({
      'id': m['id'] as String,
      'title': m['name'] as String? ?? 'Untitled',
      'borrower': m['borrower_name'] as String? ?? 'Unknown',
      'daysRemaining': null,
      'createdAt': createdAt?.millisecondsSinceEpoch,
      'dueDate': dueDate?.millisecondsSinceEpoch,
      'returnedAt': returnDate?.millisecondsSinceEpoch,
      'note': m['notes'] as String?,
      'contact': m['borrower_contact_id'] as String?,
      'imagePath': null,
      'imageUrl': m['photo_url'] as String?,
      'ownerId': m['user_id'] as String?,
      'status': status,
    });
  }
}
