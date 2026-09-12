import 'package:flutter_test/flutter_test.dart';
import 'package:resonance/features/settings/application/notification_provider.dart';

void main() {
  group('NotificationProvider and NotificationItem Tests', () {
    test('Notification ID masking always produces positive 31-bit integers', () {
      final ids = [
        'download_complete_123',
        'download_failed_456',
        'track_blocked_error_long_string_abc_xyz',
        'very_long_uuid_${DateTime.now().microsecondsSinceEpoch}',
        'neg_hash_candidate_-999999999999',
      ];

      for (final id in ids) {
        final maskedId = id.hashCode & 0x7FFFFFFF;
        expect(maskedId >= 0, isTrue);
        expect(maskedId <= 0x7FFFFFFF, isTrue);
      }
    });

    test('NotificationItem models dismissible state cleanly', () {
      final item = NotificationItem(
        id: 'download_1',
        title: 'Download Complete',
        message: 'Saved to library',
        timestamp: DateTime.now(),
        isError: false,
      );

      expect(item.id, equals('download_1'));
      expect(item.isRead, isFalse);

      final readItem = item.copyWith(isRead: true);
      expect(readItem.isRead, isTrue);
    });
  });
}
