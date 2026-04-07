# Finworks360 — Invoice Discounting Platform

A premium, production-grade Flutter application for invoice discounting and investment management. Built with a focus on **security**, **performance**, and **institutional-grade UX**.

---

## ✨ Features

| Feature | Description |
|---------|-------------|
| 📊 **Portfolio Dashboard** | Real-time portfolio tracking with animated metrics and floating summary bar |
| 🏪 **Marketplace** | Cursor-paginated invoice marketplace with infinite scroll |
| 💰 **Wallet** | Integrated wallet with Cashfree & Razorpay payment gateways |
| 🔐 **Security Shield** | TOTP-based 2FA with QR provisioning and recovery codes |
| 🔒 **Biometric Auth** | Fingerprint / Face ID login with secure token storage |
| 📈 **Analytics** | Isolate-computed portfolio analytics with interactive charts |
| 🏦 **Bank Accounts** | Full CRUD for bank accounts with primary account management |
| 👤 **Profile Management** | Profile picture, personal details, nominee, KYC |
| 🔔 **Push Notifications** | Firebase Cloud Messaging with quiet hours |
| 🌙 **Theming** | Dynamic color (Material You), dark mode, and AMOLED black mode |
| 🎯 **120Hz** | Optimized for high refresh rate displays |

---

## 🏗️ Architecture

```
lib/
├── config.dart              # Environment configuration
├── main.dart                # App entry point
├── models/                  # Data models (Freezed + JsonSerializable)
├── providers/               # Riverpod providers
├── screens/                 # Screen-level widgets
│   └── profile/             # Profile sub-screens and sheets
├── security/                # Biometric auth, app lock
├── services/                # API and data layer
│   ├── api_client.dart      # Core HTTP client (token mgmt, auto-refresh)
│   ├── api_service.dart     # Backward-compatible facade
│   ├── auth_api_service.dart
│   ├── portfolio_api_service.dart
│   ├── wallet_api_service.dart
│   ├── profile_api_service.dart
│   ├── notification_api_service.dart
│   ├── cache_service.dart   # Hive-based SWR cache
│   └── secure_storage_service.dart
├── theme/                   # ThemeProvider, AppColors, UI constants
├── utils/                   # Formatters, haptics, smooth routes
├── view_models/             # Riverpod ViewModels (Freezed state)
└── widgets/                 # Reusable UI components
```

### State Management

- **Riverpod** (primary) — ViewModels use `@riverpod` code-gen with `freezed` state classes
- Async state is managed via `AsyncNotifier` patterns (analytics, marketplace)

### Networking

- Domain-specific API services extend a shared `ApiClient`
- Automatic JWT refresh on 401/403 with de-duplicated refresh calls
- Stale-while-revalidate caching via Hive for instant-on loading

### Security

- JWT tokens stored in **flutter_secure_storage** (Android Keystore / iOS Keychain)
- Biometric re-auth uses refresh tokens (never stores passwords)
- TOTP 2FA ("Security Shield") with server-provisioned secrets

---

## 🚀 Getting Started

### Prerequisites

- Flutter SDK ≥ 3.0.0
- Dart SDK ≥ 3.0.0
- Android Studio or Xcode
- A running backend API (see `lib/config.dart` for base URL)

### Setup

```bash
# Clone the repository
git clone https://github.com/your-org/finworks360.git
cd finworks360

# Install dependencies
flutter pub get

# Generate code (Freezed + Riverpod + JsonSerializable)
dart run build_runner build --delete-conflicting-outputs

# Run on connected device
flutter run
```

### Build Release APK

```bash
flutter build apk --release
```

---

## 🧪 Testing

```bash
# Run all tests
flutter test

# Run with coverage
flutter test --coverage

# Static analysis
flutter analyze
```

---

## 🛠️ Tech Stack

| Category | Technology |
|----------|-----------|
| Framework | Flutter 3.x |
| Language | Dart 3.x |
| State Management | Riverpod + Freezed |
| Networking | http, dio |
| Storage | Hive, SharedPreferences, FlutterSecureStorage |
| Auth | JWT + TOTP 2FA + Biometrics |
| Payments | Razorpay, Cashfree |
| Push Notifications | Firebase Cloud Messaging |
| Charts | fl_chart |
| Theming | Dynamic Color (Material You), Google Fonts |

---

## 📦 Project Structure

| Directory | Purpose |
|-----------|---------|
| `lib/services/` | API layer — domain-split services with shared HTTP client |
| `lib/view_models/` | Business logic — Riverpod notifiers with Freezed states |
| `lib/screens/` | UI screens — StatefulWidgets consuming ViewModels |
| `lib/widgets/` | Reusable components — Skeleton loaders, pressable cards, etc. |
| `lib/theme/` | Design system — colors, spacing, typography tokens |
| `test/` | Unit & widget tests |

---

## 📜 License

Proprietary — All rights reserved.
