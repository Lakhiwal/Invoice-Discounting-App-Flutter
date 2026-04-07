import 'dart:async';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:local_auth/local_auth.dart';
import '../services/api_service.dart';
import '../services/secure_storage_service.dart';
import '../utils/app_haptics.dart';

part 'auth_provider.g.dart';

enum AuthStatus { initial, loading, authenticated, needs2FA, error }

class AuthState {
  final AuthStatus status;
  final String? errorMessage;
  final bool isBiometricAvailable;
  final String? preAuthToken;

  AuthState({
    this.status = AuthStatus.initial,
    this.errorMessage,
    this.isBiometricAvailable = false,
    this.preAuthToken,
  });

  AuthState copyWith({
    AuthStatus? status,
    String? errorMessage,
    bool? isBiometricAvailable,
    String? preAuthToken,
  }) {
    return AuthState(
      status: status ?? this.status,
      errorMessage: errorMessage ?? this.errorMessage,
      isBiometricAvailable: isBiometricAvailable ?? this.isBiometricAvailable,
      preAuthToken: preAuthToken ?? this.preAuthToken,
    );
  }
}

@riverpod
class Auth extends _$Auth {
  final _localAuth = LocalAuthentication();

  @override
  FutureOr<AuthState> build() async {
    final initial = AuthState();
    return _checkBiometrics(initial);
  }

  Future<AuthState> _checkBiometrics(AuthState current) async {
    try {
      final canCheck = await _localAuth.canCheckBiometrics;
      final isSupported = await _localAuth.isDeviceSupported();
      final creds = await SecureStorageService.getCredentials();
      final hasSaved = creds['email'] != null && creds['refreshToken'] != null;
      
      return current.copyWith(
        isBiometricAvailable: (canCheck || isSupported) && hasSaved,
      );
    } catch (_) {
      return current.copyWith(isBiometricAvailable: false);
    }
  }

  Future<void> login(String email, String password) async {
    final previousState = state.value ?? AuthState();
    state = AsyncData(previousState.copyWith(status: AuthStatus.loading, errorMessage: null));

    try {
      final result = await ApiService.login(email, password);
      
      if (result['success'] == true) {
        if (result['2fa_required'] == true) {
          state = AsyncData(previousState.copyWith(
            status: AuthStatus.needs2FA,
            preAuthToken: result['pre_auth_token'],
          ));
        } else {
          await SecureStorageService.saveCredentials(
            email: email, 
            refreshToken: result['refresh']
          );
          state = AsyncData(previousState.copyWith(status: AuthStatus.authenticated));
        }
      } else {
        state = AsyncData(previousState.copyWith(
          status: AuthStatus.error,
          errorMessage: result['error'] ?? 'Invalid credentials',
        ));
      }
    } catch (e) {
      state = AsyncData(previousState.copyWith(
        status: AuthStatus.error,
        errorMessage: 'Connection failed. Please check your internet.',
      ));
    }
  }

  Future<void> verify2FA(String otp) async {
    final previousState = state.value ?? AuthState();
    if (previousState.preAuthToken == null) return;

    state = AsyncData(previousState.copyWith(status: AuthStatus.loading, errorMessage: null));

    try {
      final result = await ApiService.verify2FALogin(previousState.preAuthToken!, otp);
      
      if (result['success'] == true) {
        await SecureStorageService.saveCredentials(email: '', refreshToken: result['refresh']); 
        state = AsyncData(previousState.copyWith(status: AuthStatus.authenticated));
      } else {
        await AppHaptics.error();
        state = AsyncData(previousState.copyWith(
          status: AuthStatus.error,
          errorMessage: result['error'] ?? 'Invalid security code',
        ));
      }
    } catch (e) {
      state = AsyncData(previousState.copyWith(
        status: AuthStatus.error,
        errorMessage: 'Verification failed. Try again.',
      ));
    }
  }

  Future<void> biometricLogin() async {
    final previousState = state.value ?? AuthState();
    
    try {
      final authenticated = await _localAuth.authenticate(
        localizedReason: 'Authenticate to access Finworks360',
        biometricOnly: true,
      );

      if (authenticated) {
        state = AsyncData(previousState.copyWith(status: AuthStatus.loading));
        
        final creds = await SecureStorageService.getCredentials();
        final email = creds['email'];
        final refreshToken = creds['refreshToken'];

        if (email != null && refreshToken != null) {
          final check2FAResult = await ApiService.check2FAStatus(email);
          
          if (check2FAResult['requires_2fa'] == true) {
            state = AsyncData(previousState.copyWith(
              status: AuthStatus.needs2FA,
              preAuthToken: check2FAResult['pre_token'] ?? refreshToken,
            ));
          } else {
            state = AsyncData(previousState.copyWith(status: AuthStatus.authenticated));
          }
        } else {
          state = AsyncData(previousState.copyWith(
            status: AuthStatus.error,
            errorMessage: 'Biometric data no longer valid. Please login with password.',
          ));
        }
      }
    } catch (e) {
      state = AsyncData(previousState.copyWith(
        status: AuthStatus.error,
        errorMessage: 'Biometric authentication failed.',
      ));
    }
  }

  void logout() async {
    await SecureStorageService.clearCredentials();
    state = AsyncData(AuthState());
  }

  void resetStatus() {
    state = AsyncData(AuthState(isBiometricAvailable: state.value?.isBiometricAvailable ?? false));
  }
}
