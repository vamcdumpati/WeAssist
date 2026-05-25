import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/admin_user.dart';
import '../models/patient.dart';
import '../models/hospital_visit.dart';

class FirebaseService {
  static bool isDemoMode = false;
  static Future<void>? _initFuture;
  
  // Simulated database for Demo Mode
  static List<AdminUser> _mockAdmins = [];
  static List<Patient> _mockPatients = [];
  static List<HospitalVisit> _mockVisits = [];
  
  // SharedPreferences keys
  static const String _keyAdmins = 'weassist_admins';
  static const String _keyPatients = 'weassist_patients';
  static const String _keyVisits = 'weassist_visits';
  static const String _keyCurrentUser = 'weassist_current_user';

  // Holds simulation logs
  static final List<String> simulationLogs = [];
  static Function()? onLogAdded;

  static void addLog(String log) {
    final timestamp = DateTime.now().toLocal().toString().split('.')[0];
    final formattedLog = '[$timestamp] $log';
    simulationLogs.add(formattedLog);
    if (onLogAdded != null) {
      onLogAdded!();
    }
    print(formattedLog);
  }

  /// Initialize service and check if Firebase is configured.
  static Future<void> init() async {
    if (_initFuture != null) return _initFuture!;
    _initFuture = _doInit();
    return _initFuture!;
  }

  static Future<void> _doInit() async {
    addLog("Initializing FirebaseService... loading local database first.");
    try {
      await _loadMockData();
      addLog("Local persistent database loaded: ${_mockPatients.length} patients, ${_mockVisits.length} trips found.");
      addLog("Local mock database loaded successfully.");
    } catch (e) {
      addLog("Local database failed to load: $e");
    }

    try {
      if (Firebase.apps.isEmpty) {
        addLog("No existing Firebase app found. Initializing with explicit options...");
        await Firebase.initializeApp(
          options: const FirebaseOptions(
            apiKey: 'AIzaSyC24igBgly89VnvMkLacUEJQC4PIyNZj6E',
            appId: '1:289401247925:ios:b89d34c1e9c4d9f39586fc',
            messagingSenderId: '289401247925',
            projectId: 'hey-buddy-18a7b',
            storageBucket: 'hey-buddy-18a7b.firebasestorage.app',
          ),
        );
        addLog("Firebase initialized successfully. Real Mode active.");
      } else {
        addLog("Firebase already initialized (native init). Reusing existing app.");
      }
      isDemoMode = false;
    } catch (e, stack) {
      if (e.toString().contains('duplicate-app')) {
        addLog("Firebase duplicate-app detected — using already-initialized app. Real Mode active.");
        isDemoMode = false;
      } else {
        isDemoMode = false;
        addLog("Firebase initialization failed: $e. Real Mode remains active.");
        print(stack);
      }
    }
  }

  static Exception _handleFirebaseError(dynamic e, String actionContext) {
    final errorStr = e.toString();
    addLog("Error during $actionContext: $errorStr");

    if (errorStr.contains("permission-denied") || errorStr.contains("permission_denied") || errorStr.contains("PERMISSION_DENIED")) {
      return Exception(
        "Firestore Permission Denied:\n"
        "Your Firestore Database security rules are blocking access (Permission Denied).\n\n"
        "To fix this:\n"
        "1. Open Firebase Console: https://console.firebase.google.com/\n"
        "2. Select your project 'hey-buddy-18a7b'\n"
        "3. Go to 'Firestore Database' -> 'Rules' tab (next to Data)\n"
        "4. Update the rules to allow public reads and writes for development:\n\n"
        "rules_version = '2';\n"
        "service cloud.firestore {\n"
        "  match /databases/{database}/documents {\n"
        "    match /{document=**} {\n"
        "      allow read, write: if true;\n"
        "    }\n"
        "  }\n"
        "}\n\n"
        "5. Click 'Publish'."
      );
    }

    if (errorStr.contains("database (default) does not exist") || 
        errorStr.contains("not-found") && errorStr.contains("database") ||
        errorStr.contains("cloud_firestore/unavailable")) {
      return Exception(
        "Firestore Setup Required:\n"
        "The Firestore database (default) does not exist for project 'hey-buddy-18a7b' or the service is temporarily unavailable.\n\n"
        "To fix this:\n"
        "1. Open Firebase Console: https://console.firebase.google.com/\n"
        "2. Select your project 'hey-buddy-18a7b'\n"
        "3. Go to 'Firestore Database' (under Build)\n"
        "4. Click 'Create database', choose location, and start in 'Test mode'."
      );
    }
    
    if (errorStr.contains("operation-not-allowed") || errorStr.contains("operation is not allowed")) {
      return Exception(
        "Firebase Auth Setup Required:\n"
        "Phone Authentication is not enabled in your Firebase project.\n\n"
        "To fix this:\n"
        "1. Go to Firebase Console -> Authentication -> Sign-in method\n"
        "2. Add 'Phone' as a provider and enable it."
      );
    }

    if (errorStr.contains("app-not-authorized") || 
        errorStr.contains("invalid-app-credential") || 
        errorStr.contains("safety-net-attestation") ||
        errorStr.contains("play-integrity") ||
        errorStr.contains("unknown calling package")) {
      return Exception(
        "App Verification Fingerprint (SHA) Missing:\n"
        "Phone Auth failed because the app is not verified.\n\n"
        "To fix this:\n"
        "1. Run './gradlew signingReport' inside the 'android' folder to find your SHA-1/SHA-256 keys.\n"
        "2. Go to Firebase Console -> Project Settings -> General -> Your Android App.\n"
        "3. Click 'Add fingerprint' and enter your SHA-1 and SHA-256 keys."
      );
    }

    if (errorStr.contains("too-many-requests") || errorStr.contains("quota-exceeded")) {
      return Exception(
        "SMS Quota Exceeded:\n"
        "Firebase has blocked requests due to volume.\n\n"
        "To fix this:\n"
        "1. Go to Firebase Console -> Authentication -> Sign-in method -> Phone.\n"
        "2. Add your phone number and a test OTP code (e.g., 123456) under 'Phone numbers for testing'."
      );
    }

    return Exception("$actionContext failed: ${errorStr.replaceAll("Exception: ", "")}");
  }

  static String normalizeMobile(String mobile) {
    var cleaned = mobile.replaceAll(RegExp(r'[\s\-\(\)]'), '');
    if (cleaned.length == 10 && RegExp(r'^\d+$').hasMatch(cleaned)) {
      return '+91$cleaned';
    }
    if (cleaned.startsWith('91') && cleaned.length == 12) {
      return '+$cleaned';
    }
    if (cleaned.isNotEmpty && !cleaned.startsWith('+')) {
      return '+$cleaned';
    }
    return cleaned;
  }

  static Future<void> _ensureInitialized() async {
    if (_initFuture == null) {
      await init();
    } else {
      await _initFuture;
    }
  }

  static Future<void> _loadMockData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      final adminsJson = prefs.getString(_keyAdmins);
      if (adminsJson != null) {
        final List decoded = jsonDecode(adminsJson);
        _mockAdmins = decoded.map((e) => AdminUser.fromMap(e, e['uid'] ?? '')).toList();
      }

      final patientsJson = prefs.getString(_keyPatients);
      if (patientsJson != null) {
        final List decoded = jsonDecode(patientsJson);
        _mockPatients = decoded.map((e) => Patient.fromMap(e, e['id'] ?? '')).toList();
      }

      final visitsJson = prefs.getString(_keyVisits);
      if (visitsJson != null) {
        final List decoded = jsonDecode(visitsJson);
        _mockVisits = decoded.map((e) => HospitalVisit.fromMap(e, e['id'] ?? '')).toList();
      }
      addLog("Local persistent database loaded: ${_mockPatients.length} patients, ${_mockVisits.length} trips found.");
    } catch (e) {
      addLog("Error loading local database: $e");
    }
  }

  static Future<void> _saveMockData(String key, List<Map<String, dynamic>> data) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(key, jsonEncode(data));
    } catch (e) {
      addLog("Error saving local data for key $key: $e");
    }
  }

  // --- ADMIN AUTH FLOWS ---

  /// Triggers OTP dispatch.
  static Future<void> sendOtp(
    String mobile, {
    required Function(String verificationId) onCodeSent,
    required Function(String error) onError,
  }) async {
    await _ensureInitialized();
    final normalizedMobile = normalizeMobile(mobile);
    addLog("Sending OTP to mobile number: $normalizedMobile");
    if (isDemoMode) {
      // Generate a mock code (e.g. 123456)
      final mockVerificationId = 'mock_ver_id_${DateTime.now().millisecondsSinceEpoch}';
      addLog("Demo SMS dispatched to $normalizedMobile! Mock Code: [ 123456 ]");
      onCodeSent(mockVerificationId);
    } else {
      // Real Firebase Phone Auth
      try {
        await FirebaseAuth.instance.verifyPhoneNumber(
          phoneNumber: normalizedMobile,
          verificationCompleted: (PhoneAuthCredential credential) async {
            // Auto-resolution (on some Android devices)
            await FirebaseAuth.instance.signInWithCredential(credential);
            addLog("Real Phone Auth: SMS verified automatically.");
          },
          verificationFailed: (FirebaseAuthException e) {
            final formatted = _handleFirebaseError(e, "Phone Authentication Dispatch");
            onError(formatted.toString().replaceAll("Exception: ", ""));
          },
          codeSent: (String verificationId, int? resendToken) {
            addLog("Real Phone Auth: SMS OTP code dispatched successfully.");
            onCodeSent(verificationId);
          },
          codeAutoRetrievalTimeout: (String verificationId) {},
        ).timeout(const Duration(seconds: 15), onTimeout: () {
          throw TimeoutException("verifyPhoneNumber timed out.");
        });
      } catch (e) {
        final formatted = _handleFirebaseError(e, "Phone Authentication Dispatch");
        onError(formatted.toString().replaceAll("Exception: ", ""));
      }
    }
  }

  /// Verify entered OTP code.
  static Future<AdminUser?> verifyOtp({
    required String mobile,
    required String verificationId,
    required String smsCode,
  }) async {
    await _ensureInitialized();
    final normalizedMobile = normalizeMobile(mobile);
    addLog("Verifying OTP code: $smsCode for id: $verificationId");
    if (isDemoMode) {
      if (smsCode == '123456' || smsCode == '654321') {
        final admin = _mockAdmins.firstWhere(
          (a) => a.mobile == normalizedMobile,
          orElse: () => AdminUser(
            uid: 'mock_uid_${DateTime.now().millisecondsSinceEpoch}',
            firstName: 'Caretaker',
            lastName: '',
            mobile: normalizedMobile,
          ),
        );

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_keyCurrentUser, jsonEncode(admin.toMap()..['uid'] = admin.uid));

        addLog('Demo Login Successful: Caretaker ${admin.displayName} is logged in.');
        return admin;
      } else {
        throw Exception('Incorrect verification code.');
      }
    } else {
      try {
        // Real Firebase Phone Auth credential verification
        final credential = PhoneAuthProvider.credential(
          verificationId: verificationId,
          smsCode: smsCode,
        );
        final authResult = await FirebaseAuth.instance.signInWithCredential(credential).timeout(const Duration(seconds: 15));
        final user = authResult.user;
        if (user != null) {
          // Fetch profile details from Firestore
          // Look up by doc ID first
          var doc = await FirebaseFirestore.instance.collection('admins').doc(normalizedMobile).get().timeout(const Duration(seconds: 15));
          
          // If not found by doc ID, search by mobile field
          if (!doc.exists) {
            final query = await FirebaseFirestore.instance
                .collection('admins')
                .where('mobile', isEqualTo: normalizedMobile)
                .get()
                .timeout(const Duration(seconds: 15));
            if (query.docs.isNotEmpty) {
              doc = query.docs.first;
            }
          }
          // Try mobileNumber field as fallback
          if (!doc.exists) {
            final query = await FirebaseFirestore.instance
                .collection('admins')
                .where('mobileNumber', isEqualTo: normalizedMobile)
                .get()
                .timeout(const Duration(seconds: 15));
            if (query.docs.isNotEmpty) {
              doc = query.docs.first;
            }
          }

          if (doc.exists) {
            final admin = AdminUser.fromMap(doc.data()!, doc.id);
            addLog('Real Login Successful: Caretaker ${admin.displayName} logged in.');
            return admin;
          } else {
            // Document does not exist yet — auto-create a default profile for phone-only signup.
            final admin = AdminUser(
              uid: user.uid,
              firstName: 'Caretaker',
              lastName: '',
              mobile: normalizedMobile,
            );
            await FirebaseFirestore.instance.collection('admins').doc(normalizedMobile).set(admin.toMap()).timeout(const Duration(seconds: 15));
            addLog('Real Login Successful: Created default caretaker profile for $normalizedMobile.');
            return admin;
          }
        }
        throw Exception("Phone authentication failed.");
      } catch (e) {
        throw _handleFirebaseError(e, "OTP Verification");
      }
    }
  }

  /// Retrieve the current logged-in user profile, if any.
  static Future<AdminUser?> getCurrentUser() async {
    await _ensureInitialized();
    if (isDemoMode) {
      final prefs = await SharedPreferences.getInstance();
      final userJson = prefs.getString(_keyCurrentUser);
      if (userJson != null) {
        final decoded = jsonDecode(userJson);
        return AdminUser.fromMap(decoded, decoded['uid'] ?? '');
      }
      return null;
    } else {
      try {
        final user = FirebaseAuth.instance.currentUser;
        if (user != null && user.phoneNumber != null) {
          // Look up by phone number (the only auth method on mobile)
          final normalizedMobile = normalizeMobile(user.phoneNumber!);
          var doc = await FirebaseFirestore.instance
              .collection('admins')
              .doc(normalizedMobile)
              .get()
              .timeout(const Duration(seconds: 15));
          if (!doc.exists) {
            final query = await FirebaseFirestore.instance
                .collection('admins')
                .where('mobile', isEqualTo: normalizedMobile)
                .get()
                .timeout(const Duration(seconds: 15));
            if (query.docs.isNotEmpty) {
              doc = query.docs.first;
            }
          }
          if (doc.exists) {
            return AdminUser.fromMap(doc.data()!, doc.id);
          }
        }
      } catch (e) {
        addLog('Error fetching current user session: $e');
      }
      return null;
    }
  }

  /// Sign out.
  static Future<void> signOut() async {
    await _ensureInitialized();
    addLog("Signing out current user session.");
    if (isDemoMode) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyCurrentUser);
    } else {
      await FirebaseAuth.instance.signOut();
    }
  }

  // --- PATIENTS FLOWS ---

  /// Register a new Patient.
  static Future<Patient> registerPatient(Patient patient) async {
    await _ensureInitialized();
    addLog("Registering Patient: ${patient.name}");
    if (isDemoMode) {
      final id = 'mock_pat_${DateTime.now().millisecondsSinceEpoch}';
      final newPat = Patient(
        id: id,
        name: patient.name,
        dob: patient.dob,
        gender: patient.gender,
        height: patient.height,
        weight: patient.weight,
        photoUrl: patient.photoUrl,
        identityProofUrl: patient.identityProofUrl,
        mobile: patient.mobile,
        emergencyContact: patient.emergencyContact,
        createdAt: DateTime.now(),
      );

      _mockPatients.add(newPat);
      await _saveMockData(_keyPatients, _mockPatients.map((e) => e.toMap()..['id'] = e.id).toList());
      addLog("Demo Patient registered with ID: $id");
      return newPat;
    } else {
      try {
        // Real Firestore database registration
        // Upload images to Firebase Storage first (if local paths)
        String portraitUrl = patient.photoUrl;
        String idProofUrl = patient.identityProofUrl;

        if (portraitUrl.isNotEmpty && !portraitUrl.startsWith('http')) {
          try {
            final ref = FirebaseStorage.instance.ref().child('patients/portraits/${DateTime.now().millisecondsSinceEpoch}.jpg');
            final uploadTask = await ref.putFile(File(portraitUrl)).timeout(const Duration(seconds: 15));
            portraitUrl = await uploadTask.ref.getDownloadURL().timeout(const Duration(seconds: 15));
            addLog("Uploaded patient portrait image to Firebase Storage.");
          } catch (e) {
            addLog("Storage upload error (portrait): $e");
          }
        }

        if (idProofUrl.isNotEmpty && !idProofUrl.startsWith('http')) {
          try {
            final ref = FirebaseStorage.instance.ref().child('patients/identities/${DateTime.now().millisecondsSinceEpoch}.jpg');
            final uploadTask = await ref.putFile(File(idProofUrl)).timeout(const Duration(seconds: 15));
            idProofUrl = await uploadTask.ref.getDownloadURL().timeout(const Duration(seconds: 15));
            addLog("Uploaded patient identity proof image to Firebase Storage.");
          } catch (e) {
            addLog("Storage upload error (identity): $e");
          }
        }

        final docRef = FirebaseFirestore.instance.collection('patients').doc();
        final newPat = Patient(
          id: docRef.id,
          name: patient.name,
          dob: patient.dob,
          gender: patient.gender,
          height: patient.height,
          weight: patient.weight,
          photoUrl: portraitUrl,
          identityProofUrl: idProofUrl,
          mobile: patient.mobile,
          emergencyContact: patient.emergencyContact,
          createdAt: DateTime.now(),
        );

        await docRef.set(newPat.toMap()).timeout(const Duration(seconds: 15));
        addLog("Real Patient registered in Firestore with ID: ${docRef.id}");
        return newPat;
      } catch (e) {
        throw _handleFirebaseError(e, "Patient Registration");
      }
    }
  }

  /// Get list of patients.
  static Future<List<Patient>> getPatients() async {
    await _ensureInitialized();
    addLog("Fetching patients directory list.");
    if (isDemoMode) {
      return _mockPatients;
    } else {
      try {
        final query = await FirebaseFirestore.instance
            .collection('patients')
            .orderBy('createdAt', descending: true)
            .get()
            .timeout(const Duration(seconds: 15));
        return query.docs.map((doc) => Patient.fromMap(doc.data(), doc.id)).toList();
      } catch (e) {
        throw _handleFirebaseError(e, "Fetching Patients Directory");
      }
    }
  }

  // --- TRANSIT VISITS FLOWS ---

  /// Schedule a new hospital transit trip.
  static Future<HospitalVisit> createVisit(HospitalVisit visit) async {
    await _ensureInitialized();
    addLog("Scheduling transit visit for ${visit.patientName} to ${visit.hospitalName}");
    if (isDemoMode) {
      final id = 'mock_vis_${DateTime.now().millisecondsSinceEpoch}';
      final newVisit = HospitalVisit(
        id: id,
        patientId: visit.patientId,
        patientName: visit.patientName,
        hospitalName: visit.hospitalName,
        hospitalArea: visit.hospitalArea,
        caretakerLat: visit.caretakerLat,
        caretakerLng: visit.caretakerLng,
        emergencyContact: visit.emergencyContact,
        patientMobile: visit.patientMobile,
        status: visit.status,
        createdAt: DateTime.now(),
        startedAt: visit.startedAt,
        completedAt: visit.completedAt,
      );

      _mockVisits.add(newVisit);
      await _saveMockData(_keyVisits, _mockVisits.map((e) => e.toMap()..['id'] = e.id).toList());
      addLog("Demo Visit created with ID: $id");
      return newVisit;
    } else {
      try {
        final docRef = FirebaseFirestore.instance.collection('visits').doc();
        final newVisit = HospitalVisit(
          id: docRef.id,
          patientId: visit.patientId,
          patientName: visit.patientName,
          hospitalName: visit.hospitalName,
          hospitalArea: visit.hospitalArea,
          caretakerLat: visit.caretakerLat,
          caretakerLng: visit.caretakerLng,
          emergencyContact: visit.emergencyContact,
          patientMobile: visit.patientMobile,
          status: visit.status,
          createdAt: DateTime.now(),
          startedAt: visit.startedAt,
          completedAt: visit.completedAt,
        );

        await docRef.set(newVisit.toMap()).timeout(const Duration(seconds: 15));
        addLog("Real Visit created in Firestore with ID: ${docRef.id}");
        return newVisit;
      } catch (e) {
        throw _handleFirebaseError(e, "Transit Visit Creation");
      }
    }
  }

  /// Update trip status.
  static Future<void> updateVisitStatus(String visitId, String status) async {
    await _ensureInitialized();
    addLog("Updating trip $visitId status to: $status");
    final now = DateTime.now();
    if (isDemoMode) {
      final idx = _mockVisits.indexWhere((v) => v.id == visitId);
      if (idx != -1) {
        final current = _mockVisits[idx];
        _mockVisits[idx] = HospitalVisit(
          id: current.id,
          patientId: current.patientId,
          patientName: current.patientName,
          hospitalName: current.hospitalName,
          hospitalArea: current.hospitalArea,
          caretakerLat: current.caretakerLat,
          caretakerLng: current.caretakerLng,
          emergencyContact: current.emergencyContact,
          patientMobile: current.patientMobile,
          status: status,
          createdAt: current.createdAt,
          startedAt: status == 'transit' ? now : current.startedAt,
          completedAt: status == 'completed' ? now : current.completedAt,
        );
        await _saveMockData(_keyVisits, _mockVisits.map((e) => e.toMap()..['id'] = e.id).toList());
        addLog("Demo Trip status updated.");
      }
    } else {
      try {
        final updateData = <String, dynamic>{'status': status};
        if (status == 'transit') {
          updateData['startedAt'] = now.toIso8601String();
        } else if (status == 'completed') {
          updateData['completedAt'] = now.toIso8601String();
        }
        await FirebaseFirestore.instance
            .collection('visits')
            .doc(visitId)
            .update(updateData)
            .timeout(const Duration(seconds: 15));
        addLog("Real Trip status updated in Firestore.");
      } catch (e) {
        throw _handleFirebaseError(e, "Trip Status Update");
      }
    }
  }

  /// Fetch visits.
  static Future<List<HospitalVisit>> getAllVisits() async {
    await _ensureInitialized();
    if (isDemoMode) {
      return _mockVisits;
    } else {
      try {
        final query = await FirebaseFirestore.instance
            .collection('visits')
            .orderBy('createdAt', descending: true)
            .get()
            .timeout(const Duration(seconds: 15));
        return query.docs.map((doc) => HospitalVisit.fromMap(doc.data(), doc.id)).toList();
      } catch (e) {
        throw _handleFirebaseError(e, "Fetching Transit Visits");
      }
    }
  }
}
