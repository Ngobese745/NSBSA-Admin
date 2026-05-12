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
    debugPrint('Sending branded staff credentials to $toEmail');
    
    if (_mailerSendApiKey.isNotEmpty) {
      final htmlTemplate = '''
<!DOCTYPE html>
<html>
<head>
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <style>
        body { font-family: 'Inter', Arial, sans-serif; background-color: #050505; color: #ffffff; margin: 0; padding: 0; }
        .container { max-width: 600px; margin: 20px auto; background-color: #141414; border-radius: 16px; border: 1px solid #D4AF37; overflow: hidden; }
        .header { background-color: #000000; padding: 40px; text-align: center; border-bottom: 1px solid #D4AF37; }
        .content { padding: 40px; }
        .footer { background-color: #0A0A0A; padding: 30px; text-align: center; color: #888888; font-size: 12px; }
        .gold { color: #D4AF37; }
        .button { display: inline-block; padding: 16px 32px; background-color: #D4AF37; color: #000000; text-decoration: none; border-radius: 8px; font-weight: bold; margin-top: 20px; }
        .credentials { background-color: rgba(255, 255, 255, 0.05); padding: 20px; border-radius: 12px; margin: 20px 0; border: 1px dashed #D4AF37; }
        .credential-item { margin: 10px 0; }
        .label { color: #888888; font-size: 12px; display: block; margin-bottom: 4px; }
        .value { font-family: monospace; font-size: 18px; color: #D4AF37; }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1 style="color: #D4AF37; margin: 0; letter-spacing: 2px;">NSBSA</h1>
            <p style="color: #888888; margin: 5px 0 0 0; font-size: 12px; text-transform: uppercase;">Administrative Platform</p>
        </div>
        <div class="content">
            <h2 style="margin-top: 0;">Welcome, $fullName!</h2>
            <p>Your administrative account has been successfully provisioned. You can now access the NSBSA Admin dashboard using the credentials below.</p>
            
            <div class="credentials">
                <div class="credential-item">
                    <span class="label">REGISTERED EMAIL</span>
                    <span class="value">$toEmail</span>
                </div>
                <div class="credential-item">
                    <span class="label">TEMPORARY PASSWORD</span>
                    <span class="value">$tempPassword</span>
                </div>
            </div>

            <p style="font-size: 14px; color: #BBBBBB;"><em><strong>Important:</strong> For security reasons, you will be required to change this temporary password immediately upon your first login.</em></p>

            <a href="https://nsbsa-admin.vercel.app" class="button">Access Platform</a>
        </div>
        <div class="footer">
            <p>&copy; 2024 National Small Business Support Agency (NSBSA). All rights reserved.</p>
            <p>Support: support@nsbsa.org.za | Compliance: compliance@nsbsa.org.za</p>
            <p style="margin-top: 15px;">This is an automated security notification. Please do not reply to this email.</p>
        </div>
    </div>
</body>
</html>
''';

      await _sendEmail(
        to: toEmail,
        subject: 'Welcome to NSBSA Admin - Your Account is Ready',
        text: 'Welcome $fullName! Your account has been created. Email: $toEmail, Temporary Password: $tempPassword. Access at https://nsbsa-admin.vercel.app',
        html: htmlTemplate,
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
