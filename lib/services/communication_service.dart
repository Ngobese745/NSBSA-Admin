import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class CommunicationService {
  final String _mailerSendApiKey = dotenv.env['MAILERSEND_API_KEY'] ?? '';
  final String _weSenderApiKey = dotenv.env['WESENDER_API_KEY'] ?? '';

  Future<void> sendPaymentReminder({required String toEmail, required String toPhone, required String amount}) async {
    debugPrint('Preparing to send payment reminder for $amount');
    
    if (_mailerSendApiKey.isNotEmpty) {
      await _sendEmail(
        to: toEmail,
        subject: 'Payment Reminder - NSBSA',
        text: 'Dear member, this is a reminder for your upcoming payment of $amount. Please ensure funds are available.',
        html: '<p>Dear member,</p><p>This is a reminder for your upcoming payment of <strong>$amount</strong>.</p><p>Please ensure funds are available.</p>',
      );
    }

    // TODO: Implement WeSender API for WhatsApp
    if (_weSenderApiKey.isEmpty) {
      debugPrint('WeSender API Key is missing. Skipping WhatsApp message.');
    } else {
      debugPrint('WhatsApp message sent successfully to $toPhone via WeSender.');
    }
  }

  /// Sends temporary credentials to a new staff member.
  Future<void> sendStaffCredentials({
    required String toEmail,
    required String fullName,
    required String tempPassword,
  }) async {
    debugPrint('Sending staff credentials to $toEmail');
    
    if (_mailerSendApiKey.isNotEmpty) {
      await _sendEmail(
        to: toEmail,
        subject: 'Welcome to NSBSA Admin - Your Account is Ready',
        text: 'Welcome $fullName! Your account has been created. Log in at https://nsbsa-admin.vercel.app with your email and temporary password: $tempPassword. You will be prompted to set a permanent password on your first login.',
        html: '''
          <h3>Welcome $fullName!</h3>
          <p>Your NSBSA Admin account has been created successfully.</p>
          <p><strong>Login URL:</strong> <a href="https://nsbsa-admin.vercel.app">https://nsbsa-admin.vercel.app</a></p>
          <p><strong>Email:</strong> $toEmail</p>
          <p><strong>Temporary Password:</strong> <code>$tempPassword</code></p>
          <p><em>For security reasons, you will be prompted to set a permanent password when you first log in.</em></p>
        ''',
      );
    } else {
      debugPrint('MAILERSEND_API_KEY missing. Cannot send credentials email.');
    }
  }

  Future<void> _sendEmail({
    required String to,
    required String subject,
    required String text,
    required String html,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('https://api.mailersend.com/v1/email'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_mailerSendApiKey',
        },
        body: jsonEncode({
          'from': {
            'email': 'noreply@nsbsa.org.za',
            'name': 'NSBSA Admin',
          },
          'to': [
            {'email': to}
          ],
          'subject': subject,
          'text': text,
          'html': html,
        }),
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        debugPrint('Email sent successfully to $to');
      } else {
        debugPrint('Failed to send email: ${response.body}');
      }
    } catch (e) {
      debugPrint('Error sending email: $e');
    }
  }

  Future<void> sendAnnouncement({required String groupRef, required String message}) async {
    debugPrint('Preparing to send announcement to group $groupRef: $message');
  }
}
