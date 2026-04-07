import 'package:flutter_test/flutter_test.dart';
import 'package:invoice_discounting_app/services/api_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('UnauthorizedException', () {
    test('has default message', () {
      const ex = UnauthorizedException();
      expect(ex.message, 'Session expired. Please log in again.');
      expect(ex.toString(), 'Session expired. Please log in again.');
    });

    test('supports custom message', () {
      const ex = UnauthorizedException('Custom error');
      expect(ex.message, 'Custom error');
      expect(ex.toString(), 'Custom error');
    });
  });

  group('InvoicePage', () {
    test('empty constructor creates empty page', () {
      const page = InvoicePage.empty();
      expect(page.items, isEmpty);
      expect(page.nextCursor, isNull);
      expect(page.hasMore, isFalse);
      expect(page.isFromCache, isFalse);
    });

    test('hasMore returns true when nextCursor is not null', () {
      const page = InvoicePage(
        items: [{'id': 1}],
        nextCursor: 'abc123',
      );
      expect(page.hasMore, isTrue);
      expect(page.items.length, 1);
    });

    test('hasMore returns false when nextCursor is null', () {
      const page = InvoicePage(
        items: [{'id': 1}],
        nextCursor: null,
      );
      expect(page.hasMore, isFalse);
    });

    test('isFromCache defaults to false', () {
      const page = InvoicePage(
        items: [],
        nextCursor: null,
      );
      expect(page.isFromCache, isFalse);
    });

    test('isFromCache can be set to true', () {
      const page = InvoicePage(
        items: [],
        nextCursor: null,
        isFromCache: true,
      );
      expect(page.isFromCache, isTrue);
    });
  });

  group('ApiService', () {
    test('baseUrl is constructed from AppConfig', () {
      // Verify the static field exists and is a valid URL path
      expect(ApiService.baseUrl, contains('/api'));
    });
  });
}
