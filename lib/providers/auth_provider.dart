import 'dart:async';
import 'package:flutter/foundation.dart';

import 'package:invoice_discounting_app/services/api_service.dart';
import 'package:invoice_discounting_app/services/secure_storage_service.dart';
import 'package:invoice_discounting_app/utils/app_haptics.dart';
import 'package:invoice_discounting_app/view_models/marketplace_view_model.dart';
import 'package:local_auth/local_auth.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'auth_provider.g.dart';

enum AuthStatus { initial, loading, authenticated, needs2FA, error }

class AuthState {
  AuthState({
    this.status = AuthStatus.initial,
    this.errorMessage,
    this.isBiometricAvailable = false,
    this.preAuthToken,
  });
  final AuthStatus status;
  final String? errorMessage;
  final bool isBiometricAvailable;
  final String? preAuthToken;

  AuthState copyWith({
    AuthStatus? status,
    String? errorMessage,
    bool? isBiometricAvailable,
    String? preAuthToken,
  }) =>
      AuthState(
        status: status ?? this.status,
        errorMessage: errorMessage ?? this.errorMessage,
        isBiometricAvailable: isBiometricAvailable ?? this.isBiometricAvailable,
        preAuthToken: preAuthToken ?? this.preAuthToken,
      );
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
    state = AsyncData(
      previousState.copyWith(status: AuthStatus.loading),
    );

    try {
      final result = await ApiService.login(email, password);

      if (result['success'] == true) {
        if (result['2fa_required'] == true) {
          state = AsyncData(
            previousState.copyWith(
              status: AuthStatus.needs2FA,
              preAuthToken: result['pre_auth_token'] as String?,
            ),
          );
        } else {
          await SecureStorageService.saveCredentials(
            email: email,
            refreshToken: result['refresh'] as String,
          );
          state = AsyncData(
            previousState.copyWith(status: AuthStatus.authenticated),
          );
        }
      } else {
        state = AsyncData(
          previousState.copyWith(
            status: AuthStatus.error,
            errorMessage: (result['error'] as String?) ?? 'Invalid credentials',
          ),
        );
      }
    } catch (e) {
      state = AsyncData(
        previousState.copyWith(
          status: AuthStatus.error,
          errorMessage: 'Connection failed. Please check your internet.',
        ),
      );
    }
  }

  Future<void> verify2FA(String otp) async {
    final previousState = state.value ?? AuthState();
    if (previousState.preAuthToken == null) return;

    state = AsyncData(
      previousState.copyWith(status: AuthStatus.loading),
    );

    try {
      final result =
          await ApiService.verify2FALogin(previousState.preAuthToken!, otp);

      if (result['success'] == true) {
        await SecureStorageService.saveCredentials(
          email: '',
          refreshToken: result['refresh'] as String,
        );
        state =
            AsyncData(previousState.copyWith(status: AuthStatus.authenticated));
      } else {
        await AppHaptics.error();
        state = AsyncData(
          previousState.copyWith(
            status: AuthStatus.error,
            errorMessage:
                (result['error'] as String?) ?? 'Invalid security code',
          ),
        );
      }
    } catch (e) {
      state = AsyncData(
        previousState.copyWith(
          status: AuthStatus.error,
          errorMessage: 'Verification failed. Try again.',
        ),
      );
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
            state = AsyncData(
              previousState.copyWith(
                status: AuthStatus.needs2FA,
                preAuthToken:
                    (check2FAResult['pre_token'] as String?) ?? refreshToken,
              ),
            );
          } else {
            state = AsyncData(
              previousState.copyWith(status: AuthStatus.authenticated),
            );
          }
        } else {
          state = AsyncData(
            previousState.copyWith(
              status: AuthStatus.error,
              errorMessage:
                  'Biometric data no longer valid. Please login with password.',
            ),
          );
        }
      }
    } catch (e) {
      state = AsyncData(
        previousState.copyWith(
          status: AuthStatus.error,
          errorMessage: 'Biometric authentication failed.',
        ),
      );
    }
  }

  Future<void> logout() async {
    // 1. Backend + Global Service Cleanup (SecureStorage, Caches, etc.)
    await ApiService.logout()
        .catchError((Object e) => debugPrint('Logout error: $e'));

    // 2. State Provider Invalidation
    // We must manually invalidate keepAlive providers so they reset to initialState
    ref.invalidate(marketplaceProvider);

    // 3. Reset local auth state
    state = AsyncData(AuthState());
  }

  void resetStatus() {
    state = AsyncData(
      AuthState(
        isBiometricAvailable: state.value?.isBiometricAvailable ?? false,
      ),
    );
  }
}
