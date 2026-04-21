# Finworks360 — Invoice Discounting Platform

A production-grade Flutter app for invoice discounting and investment management. Built for investors to discover, track, and manage invoice-backed investments.

---

## Screens

### Authentication
| Screen | File |
|--------|------|
| Login | `login_screen.dart` |
| Register | `register_screen.dart` |
| Forgot Password | `forgot_password_screen.dart` |
| OTP Verification | `verify_otp_screen.dart` |
| Biometric Unlock | `unlock_screen.dart` |

### Core App
| Screen | File |
|--------|------|
| Home / Dashboard | `home_screen.dart` |
| Marketplace | `marketplace_screen.dart` |
| Invoice Detail | `invoice_detail_screen.dart` |
| Secondary Market | `secondary_market_screen.dart` |
| Portfolio | `portfolio_screen.dart` |
| Analytics | `analytics_screen.dart` |
| Investment Calculator | `investment_calculator.dart` |

### Payments & Wallet
| Screen | File |
|--------|------|
| E-Collect | `e_collect_screen.dart` |
| Withdraw Request | `withdraw_request_screen.dart` |
| Transaction History | `transaction_history_screen.dart` |
| Payment Status | `payment_status_screen.dart` |
| Receivable Statement | `receivable_statement_screen.dart` |

### Profile & Account
| Screen | File |
|--------|------|
| Profile | `profile/profile_screen.dart` |
| Basic Information | `basic_information_screen.dart` |
| Personal Details | `personal_details_screen.dart` |
| Account Details | `account_details_screen.dart` |
| Change Password | `change_password_screen.dart` |
| Bank Accounts | `bank_accounts_screen.dart` |
| Bank Account Detail | `bank_account_detail_screen.dart` |
| Add Bank Account | `add_bank_account_screen.dart` |
| Nominee | `nominee_screen.dart` |
| Add Nominee | `add_nominee_screen.dart` |
| Security Shield (2FA) | `profile/shield_screen.dart` |
| Settings | `settings_screen.dart` |
| Notification Center | `notification_center_screen.dart` |
| Profile WebView | `profile_webview_screen.dart` |

---

## Architecture

```
lib/
├── config.dart              # Environment config (API base URL, etc.)
├── main.dart                # App entry point
├── models/                  # Data models (Freezed + JsonSerializable)
├── providers/               # Shared Riverpod providers
├── screens/                 # All screen-level widgets
│   └── profile/             # Profile sub-screens and sheets
├── security/                # Biometric auth and app lock logic
├── services/                # API and data layer
│   ├── api_client.dart      # Core HTTP client (JWT refresh, error handling)
│   ├── api_service.dart     # Backward-compatible API facade
│   ├── auth_api_service.dart
│   ├── portfolio_api_service.dart
│   ├── portfolio_cache.dart
│   ├── e_collect_api_service.dart
│   ├── secondary_market_api_service.dart
│   ├── profile_api_service.dart
│   ├── notification_api_service.dart
│   ├── notification_service.dart
│   ├── cashfree_service.dart
│   ├── pdf_service.dart
│   ├── status_service.dart
│   ├── cache_service.dart          # Hive-based SWR cache
│   └── secure_storage_service.dart # JWT token storage
├── theme/                   # AppColors, ThemeProvider, typography constants
├── utils/                   # Formatters, haptics, route helpers
├── view_models/             # Riverpod ViewModels (Freezed state)
└── widgets/                 # Reusable UI components
```

### State Management

- **Riverpod** with `@riverpod` code-gen and `freezed` state classes
- Async state via `AsyncNotifier` patterns (analytics, marketplace)

### Networking

- Domain-split API services sharing a common `ApiClient`
- Automatic JWT refresh on 401/403 with de-duplicated concurrent refresh
- Stale-while-revalidate caching via Hive for instant-on loading

### Security

- JWT tokens stored in **flutter_secure_storage** (Android Keystore / iOS Keychain)
- Biometric re-auth uses refresh tokens — passwords never stored locally
- TOTP 2FA ("Security Shield") with server-provisioned QR secrets
- Jailbreak / root detection at launch
- Screenshot / screen recording protection via screen protector

---

## Getting Started

### Prerequisites

- Flutter SDK ≥ 3.0.0
- Dart SDK ≥ 3.0.0
- Android Studio or Xcode
- A running backend API (configure base URL in `lib/config.dart`)

### Setup

```bash
# Clone the repository
git clone <repo-url>
cd Invoice-Discounting-App-Flutter

# Install dependencies
flutter pub get

# Generate Freezed / Riverpod / JsonSerializable code
dart run build_runner build --delete-conflicting-outputs

# Run on a connected device or emulator
flutter run
```

### Build

```bash
# Debug APK
flutter build apk

# Release APK
flutter build apk --release

# iOS (requires Mac + Xcode)
flutter build ipa --release
```

---

## Tech Stack

| Category | Library |
|----------|---------|
| Framework | Flutter 3.x / Dart 3.x |
| State Management | flutter_riverpod, riverpod_annotation, freezed |
| Networking | dio, http |
| Local Cache | hive, hive_flutter |
| Secure Storage | flutter_secure_storage |
| Biometrics | local_auth |
| Payments | razorpay_flutter, flutter_cashfree_pg_sdk |
| Push Notifications | firebase_messaging, flutter_local_notifications |
| Charts | fl_chart |
| PDF Export | pdf, printing |
| AI | google_generative_ai |
| Animations | lottie, animations, shimmer, loading_animation_widget |
| Theming | dynamic_color, google_fonts |
| Images | cached_network_image, image_picker, image_cropper |
| Security | jailbreak_root_detection, screen_protector |
| WebView | webview_flutter |
| Other | url_launcher, file_picker, flutter_svg, haptic_feedback, home_widget |

---

## Testing

```bash
# Run all tests
flutter test

# Run with coverage
flutter test --coverage

# Static analysis
flutter analyze
```

---

## License

Proprietary — All rights reserved.
