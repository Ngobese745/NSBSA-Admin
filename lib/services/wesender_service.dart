import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class WeSenderService {
  static const String _baseUrl = 'https://www.wasenderapi.com/api';
  final _supabase = Supabase.instance.client;

  // ---------------------------------------------------------------------------
  // NSBSA WhatsApp Branding Templates
  // ---------------------------------------------------------------------------

  static const String _header =
      '🌐 *NSBSA | Empowering Communities*\n'
      '─────────────────────────────────';

  static const String _footer =
      '─────────────────────────────────\n'
      '📞 *Contact NSBSA*\n'
      '📧 Email: info@nsbsa.org.za\n'
      '☎️  Phone: 087 107 7524\n'
      '💬 WhatsApp: 087 107 7524\n'
      '🌍 Website: https://www.stokvelbody.org.za';

  /// Wraps [body] with the NSBSA header and optional footer.
  ///
  /// Set [includeFooter] to `false` for very short transactional messages
  /// (e.g., OTPs, quick alerts) where the footer would be intrusive.
  static String formatMessage(String body, {bool includeFooter = true}) {
    final buffer = StringBuffer();
    buffer.writeln(_header);
    buffer.writeln();
    buffer.write(body.trim());
    if (includeFooter) {
      buffer.writeln();
      buffer.writeln();
      buffer.write(_footer);
    }
    return buffer.toString();
  }

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  /// Sends a WhatsApp message using the stored WeSender API credentials.
  ///
  /// The NSBSA header and footer are automatically applied to [message].
  /// Set [includeFooter] to `false` to suppress the footer for short messages.
  Future<bool> sendWhatsApp({
    required String to,
    required String message,
    bool includeFooter = true,
  }) async {
    try {
      final apiKey = await _getApiKey();
      if (apiKey == null) {
        debugPrint('WeSender: No active API key found.');
        return false;
      }

      final formattedMessage = formatMessage(message, includeFooter: includeFooter);

      final response = await http.post(
        Uri.parse('$_baseUrl/send-message'),
        headers: {
          'Authorization': 'Bearer $apiKey',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'to': _formatPhoneNumber(to),
          'text': formattedMessage,
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

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

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

  /// Normalises a phone number to E.164 SA format (e.g. 27712345678).
  String _formatPhoneNumber(String phone) {
    final cleaned = phone.replaceAll(RegExp(r'\D'), '');
    if (cleaned.startsWith('0') && cleaned.length == 10) {
      return '27${cleaned.substring(1)}';
    }
    return cleaned;
  }

  /// Tests the connection by calling a real WaSender endpoint.
  Future<bool> testConnection(String apiKey) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/groups'),
        headers: {
          'Authorization': 'Bearer $apiKey',
          'Accept': 'application/json',
        },
      );
      
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
}
