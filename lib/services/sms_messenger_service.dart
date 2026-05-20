import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import '../utils/env_utils.dart';

class SMSMessengerService {
  // Fetch credentials from environment or Supabase config
  Future<Map<String, String>?> _fetchCredentials() async {
    final clientId = await EnvUtils.getEnv('SMS_MESSENGER_CLIENT_ID');
    final apiSecret = await EnvUtils.getEnv('SMS_MESSENGER_API_SECRET');
    if (clientId == null || apiSecret == null) {
      return null;
    }
    return {'clientId': clientId, 'apiSecret': apiSecret};
  }

  /// Sends an SMS using SMS Messenger API.
  /// Returns true on success, false otherwise.
  Future<bool> sendSMS({required String destination, required String message}) async {
    final creds = await _fetchCredentials();
    if (creds == null) {
      debugPrint('SMSMessenger: Missing API credentials');
      return false;
    }
    final url = Uri.parse('https://sms1.smsmessenger.co.za/api/v1/send');
    final body = {
      'client_id': creds['clientId'],
      'api_secret': creds['apiSecret'],
      'to': destination,
      'message': message,
    };
    try {
      final response = await http.post(url, headers: {'Content-Type': 'application/json'}, body: jsonEncode(body));
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        if (json['status'] == 'success') {
          debugPrint('SMSMessenger: Message sent to $destination');
          return true;
        } else {
          debugPrint('SMSMessenger error: \\${json['message']}');
          return false;
        }
      } else {
        debugPrint('SMSMessenger HTTP ${response.statusCode}: ${response.body}');
        return false;
      }
    } catch (e) {
      debugPrint('SMSMessenger exception: $e');
      return false;
    }
  }

  /// Test connection by attempting a lightweight request.
  /// Returns true if the API responds with success.
  Future<bool> testConnection() async {
    // Use a dummy call to the status endpoint if available; otherwise a ping.
    final creds = await _fetchCredentials();
    if (creds == null) return false;
    final url = Uri.parse('https://sms1.smsmessenger.co.za/api/v1/status');
    try {
      final response = await http.get(url, headers: {
        'client_id': creds['clientId']!,
        'api_secret': creds['apiSecret']!,
      });
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}
