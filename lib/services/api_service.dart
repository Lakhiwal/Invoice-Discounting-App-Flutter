// ═══════════════════════════════════════════════════════════════════════════════
// ApiService — Backward-compatible FACADE
// ═══════════════════════════════════════════════════════════════════════════════
//
// This file now delegates to domain-specific services:
//   • ApiClient       — Core HTTP plumbing (token management, auto-refresh)
//   • AuthApiService  — Login, Register, OTP, Password, 2FA
//   • PortfolioApiService — Portfolio, Invoices, Investments
//   • ECollectApiService    — E-Collect Account, Payments
//   • ProfileApiService   — Profile, Bank Accounts, Nominee
//   • NotificationApiService — FCM, Quiet Hours
//
// ALL existing call sites (ApiService.login(), ApiService.getPortfolio(), etc.)
// continue to work unchanged. Migrate callers at your own pace.
// ═══════════════════════════════════════════════════════════════════════════════

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:invoice_discounting_app/services/api_client.dart';
import 'package:invoice_discounting_app/services/auth_api_service.dart';
import 'package:invoice_discounting_app/services/e_collect_api_service.dart';
import 'package:invoice_discounting_app/services/notification_api_service.dart';
import 'package:invoice_discounting_app/services/portfolio_api_service.dart';
import 'package:invoice_discounting_app/services/profile_api_service.dart';

// Re-export so existing `import 'api_service.dart'` still finds these types
export 'api_client.dart' show UnauthorizedException;
export 'portfolio_api_service.dart' show InvoicePage;

class ApiService {
  static String get baseUrl => ApiClient.baseUrl;

  // ═══════════════════════════════════════════════════════════════════════════
  // AUTH
  // ═══════════════════════════════════════════════════════════════════════════

  static Future<Map<String, dynamic>> check2FAStatus(String email) =>
      AuthApiService.check2FAStatus(email);

  static Future<Map<String, dynamic>> login(String email, String password) =>
      AuthApiService.login(email, password);

  static Future<Map<String, dynamic>> register({
    required String name,
    required String email,
    required String mobile,
    required String panNumber,
    required String password,
    required String userType,
  }) =>
      AuthApiService.register(
        name: name,
        email: email,
        mobile: mobile,
        panNumber: panNumber,
        password: password,
        userType: userType,
      );

  static Future<Map<String, dynamic>> verifyEmailOtp({
    required String email,
    required String otp,
  }) =>
      AuthApiService.verifyEmailOtp(email: email, otp: otp);

  static Future<Map<String, dynamic>> resendOtp({required String email}) =>
      AuthApiService.resendOtp(email: email);

  static Future<Map<String, dynamic>> forgotPassword({required String email}) =>
      AuthApiService.forgotPassword(email: email);

  static Future<Map<String, dynamic>> resetPassword({
    required String email,
    required String otp,
    required String newPassword,
  }) =>
      AuthApiService.resetPassword(
        email: email,
        otp: otp,
        newPassword: newPassword,
      );

  static Future<Map<String, dynamic>> changePassword(
    String currentPassword,
    String newPassword,
  ) =>
      AuthApiService.changePassword(currentPassword, newPassword);

  static Future<Map<String, dynamic>> get2FAStatus() =>
      AuthApiService.get2FAStatus();

  static Future<Map<String, dynamic>> setup2FA() => AuthApiService.setup2FA();

  static Future<Map<String, dynamic>> activate2FA(String token) =>
      AuthApiService.activate2FA(token);

  static Future<Map<String, dynamic>> disable2FA(String token) =>
      AuthApiService.disable2FA(token);

  static Future<Map<String, dynamic>> verify2FALogin(
    String preAuthToken,
    String token,
  ) =>
      AuthApiService.verify2FALogin(preAuthToken, token);

  static Future<void> logout() => AuthApiService.logout();

  static Future<bool> isLoggedIn() => AuthApiService.isLoggedIn();

  static Future<bool> refreshWithStoredToken() =>
      AuthApiService.refreshWithStoredToken();

  static Future<Map<String, dynamic>> createWebviewToken() =>
      AuthApiService.createWebviewToken();

  // ═══════════════════════════════════════════════════════════════════════════
  // PORTFOLIO / INVOICES / INVEST
  // ═══════════════════════════════════════════════════════════════════════════

  static Future<Map<String, dynamic>?> getPortfolio({
    bool forceRefresh = false,
    int page = 1,
    int limit = 20,
    String type = 'all',
    bool? isSecondary,
  }) =>
      PortfolioApiService.getPortfolio(
        forceRefresh: forceRefresh,
        page: page,
        limit: limit,
        type: type,
        isSecondary: isSecondary,
      );

  static Future<Map<String, dynamic>?> getReceivableStatement({
    String? asOnDate,
    bool forceRefresh = false,
  }) =>
      PortfolioApiService.getReceivableStatement(
        asOnDate: asOnDate,
        forceRefresh: forceRefresh,
      );

  static Future<InvoicePage> getInvoicesCursor({
    String? afterCursor,
    int limit = 50,
    bool forceRefresh = false,
  }) =>
      PortfolioApiService.getInvoicesCursor(
        afterCursor: afterCursor,
        limit: limit,
        forceRefresh: forceRefresh,
      );

  static Future<List<dynamic>> getInvoices({
    int page = 1,
    int limit = 50,
    bool forceRefresh = false,
    String? status,
    bool unfundedOnly = false,
  }) =>
      PortfolioApiService.getInvoices(
        page: page,
        limit: limit,
        forceRefresh: forceRefresh,
        status: status,
        unfundedOnly: unfundedOnly,
      );

  static Future<Map<String, dynamic>?> getInvoiceDetail(int id) =>
      PortfolioApiService.getInvoiceDetail(id);

  static Future<Map<String, dynamic>> invest(int invoiceId, double amount) =>
      PortfolioApiService.invest(invoiceId, amount);

  static Future<Map<String, dynamic>?> calculateInvestment(
    int invoiceId,
    double amount,
  ) =>
      PortfolioApiService.calculateInvestment(invoiceId, amount);

  // ═══════════════════════════════════════════════════════════════════════════
  // E-COLLECT / PAYMENTS
  // ═══════════════════════════════════════════════════════════════════════════

  static Future<Map<String, dynamic>?> getWallet({bool forceRefresh = false}) =>
      ECollectApiService.getWallet(forceRefresh: forceRefresh);

  static Future<void> addFunds(double amount, String paymentMethod) =>
      ECollectApiService.addFunds(amount, paymentMethod);

  static Future<void> withdrawFunds(double amount) =>
      ECollectApiService.withdrawFunds(amount);

  static Future<Map<String, dynamic>> getWalletHistory({
    bool forceRefresh = false,
  }) =>
      ECollectApiService.getWalletHistory(forceRefresh: forceRefresh);

  static Future<Map<String, dynamic>> createCashfreeOrder(double amount) =>
      ECollectApiService.createCashfreeOrder(amount);

  static Future<Map<String, dynamic>> verifyCashfreePayment({
    required String orderId,
  }) =>
      ECollectApiService.verifyCashfreePayment(orderId: orderId);

  static Future<Map<String, dynamic>> createRazorpayOrder(double amount) =>
      ECollectApiService.createRazorpayOrder(amount);

  static Future<Map<String, dynamic>> verifyPayment({
    required String paymentId,
    required String orderId,
    required String signature,
  }) =>
      ECollectApiService.verifyPayment(
        paymentId: paymentId,
        orderId: orderId,
        signature: signature,
      );

  // ═══════════════════════════════════════════════════════════════════════════
  // PROFILE / BANK / NOMINEE
  // ═══════════════════════════════════════════════════════════════════════════

  static Future<Map<String, dynamic>?> getProfile({
    bool forceRefresh = false,
  }) =>
      ProfileApiService.getProfile(forceRefresh: forceRefresh);

  static Future<Map<String, dynamic>> updateBasicInfo({
    required String dob,
    required String gender,
  }) =>
      ProfileApiService.updateBasicInfo(
        dob: dob,
        gender: gender,
      );

  static Future<Map<String, dynamic>?> getCachedUser() =>
      ProfileApiService.getCachedUser();

  static Future<Map<String, dynamic>> uploadProfilePicture(File imageFile) =>
      ProfileApiService.uploadProfilePicture(imageFile);

  static Future<Map<String, dynamic>> deleteProfilePicture() =>
      ProfileApiService.deleteProfilePicture();

  static Future<List<Map<String, dynamic>>> getBankAccounts({
    bool forceRefresh = false,
  }) =>
      ProfileApiService.getBankAccounts(forceRefresh: forceRefresh);

  static Future<Map<String, dynamic>> addBankAccount({
    required String bankName,
    required String accountNumber,
    required String ifscCode,
    required String beneficiaryName,
    required String branchAddress,
    bool isPrimary = false,
  }) =>
      ProfileApiService.addBankAccount(
        bankName: bankName,
        accountNumber: accountNumber,
        ifscCode: ifscCode,
        beneficiaryName: beneficiaryName,
        branchAddress: branchAddress,
        isPrimary: isPrimary,
      );

  static Future<Map<String, dynamic>> setPrimaryBankAccount(int accountId) =>
      ProfileApiService.setPrimaryBankAccount(accountId);

  static Future<Map<String, dynamic>> deleteBankAccount(int accountId) =>
      ProfileApiService.deleteBankAccount(accountId);

  static Future<Map<String, dynamic>?> getNominee({
    bool forceRefresh = false,
  }) =>
      ProfileApiService.getNominee(forceRefresh: forceRefresh);

  static Future<Map<String, dynamic>> saveNominee({
    required String name,
    required int age,
    required String gender,
    required String relationship,
    String guardianName = '',
    String address = '',
  }) =>
      ProfileApiService.saveNominee(
        name: name,
        age: age,
        gender: gender,
        relationship: relationship,
        guardianName: guardianName,
        address: address,
      );

  // ═══════════════════════════════════════════════════════════════════════════
  // NOTIFICATIONS
  // ═══════════════════════════════════════════════════════════════════════════

  static Future<void> registerFcmToken(String token) =>
      NotificationApiService.registerFcmToken(token);

  static Future<void> updateQuietHours(TimeOfDay? start, TimeOfDay? end) =>
      NotificationApiService.updateQuietHours(start, end);
}
