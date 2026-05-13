import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SMSWorxService {
  static const String _baseUrl = 'https://rest.mymobileapi.com/v3';
  final _supabase = Supabase.instance.client;

  /// Sends an SMS to a single recipient using the stored SMSWorx API credentials.
  Future<bool> sendSMS({
    required String destination,
    required String message,
    String? senderId,
  }) async {
    try {
      final credentials = await _getCredentials();
      if (credentials == null) {
        debugPrint('SMSWorx: No active API credentials found.');
        return false;
      }

      final String basicAuth = 'Basic ${base64Encode(utf8.encode('${credentials['clientId']}:${credentials['apiSecret']}'))}';

      final response = await http.post(
        Uri.parse('$_baseUrl/BulkMessages'),
        headers: {
          'Authorization': basicAuth,
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'sendOptions': {
            'allowContentTrimming': true,
            if (senderId != null) 'senderId': senderId,
          },
          'messages': [
            {
              'content': message,
              'destination': _formatPhoneNumber(destination),
            }
          ],
        }),
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        debugPrint('SMSWorx: Message sent successfully to $destination');
        return true;
      } else {
        debugPrint('SMSWorx Error (${response.statusCode}): ${response.body}');
        return false;
      }
    } catch (e) {
      debugPrint('SMSWorx Exception: $e');
      return false;
    }
  }

  /// Fetches the active SMSWorx credentials from the api_keys table.
  /// Expects the key to be stored in the format "clientID:apiSecret".
  Future<Map<String, String>?> _getCredentials() async {
    try {
      final response = await _supabase
          .from('api_keys')
          .select('api_key')
          .eq('service_name', 'smsworx')
          .eq('status', 'active')
          .maybeSingle();

      if (response == null) return null;

      final String rawKey = response['api_key'];
      final parts = rawKey.split(':');
      if (parts.length != 2) {
        debugPrint('SMSWorx: Invalid key format in database. Expected "clientID:apiSecret"');
        return null;
      }

      return {
        'clientId': parts[0],
        'apiSecret': parts[1],
      };
    } catch (e) {
      debugPrint('SMSWorx Credential Fetch Error: $e');
      return null;
    }
  }

  /// Ensures the phone number is in international format (e.g., 27...)
  String _formatPhoneNumber(String phone) {
    String cleaned = phone.replaceAll(RegExp(r'\D'), '');
    if (cleaned.startsWith('0') && cleaned.length == 10) {
      return '27${cleaned.substring(1)}';
    }
    // If it already starts with 27 and is 11-12 digits, return as is
    if (cleaned.startsWith('27') && (cleaned.length == 11 || cleaned.length == 12)) {
      return cleaned;
    }
    return cleaned;
  }

  /// Tests the connection by fetching the account balance.
  Future<bool> testConnection(String clientId, String apiSecret) async {
    try {
      final String basicAuth = 'Basic ${base64Encode(utf8.encode('$clientId:$apiSecret'))}';
      
      final response = await http.get(
        Uri.parse('$_baseUrl/Balance'),
        headers: {
          'Authorization': basicAuth,
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        debugPrint('SMSWorx: Connection test successful. Balance retrieved.');
        return true;
      } else {
        debugPrint('SMSWorx: Connection test failed (${response.statusCode}): ${response.body}');
        return false;
      }
    } catch (e) {
      debugPrint('SMSWorx Test Connection Error: $e');
      return false;
    }
  }
}
