import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import '../models/admin_user.dart';
import '../services/firebase_service.dart';
import '../services/api_service.dart';

class AuthProvider with ChangeNotifier {
  AdminUser? _currentUser;
  bool _isLoading = false;
  bool _isInitialized = false;
  String? _error;
  String? _activeVerificationId;
  String? _loginMobileNumber;
  bool _isOnline = true;
  Timer? _connectivityTimer;

  AdminUser? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  bool get isInitialized => _isInitialized;
  String? get error => _error;
  String? get activeVerificationId => _activeVerificationId;
  String? get loginMobileNumber => _loginMobileNumber;
  bool get isOnline => _isOnline;

  void clearError() {
    _error = null;
    notifyListeners();
  }

  void startConnectivityMonitoring() {
    _connectivityTimer?.cancel();
    _checkInternetConnection();
    _connectivityTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
      _checkInternetConnection();
    });
  }

  Future<void> _checkInternetConnection() async {
    final prevOnline = _isOnline;
    bool online = false;
    try {
      final result = await InternetAddress.lookup('google.com')
          .timeout(const Duration(seconds: 4));
      if (result.isNotEmpty && result[0].rawAddress.isNotEmpty) {
        online = true;
      }
    } catch (_) {
      try {
        final response = await http
            .get(Uri.parse('https://www.google.com'))
            .timeout(const Duration(seconds: 4));
        if (response.statusCode >= 200 && response.statusCode < 400) {
          online = true;
        }
      } catch (_) {
        try {
          final socket =
              await Socket.connect('8.8.8.8', 53, timeout: const Duration(seconds: 3));
          socket.destroy();
          online = true;
        } catch (_) {
          try {
            final socket = await Socket.connect('1.1.1.1', 53,
                timeout: const Duration(seconds: 3));
            socket.destroy();
            online = true;
          } catch (_) {
            online = false;
          }
        }
      }
    }
    _isOnline = online;
    if (prevOnline != _isOnline) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _connectivityTimer?.cancel();
    super.dispose();
  }

  /// Check if user session already exists
  Future<void> checkSession() async {
    startConnectivityMonitoring();
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      final userJson = prefs.getString('weassist_current_user');
      if (userJson != null) {
        final decoded = jsonDecode(userJson);
        final cachedUser = AdminUser.fromMap(decoded, decoded['uid'] ?? '');
        _currentUser = cachedUser;
        notifyListeners();

        // Refresh user profile in background from caretaker endpoint
        try {
          final profile =
              await ApiService.getCaretaker(caretakerId: cachedUser.uid)
                  .timeout(const Duration(seconds: 5));
          _currentUser = AdminUser(
            uid: cachedUser.uid,
            firstName: profile['first_name'] ?? '',
            lastName: profile['last_name'] ?? '',
            mobile: profile['mobile'] ?? '',
            role: profile['role'],
          );
          await prefs.setString(
            'weassist_current_user',
            jsonEncode(_currentUser!.toMap()..['uid'] = _currentUser!.uid),
          );
        } catch (e) {
          debugPrint('Failed to background-refresh cached user profile: $e');
        }
      } else {
        final fbUser = await FirebaseService.getCurrentUser();
        if (fbUser != null) {
          _currentUser = fbUser;
        }
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      _isInitialized = true;
      notifyListeners();
    }
  }

  // ─── OTP Flow ──────────────────────────────────────────────────────────────

  /// Step 1: Send OTP to the given mobile number via Firebase
  Future<void> sendOtp({
    required String mobile,
    required VoidCallback onOtpSent,
    required Function(String) onFailure,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _loginMobileNumber = mobile;
      await FirebaseService.sendOtp(
        mobile,
        onCodeSent: (verId) {
          _activeVerificationId = verId;
          _isLoading = false;
          notifyListeners();
          onOtpSent();
        },
        onError: (err) {
          _error = err;
          _isLoading = false;
          notifyListeners();
          onFailure(err);
        },
      );
    } catch (e) {
      _error = e.toString().replaceAll('Exception: ', '');
      _isLoading = false;
      notifyListeners();
      onFailure(_error!);
    }
  }

  /// Step 2: Verify OTP.
  /// - Calls [onExistingUser] if user is already registered → login complete
  /// - Calls [onNewUser] if user doesn't exist yet → show registration form
  /// Step 2: Verify OTP and fetch user profile.
  Future<void> verifyOtpCode({
    required String smsCode,
    required VoidCallback onSuccess,
    required Function(String) onFailure,
  }) async {
    if (_loginMobileNumber == null || _activeVerificationId == null) {
      onFailure('Invalid login session. Please restart and try again.');
      return;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Firebase OTP verification
      await FirebaseService.verifyOtp(
        mobile: _loginMobileNumber!,
        verificationId: _activeVerificationId!,
        smsCode: smsCode,
      );

      final fbUser = FirebaseAuth.instance.currentUser;
      if (fbUser == null) throw Exception('Firebase auth failed. Please retry.');

      final idToken = await fbUser.getIdToken();
      if (idToken == null) throw Exception('Failed to get Firebase ID token.');

      // Call backend OTP login with a defensive fallback if the backend returns 500 or is offline
      Map<String, dynamic>? otpResponse;
      try {
        otpResponse = await ApiService.otpLogin(firebaseIdToken: idToken);
        print('[AUTH] otp-login response: $otpResponse');
      } catch (e) {
        print('Backend otp-login failed, falling back to local session: $e');
      }

      final userId = otpResponse?['user_id']?.toString() ?? fbUser.uid;
      Map<String, dynamic>? profile;
      if (otpResponse != null) {
        try {
          profile = await ApiService.getCaretaker(caretakerId: userId);
        } catch (e) {
          print('Could not fetch caretaker profile, using otp-login data: $e');
        }
      }

      _currentUser = AdminUser(
        uid: userId,
        firstName: profile?['first_name'] ?? otpResponse?['name']?.toString().split(' ').first ?? 'Caretaker',
        lastName: profile?['last_name'] ?? ((otpResponse?['name']?.toString().split(' ').length ?? 0) > 1
            ? otpResponse!['name'].toString().split(' ').sublist(1).join(' ')
            : ''),
        mobile: profile?['mobile'] ?? fbUser.phoneNumber ?? _loginMobileNumber ?? '',
        role: profile?['role'],
      );

      await _saveUserToPrefs();
      _isLoading = false;
      notifyListeners();
      onSuccess();
    } catch (e) {
      _error = e.toString().replaceAll('Exception: ', '');
      _isLoading = false;
      notifyListeners();
      onFailure(_error!);
    }
  }

  // ─── Helpers ───────────────────────────────────────────────────────────────

  Future<void> _saveUserToPrefs() async {
    if (_currentUser == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'weassist_current_user',
      jsonEncode(_currentUser!.toMap()..['uid'] = _currentUser!.uid),
    );
  }

  /// Sign out
  Future<void> signOutUser() async {
    _isLoading = true;
    notifyListeners();
    try {
      await FirebaseService.signOut();
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('weassist_current_user');
      _currentUser = null;
      _loginMobileNumber = null;
      _activeVerificationId = null;
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
