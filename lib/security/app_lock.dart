import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

class AppLock {
  static final LocalAuthentication _auth = LocalAuthentication();

  static Future<bool> authenticate() async {
    try {
      final canCheck = await _auth.canCheckBiometrics;
      final supported = await _auth.isDeviceSupported();

      if (!canCheck && !supported) {
        return false;
      }

      final authenticated = await _auth.authenticate(
        localizedReason: 'Authenticate to unlock Finworks360',
        biometricOnly: false,
      );

      return authenticated;
    } on PlatformException {
      return false;
    }
  }
}