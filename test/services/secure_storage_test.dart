import 'package:flutter_test/flutter_test.dart';
import 'package:invoice_discounting_app/services/secure_storage_service.dart';

void main() {
  // flutter_secure_storage uses platform channels — set up mock
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SecureStorageService', () {
    // NOTE: These tests validate the API contract.
    // Full integration tests require a device/emulator since
    // FlutterSecureStorage uses Android Keystore / iOS Keychain.

    test('class exists and has expected static methods', () {
      // Verify the class compiles and all methods exist
      expect(SecureStorageService.saveTokens, isA<Function>());
      expect(SecureStorageService.saveAccessToken, isA<Function>());
      expect(SecureStorageService.getAccessToken, isA<Function>());
      expect(SecureStorageService.getRefreshToken, isA<Function>());
      expect(SecureStorageService.clearTokens, isA<Function>());
      expect(SecureStorageService.saveCredentials, isA<Function>());
      expect(SecureStorageService.getCredentials, isA<Function>());
      expect(SecureStorageService.clearCredentials, isA<Function>());
      expect(SecureStorageService.clearAll, isA<Function>());
    });
  });
}
