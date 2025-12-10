import 'package:flutter_test/flutter_test.dart';
import 'package:pinjam_in/services/admin_service.dart';
import 'package:pinjam_in/services/service_exception.dart';

void main() {
  test('getDashboardStats returns map when RPC returns list', () async {
    Future<dynamic> fakeRpc(String name, {Map<String, dynamic>? params}) async {
      expect(name, 'admin_get_dashboard_stats');
      return [
        {'total_users': 10, 'total_items': 5},
      ];
    }

    final svc = AdminService(null, fakeRpc, null);
    final res = await svc.getDashboardStats();
    expect(res, isNotNull);
    expect(res!['total_users'], 10);
  });

  test('getAllUsers returns list', () async {
    Future<dynamic> fakeRpc(String name, {Map<String, dynamic>? params}) async {
      expect(name, 'admin_get_all_users');
      return [
        {'id': 'u1'},
        {'id': 'u2'},
      ];
    }

    final svc = AdminService(null, fakeRpc, null);
    final lst = await svc.getAllUsers(limit: 2);
    expect(lst, hasLength(2));
  });

  test('getUserDetails returns first row as map', () async {
    Future<dynamic> fakeRpc(String name, {Map<String, dynamic>? params}) async {
      expect(name, 'admin_get_user_details');
      expect(params?['p_user_id'], 'u123');
      return [
        {'id': 'u123', 'full_name': 'Alice'},
      ];
    }

    final svc = AdminService(null, fakeRpc, null);
    final res = await svc.getUserDetails('u123');
    expect(res, isNotNull);
    expect(res!['full_name'], 'Alice');
  });

  test('createUser uses function invoker and returns map', () async {
    Future<dynamic> fakeFn(String name, {dynamic body}) async {
      expect(name, 'admin_create_user');
      return {
        'status': 200,
        'data': {'id': 'u-new', 'email': body['email']},
      };
    }

    final svc = AdminService(null, null, fakeFn);
    final res = await svc.createUser({'email': 'a@b.com'});
    expect(res['id'], 'u-new');
    expect(res['email'], 'a@b.com');
  });

  test('updateUser calls profile rpc when full_name present', () async {
    Future<dynamic> fakeRpc(String name, {Map<String, dynamic>? params}) async {
      expect(name, 'admin_update_user_profile');
      return [
        {'id': params?['p_user_id'], 'full_name': params?['p_full_name']},
      ];
    }

    final svc = AdminService(null, fakeRpc, null);
    final res = await svc.updateUser('u1', {'full_name': 'Bob'});
    expect(res['full_name'], 'Bob');
  });

  test('deleteUser returns true on rpc list response', () async {
    Future<dynamic> fakeRpc(String name, {Map<String, dynamic>? params}) async {
      expect(name, 'admin_delete_user');
      return [
        {'deleted': true},
      ];
    }

    final svc = AdminService(null, fakeRpc, null);
    final ok = await svc.deleteUser('u1', hardDelete: true);
    expect(ok, isTrue);
  });

  test('getAllItems returns list', () async {
    Future<dynamic> fakeRpc(String name, {Map<String, dynamic>? params}) async {
      expect(name, 'admin_get_all_items');
      return [
        {'id': 'i1'},
        {'id': 'i2'},
      ];
    }

    final svc = AdminService(null, fakeRpc, null);
    final items = await svc.getAllItems(limit: 2);
    expect(items, hasLength(2));
  });

  test(
    'getMostBorrowedItems falls back to getAllItems and uses p_user_filter',
    () async {
      bool topItemsCalled = false;
      Future<dynamic> fakeRpc(
        String name, {
        Map<String, dynamic>? params,
      }) async {
        if (name == 'admin_get_top_items') {
          topItemsCalled = true;
          throw Exception('rpc not found');
        }
        if (name == 'admin_get_all_items') {
          // ensure we pass p_user_filter not owner param
          expect(params?.containsKey('p_user_filter'), isTrue);
          return [
            {'name': 'Hammer', 'id': 'i1'},
            {'name': 'Hammer', 'id': 'i2'},
            {'name': 'Screwdriver', 'id': 'i3'},
          ];
        }
        throw Exception('unexpected rpc call: $name');
      }

      final svc = AdminService(null, fakeRpc, null);
      final res = await svc.getMostBorrowedItems(limit: 2);
      expect(topItemsCalled, isTrue);
      expect(res, isNotEmpty);
      expect(res.first['name'], 'Hammer');
    },
  );

  test('getItemGrowth fallback computes counts from items list', () async {
    Future<dynamic> fakeRpc(String name, {Map<String, dynamic>? params}) async {
      if (name == 'admin_get_item_growth') {
        throw Exception('rpc not found');
      }
      if (name == 'admin_get_all_items') {
        // return few items with created_at dates
        return [
          {'id': 'i1', 'created_at': DateTime.now().toIso8601String()},
          {
            'id': 'i2',
            'created_at': DateTime.now()
                .subtract(Duration(days: 1))
                .toIso8601String(),
          },
        ];
      }
      throw Exception('unexpected rpc call: $name');
    }

    final svc = AdminService(null, fakeRpc, null);
    final res = await svc.getItemGrowth(days: 2);
    expect(res, isNotEmpty);
    // Expect keys with date strings
    expect(res.first.containsKey('date'), isTrue);
    expect(res.first.containsKey('count'), isTrue);
  });

  test('getItemDetails returns first row', () async {
    Future<dynamic> fakeRpc(String name, {Map<String, dynamic>? params}) async {
      expect(name, 'admin_get_item_details');
      return [
        {'id': params?['p_item_id'], 'name': 'Gadget'},
      ];
    }

    final svc = AdminService(null, fakeRpc, null);
    final it = await svc.getItemDetails('i1');
    expect(it, isNotNull);
    expect(it!['name'], 'Gadget');
  });

  test('RPC errors are wrapped in ServiceException', () async {
    Future<dynamic> fakeRpc(String name, {Map<String, dynamic>? params}) async {
      throw Exception('boom');
    }

    final svc = AdminService(null, fakeRpc, null);
    expect(() => svc.getAllUsers(), throwsA(isA<ServiceException>()));
  });
}
