import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pinjam_in/di/service_locator.dart';
import 'package:pinjam_in/models/loan_item.dart';
import 'package:pinjam_in/services/persistence_service.dart';
import 'package:pinjam_in/widgets/storage_image.dart';

class FakeNoUrlPersistence extends PersistenceService {
  @override
  Future<void> deleteItem(String itemId) async {}

  @override
  Future<void> invalidateCache({String? itemId}) async {}

  @override
  Future<String?> currentUserId() async => null;

  @override
  Future<List<LoanItem>> loadActive() async => <LoanItem>[];

  @override
  Future<List<LoanItem>> loadHistory() async => <LoanItem>[];

  @override
  Future<void> saveActive(List items) async {}

  @override
  Future<void> saveHistory(List items) async {}

  @override
  Future<String?> getPublicUrl(String path) async => null;
}

void main() {
  testWidgets(
    'StorageImage shows placeholder for relative path when persistence has no URL',
    (tester) async {
      final persistence = FakeNoUrlPersistence();
      ServiceLocator.setPersistenceService(persistence);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StorageImage(
              imageUrl: 'user1/photo1.jpg',
              persistence: persistence,
              width: 80,
              height: 80,
            ),
          ),
        ),
      );

      // Allow async signed URL attempts to finish
      await tester.pumpAndSettle();

      // Verify placeholder icon is present instead of a network image
      expect(find.byIcon(Icons.image_not_supported), findsOneWidget);
    },
  );
}
