import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart' as io;

class ApiService {
  static const String baseUrl = 'https://emergency-tracker-api.onrender.com';

  // Inner HTTP client configured to allow SSL handshakes on fallback IP addresses
  // for the Render CDN (*.onrender.com certificate).
  static final HttpClient _innerIoClient = HttpClient()
    ..badCertificateCallback = (X509Certificate cert, String host, int port) {
      if ((host == '216.24.57.251' || host == '216.24.57.7') && cert.subject.contains('onrender.com')) {
        return true;
      }
      return false;
    };

  static final http.Client _customClient = io.IOClient(_innerIoClient);

  /// Helper to resolve a domain name using Google's DNS-over-HTTPS JSON API via IP.
  /// This works in offline/DNS-broken emulators as long as IP routing (e.g. 8.8.8.8) is functional.
  static Future<String?> _resolveDomainOverDoh(String domain) async {
    try {
      final url = Uri.parse('https://8.8.8.8/resolve?name=$domain');
      final response = await http.get(url).timeout(const Duration(seconds: 4));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is Map && data['Answer'] is List) {
          final answers = data['Answer'] as List;
          for (var ans in answers) {
            if (ans is Map && ans['type'] == 1 && ans['data'] != null) {
              return ans['data'].toString();
            }
          }
        }
      }
    } catch (e) {
      print('[DNS FALLBACK ERROR] Failed to resolve $domain via DoH: $e');
    }
    return null;
  }

  /// Sends a request and automatically falls back to secure DoH + Direct IP routing if standard DNS fails.
  static Future<http.Response> _sendRequestWithDohFallback({
    required String method,
    required Uri originalUri,
    Map<String, String>? headers,
    Object? body,
  }) async {
    headers ??= {};
    headers = Map<String, String>.from(headers);

    try {
      // 1. Try standard connection first
      http.Response response;
      if (method == 'POST') {
        response = await http.post(originalUri, headers: headers, body: body).timeout(const Duration(seconds: 8));
      } else {
        response = await http.get(originalUri, headers: headers).timeout(const Duration(seconds: 8));
      }
      return response;
    } catch (e) {
      final errStr = e.toString();
      final isDnsError = errStr.contains('SocketException') || 
                         errStr.contains('Failed host lookup') || 
                         errStr.contains('ClientException');
      
      if (isDnsError && originalUri.host == 'emergency-tracker-api.onrender.com') {
        print('[DNS FALLBACK] DNS lookup failed. Attempting Google DNS-over-HTTPS fallback...');
        final ip = await _resolveDomainOverDoh('emergency-tracker-api.onrender.com');
        if (ip != null) {
          print('[DNS FALLBACK] Successfully resolved IP via DoH: $ip');
          final fallbackUri = originalUri.replace(host: ip);
          headers['Host'] = 'emergency-tracker-api.onrender.com';

          print('[DNS FALLBACK] Retrying request directly to IP: $fallbackUri');
          http.Response response;
          if (method == 'POST') {
            response = await _customClient.post(fallbackUri, headers: headers, body: body);
          } else {
            response = await _customClient.get(fallbackUri, headers: headers);
          }
          return response;
        }
      }
      rethrow;
    }
  }

  /// Helper to parse FastAPI and generic error messages
  static String _parseError(http.Response response) {
    try {
      final body = jsonDecode(response.body);
      if (body is Map) {
        if (body.containsKey('detail')) {
          final detail = body['detail'];
          if (detail is List) {
            return detail.map((e) => e['msg'] ?? e.toString()).join(', ');
          }
          return detail.toString();
        }
        if (body.containsKey('message')) {
          return body['message'].toString();
        }
      }
      return 'Error: ${response.statusCode} - ${response.reasonPhrase}';
    } catch (_) {
      return 'Request failed with status: ${response.statusCode}';
    }
  }

  /// Get caretaker profile by ID
  /// Uses GET /mobile/caretaker/{caretaker_id}
  static Future<Map<String, dynamic>> getCaretaker({
    required String caretakerId,
  }) async {
    final url = Uri.parse('$baseUrl/mobile/caretaker/$caretakerId');

    print('[API REQUEST] GET /mobile/caretaker/$caretakerId\nURL: $url');

    final response = await _sendRequestWithDohFallback(
      method: 'GET',
      originalUri: url,
      headers: {'Content-Type': 'application/json'},
    );

    print('[API RESPONSE] GET /mobile/caretaker/$caretakerId\nStatus: ${response.statusCode}\nBody: ${response.body}');

    if (response.statusCode != 200) {
      throw Exception(_parseError(response));
    }

    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  /// Complete OTP login on backend with Firebase ID Token
  /// Returns OTPLoginResponse: {user_id, name, phone, is_new_user, message}
  static Future<Map<String, dynamic>> otpLogin({
    required String firebaseIdToken,
    String? name,
  }) async {
    final url = Uri.parse('$baseUrl/mobile/auth/otp-login');
    final payload = {
      'firebase_id_token': firebaseIdToken,
      if (name != null) 'name': name,
    };

    print('[API REQUEST] POST /mobile/auth/otp-login\nURL: $url\nPayload: $payload');

    final response = await _sendRequestWithDohFallback(
      method: 'POST',
      originalUri: url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(payload),
    );

    print('[API RESPONSE] POST /mobile/auth/otp-login\nStatus: ${response.statusCode}\nBody: ${response.body}');

    if (response.statusCode != 200) {
      throw Exception(_parseError(response));
    }

    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  /// Retrieve user profile by ID (legacy auth endpoint)
  static Future<Map<String, dynamic>> getUser({
    required String userId,
  }) async {
    final url = Uri.parse('$baseUrl/web/auth/user/$userId');

    print('[API REQUEST] GET /web/auth/user/$userId\nURL: $url');

    final response = await _sendRequestWithDohFallback(
      method: 'GET',
      originalUri: url,
      headers: {'Content-Type': 'application/json'},
    );

    print('[API RESPONSE] GET /web/auth/user/$userId\nStatus: ${response.statusCode}\nBody: ${response.body}');

    if (response.statusCode != 200) {
      throw Exception(_parseError(response));
    }

    return jsonDecode(response.body) as Map<String, dynamic>;
  }
}
