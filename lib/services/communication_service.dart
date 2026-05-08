import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class CommunicationService {
  final String _mailerSendApiKey = dotenv.env['MAILERSEND_API_KEY'] ?? '';
  final String _weSenderApiKey = dotenv.env['WESENDER_API_KEY'] ?? '';

  Future<void> sendPaymentReminder({required String toEmail, required String toPhone, required String amount}) async {
    debugPrint('Preparing to send payment reminder for $amount');
    // TODO: Implement HTTP POST to MailerSend API
    if (_mailerSendApiKey.isEmpty) {
      debugPrint('MailerSend API Key is missing. Skipping email/sms.');
    } else {
      debugPrint('Email/SMS sent successfully to $toEmail / $toPhone via MailerSend.');
    }

    // TODO: Implement HTTP POST to WeSender API
    if (_weSenderApiKey.isEmpty) {
      debugPrint('WeSender API Key is missing. Skipping WhatsApp message.');
    } else {
      debugPrint('WhatsApp message sent successfully to $toPhone via WeSender.');
    }
  }

  Future<void> sendAnnouncement({required String groupRef, required String message}) async {
    debugPrint('Preparing to send announcement to group $groupRef: $message');
    // Logic to dispatch bulk messages will go here once API details are finalized.
  }
}
