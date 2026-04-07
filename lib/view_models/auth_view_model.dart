import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';
import '../services/api_service.dart';
import '../services/secure_storage_service.dart';
import '../utils/app_haptics.dart';

// ── Riverpod provider ─────────────────────────────────────────────────────────
final authViewModelProvider =
    ChangeNotifierProvider<AuthViewModel>((ref) => AuthViewModel());

enum AuthStatus { initial, loading, authenticated, needs2FA, error }

class AuthViewModel extends ChangeNotifier {
  final _localAuth = LocalAuthentication();
  
  AuthStatus _status = AuthStatus.initial;
  AuthStatus get status => _status;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  bool _isBiometricAvailable = false;
  bool get isBiometricAvailable => _isBiometricAvailable;

  String? _preAuthToken; // Token for 2FA verification

  AuthViewModel() {
    checkBiometrics();
  }

  Future<void> checkBiometrics() async {
    try {
      final canCheck = await _localAuth.canCheckBiometrics;
      final isSupported = await _localAuth.isDeviceSupported();
      final creds = await SecureStorageService.getCredentials();
      final hasSaved = creds['email'] != null && creds['refreshToken'] != null;
      
      _isBiometricAvailable = (canCheck || isSupported) && hasSaved;
      notifyListeners();
    } catch (_) {
      _isBiometricAvailable = false;
      notifyListeners();
    }
  }

  Future<void> login(String email, String password) async {
    if (_status == AuthStatus.loading) return;

    _status = AuthStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      final result = await ApiService.login(email, password);
      
      if (result['success'] == true) {
        if (result['2fa_required'] == true) {
          _preAuthToken = result['pre_auth_token'];
          _status = AuthStatus.needs2FA;
        } else {
          // Normal login success
          await _saveCredentials(email, result['refresh']);
          _status = AuthStatus.authenticated;
        }
      } else {
        _errorMessage = result['error'] ?? 'Invalid credentials';
        _status = AuthStatus.error;
      }
    } catch (e) {
      _errorMessage = 'Connection failed. Please check your internet.';
      _status = AuthStatus.error;
    }
    
    notifyListeners();
  }

  Future<void> verify2FA(String otp) async {
    if (_status == AuthStatus.loading || _preAuthToken == null) return;

    _status = AuthStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      final result = await ApiService.verify2FALogin(_preAuthToken!, otp);
      
      if (result['success'] == true) {
        await _saveCredentials('', result['refresh']); 
        _status = AuthStatus.authenticated;
      } else {
        _errorMessage = result['error'] ?? 'Invalid security code';
        _status = AuthStatus.error;
        await AppHaptics.error();
      }
    } catch (e) {
      _errorMessage = 'Verification failed. Try again.';
      _status = AuthStatus.error;
    }
    
    notifyListeners();
  }

  Future<void> biometricLogin() async {
    if (_status == AuthStatus.loading) return;

    try {
      final authenticated = await _localAuth.authenticate(
        localizedReason: 'Authenticate to access Finworks360',
        biometricOnly: true,
      );

      if (authenticated) {
        _status = AuthStatus.loading;
        notifyListeners();
        
        final creds = await SecureStorageService.getCredentials();
        final email = creds['email'];
        final refreshToken = creds['refreshToken'];

        if (email != null && refreshToken != null) {
          // Verify with API if Shield/2FA is enabled for this email
          final check2FAResult = await ApiService.check2FAStatus(email);
          
          if (check2FAResult['requires_2fa'] == true) {
            _preAuthToken = check2FAResult['pre_token'] ?? refreshToken; 
            _status = AuthStatus.needs2FA;
          } else {
            _status = AuthStatus.authenticated;
          }
        } else {
          _errorMessage = 'Biometric data no longer valid. Please login with password.';
          _status = AuthStatus.error;
        }
      }
    } catch (e) {
      _errorMessage = 'Biometric authentication failed.';
      _status = AuthStatus.error;
    }
    
    notifyListeners();
  }

  Future<void> _saveCredentials(String email, String refreshToken) async {
    await SecureStorageService.saveCredentials(email: email, refreshToken: refreshToken);
  }

  void resetStatus() {
    _status = AuthStatus.initial;
    _errorMessage = null;
    _preAuthToken = null;
    notifyListeners();
  }
}
