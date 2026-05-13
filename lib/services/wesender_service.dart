import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class WeSenderService {
  static const String _baseUrl = 'https://www.wasenderapi.com/api';
  final _supabase = Supabase.instance.client;

  /// Sends a WhatsApp message using the stored WeSender API credentials.
  Future<bool> sendWhatsApp({
    required String to,
    required String message,
  }) async {
    try {
      final apiKey = await _getApiKey();
      if (apiKey == null) {
        debugPrint('WeSender: No active API key found.');
        return false;
      }

      final response = await http.post(
        Uri.parse('$_baseUrl/send-message'),
        headers: {
          'Authorization': 'Bearer $apiKey',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'to': _formatPhoneNumber(to),
          'text': message,
        }),
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        debugPrint('WeSender: WhatsApp sent successfully to $to');
        return true;
      } else {
        debugPrint('WeSender Error (${response.statusCode}): ${response.body}');
        return false;
      }
    } catch (e) {
      debugPrint('WeSender Exception: $e');
      return false;
    }
  }

  /// Fetches the active WeSender API key from the api_keys table.
  Future<String?> _getApiKey() async {
    try {
      final response = await _supabase
          .from('api_keys')
          .select('api_key')
          .eq('service_name', 'wesender')
          .eq('status', 'active')
          .maybeSingle();

      return response?['api_key']?.toString();
    } catch (e) {
      debugPrint('WeSender Key Fetch Error: $e');
      return null;
    }
  }

  /// Formats phone number for WhatsApp (E.164 without the '+' for some APIs, or with it).
  /// Standardizing to E.164 (e.g., 27712345678).
  String _formatPhoneNumber(String phone) {
    String cleaned = phone.replaceAll(RegExp(r'\D'), '');
    if (cleaned.startsWith('0') && cleaned.length == 10) {
      return '27${cleaned.substring(1)}';
    }
    return cleaned;
  }

  /// Tests the connection (usually by calling a simple account/profile endpoint).
  Future<bool> testConnection(String apiKey) async {
    try {
      // Trying to fetch profile or a simple endpoint to verify key
      final response = await http.get(
        Uri.parse('$_baseUrl/me'), // Assuming /me or /profile exists for test
        headers: {
          'Authorization': 'Bearer $apiKey',
          'Accept': 'application/json',
        },
      );
      // Even if 404, if it's not 401/403, the key might be valid. 
      // But let's assume a success status code.
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
}
