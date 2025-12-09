import 'package:flutter_test/flutter_test.dart';
import 'package:pinjam_in/services/admin_service.dart';

void main() {
  test('deleteItem returns true when RPC returns non-empty list', () async {
    var calls = 0;
    Future<dynamic> fakeRpc(String name, {Map<String, dynamic>? params}) async {
      // Allow getItemDetails to be called first; return minimal item details
      if (name == 'admin_get_item_details') {
        return [
          {'id': params?['p_item_id'], 'photo_url': null},
        ];
      }
      expect(name, 'admin_delete_item');
      calls++;
      return [
        {'deleted': true},
      ];
    }

    final svc = AdminService(null, fakeRpc, null);
    final ok = await svc.deleteItem('item-1', hardDelete: true);
    expect(ok, isTrue);
    expect(calls, 1);
  });

  test('deleteItem retries when RPC fails then succeeds', () async {
    var calls = 0;
    Future<dynamic> flakyRpc(
      String name, {
      Map<String, dynamic>? params,
    }) async {
      // Ensure getItemDetails succeeds deterministically
      if (name == 'admin_get_item_details') {
        return [
          {'id': params?['p_item_id'], 'photo_url': null},
        ];
      }
      calls++;
      if (calls == 1) throw Exception('transient');
      return [
        {'deleted': true},
      ];
    }

    final svc = AdminService(null, flakyRpc, null);
    final ok = await svc.deleteItem('item-2', hardDelete: false);
    expect(ok, isTrue);
    expect(calls, greaterThanOrEqualTo(2));
  });
}
