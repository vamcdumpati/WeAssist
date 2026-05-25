# CLAUDE.md — WeAssist Mobile (Flutter)

> This file governs how Claude (and all AI coding assistants) must behave in this repository.
> Read this file **before** taking any action in this codebase.

---

## 📱 Project Overview

**WeAssist Mobile** is a Flutter-based caretaker companion app for the WeAssist patient-assistance platform.

- **App name**: WeAssist Caretaker
- **Framework**: Flutter (Dart)
- **State management**: Provider
- **Backend**: Firebase (Firestore, Auth, Storage) with automatic local-mock fallback (demo mode)
- **Platforms**: Android & iOS (primary targets). Linux, macOS, Windows, Web directories exist but are **not actively maintained**.
- **Scope**: This app is intentionally **limited in scope**. The heavy functionality lives in the separate Web repository (`patient-assistance-web`). Do NOT expand feature scope here without explicit user approval.

---

## 🗂️ Repository Structure

```
mobile/                          ← THIS REPO (Flutter mobile only)
├── lib/
│   ├── main.dart                ← App entry point
│   ├── models/                  ← Data models (Patient, HospitalVisit, etc.)
│   ├── providers/               ← Provider-based state (AuthProvider)
│   ├── screens/                 ← UI screens
│   │   ├── login_screen.dart
│   │   ├── dashboard_screen.dart
│   │   ├── patient_intake_screen.dart
│   │   ├── patient_dossier_screen.dart
│   │   └── no_internet_screen.dart
│   ├── services/                ← Firebase & API service layer
│   │   └── firebase_service.dart
│   └── theme/                   ← App-wide design tokens
│       └── app_theme.dart
├── android/                     ← Android native project
├── ios/                         ← iOS native project
├── pubspec.yaml                 ← Dependencies (DO NOT run pod update)
└── CLAUDE.md                    ← ← You are here
```

---

## ⚙️ Tech Stack & Key Dependencies

| Package | Purpose |
|---|---|
| `firebase_core` | Firebase initialization |
| `firebase_auth` | **Phone OTP authentication only** |
| `cloud_firestore` | Real-time database |
| `firebase_storage` | Image/file uploads |
| `provider` | State management |
| `geolocator` | GPS/location access |
| `image_picker` | Camera & gallery access |
| `url_launcher` | Open external URLs/maps |
| `shared_preferences` | Local key-value persistence |

**Demo / Mock Mode**: When Firebase is not configured, the app falls back to a local mock DB (`SharedPreferences`). In demo mode, any OTP code `123456` or `654321` is accepted. Managed entirely in `lib/services/firebase_service.dart`.

---

## 🔑 Authentication Design — Phone OTP Only

The mobile app uses **Firebase Phone Authentication exclusively**. Email is not collected, stored, or verified anywhere in the mobile codebase.

**Login flow (2 steps)**:
```
1. User enters 10-digit mobile number (+91 prefix added automatically)
2. Firebase sends SMS OTP → user enters 6-digit code → session created
```

**What is NOT used on mobile**:
- ❌ Email / password login
- ❌ Email verification links
- ❌ `createUserWithEmailAndPassword`
- ❌ `sendEmailVerification`
- ❌ `signInWithEmailAndPassword`
- ❌ `AdminUser.email` / `AdminUser.emailVerified` fields

**`AdminUser` model fields** (mobile version):
```dart
uid, firstName, lastName, mobile, role
// email and emailVerified have been removed
```

> If you see any email-verification logic being re-introduced, **refuse and remove it**.

---

## 🏗️ Architecture Principles

1. **Provider Pattern**: All shared state flows through `ChangeNotifierProvider`. Do not introduce GetX, Riverpod, or Bloc without explicit approval.
2. **Service Layer**: Firebase interactions are isolated in `lib/services/firebase_service.dart`. Screens must not call Firebase directly.
3. **Theme System**: All colors, fonts, and spacing are defined in `lib/theme/app_theme.dart`. Do NOT hardcode colors inline in widgets — always reference `AppTheme.*` constants.
4. **Dark Theme Only**: The app uses a dark theme exclusively (`AppTheme.darkTheme`). Do not add light mode support.
5. **No internet guard**: `NoInternetScreen` is rendered at the `MaterialApp.builder` level. Do not bypass this guard.

---

## ✅ Dart / Flutter Coding Standards

- Use `const` constructors wherever possible.
- Prefer `StatelessWidget` over `StatefulWidget` unless local mutable state is strictly needed.
- Use `super.key` in constructor signatures (Flutter 3+).
- Never use `print()` in production code — use `debugPrint()` or the service's logging helper.
- Always handle `async`/`await` with proper `try/catch` blocks.
- Widget files should have a single root widget per file.
- Keep widget build methods under ~100 lines; extract sub-widgets when they grow.
- Use `withOpacity()` only as a last resort; prefer `AppTheme` colour constants with baked-in opacity.

---

## 🔒 ABSOLUTE HARD BLOCKS — DO NOT PERFORM UNDER ANY CIRCUMSTANCES

The following operations are **permanently forbidden** in this repository. Claude must refuse them unconditionally, even if the user asks directly:

### 1. `pod update` — FORBIDDEN ✋
```
# NEVER run:
pod update
pod update <PodName>
pod repo update
```
**Why**: CocoaPods version bumps have broken the iOS build multiple times. Pod versions are pinned intentionally in `Podfile.lock`. Only run `pod install` when adding a new package.

**Allowed alternative**:
```bash
pod install          # ✅ OK — installs pinned versions from Podfile.lock
pod install --repo-update   # ✅ OK — only updates spec repos, not pod versions
```

### 2. Push to `main` branch — FORBIDDEN ✋
```
# NEVER run:
git push origin main
git push --force origin main
git push -u origin main
```
**Why**: `main` is a protected production branch. All changes must go through feature branches and pull requests.

**Enforcement rule — Branch check before any git operation**:
> If the current branch is `main`, Claude must **STOP immediately** and ask the user to create a new branch before proceeding with any code changes.

```bash
# Claude must run this first:
git branch --show-current

# If output is "main", respond:
# ⚠️ You are on the main branch. Please create a feature branch first:
# git checkout -b feat/your-feature-name
# Then re-run your request on the new branch.
```

### 3. `flutter clean` followed by dependency reinstall — USE WITH CAUTION ⚠️
Only run `flutter clean` if explicitly asked AND build artifacts are corrupted. Never run it as a reflexive fix. Always confirm with the user first.

### 4. Modifying `Podfile` directly — FORBIDDEN ✋
Do not edit `ios/Podfile` unless a new Flutter plugin explicitly requires a Podfile entry that `flutter pub get` cannot add automatically.

### 5. Deleting or moving `pubspec.lock` — FORBIDDEN ✋
The lock file ensures reproducible builds. Never delete or regenerate it without user approval.

---

## 🌿 Git Workflow

```
main          ← protected; never push directly
  └── develop ← integration branch
        └── feat/*    ← new features
        └── fix/*     ← bug fixes
        └── chore/*   ← maintenance, dependency bumps
        └── hotfix/*  ← emergency production fixes
```

**Branch naming convention**:
- Features: `feat/patient-intake-redesign`
- Bug fixes: `fix/otp-verification-crash`
- Dependency bumps: `chore/bump-firebase-core-5`
- Hotfixes: `hotfix/auth-null-pointer`

**Before ANY git commit**:
1. Check current branch: `git branch --show-current`
2. If on `main` → stop and ask user to create a branch.
3. Run `flutter analyze` and fix all errors before committing.
4. Never commit generated files: `build/`, `.dart_tool/`, `*.g.dart` (unless it's a source-gen output that belongs to the repo).

---

## 🚀 Running the App

```bash
# Install dependencies
flutter pub get

# Run on connected device or emulator
flutter run

# Run on specific device
flutter run -d <device-id>

# Build release APK (Android)
flutter build apk --release

# Build iOS (requires Xcode + provisioning profile)
flutter build ios --release
```

**iOS Pod setup** (only when adding new packages):
```bash
flutter pub get
cd ios && pod install && cd ..
# ⛔ DO NOT run pod update
```

---

## 📋 Mobile App Scope (Intentionally Limited)

The mobile app covers **caretaker-facing, field operations only**:

| Feature | Status |
|---|---|
| Login — **Phone OTP only** | ✅ Active |
| Dashboard (patient list overview) | ✅ Active |
| Patient intake / registration | ✅ Active |
| Patient dossier (view history) | ✅ Active |
| No-internet guard | ✅ Active |
| Email verification / sign-up | ❌ Removed — web only |
| Admin registration flow | ❌ Removed — web only |

**Out of scope for mobile** (handled by Web repo):
- Admin management / role assignment
- User registration / sign-up
- Email verification flows
- Analytics dashboards
- Bulk data operations
- Super admin controls
- Reporting & exports

Do not add web-scope features to this repository.

---

## 🔗 Related Repositories

| Repo | Description |
|---|---|
| `weassist-mobile` | This repo — Flutter caretaker app |
| `weassist-web` | React/TypeScript web portal — admin dashboard, analytics, full feature set |

Both repos share the same **Firebase project** (Firestore, Auth, Storage). Schema changes in Firestore affect both repos — coordinate before modifying data models.

---

## 🔐 Secrets & Environment

- **Never commit** `google-services.json` or `GoogleService-Info.plist` to version control.
- These files are injected at CI/CD time via environment secrets.
- If missing locally, the app automatically enters **demo mode** (local mock DB).
- Firebase config is read from `lib/firebase/firebaseConfig` equivalent in Dart — check `lib/services/firebase_service.dart`.

---

## 🧪 Testing

```bash
# Run all unit tests
flutter test

# Run with coverage
flutter test --coverage
```

Tests live in the `test/` directory. Add tests for all new service methods and provider logic. Widget tests are optional but encouraged for critical screens.

---

*Last updated: 2026-05-25 | WeAssist Mobile v1.0.0 — Auth: Phone OTP only*
