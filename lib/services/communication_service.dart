import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CommunicationService {
  final _client = Supabase.instance.client;

  Future<void> sendPaymentReminder({required String toEmail, required String toPhone, required String amount}) async {
    debugPrint('Queuing payment reminder for $amount');
    
    await _client.from('email_outbox').insert({
      'to_email': toEmail,
      'subject': 'Payment Reminder - NSBSA',
      'html_content': '<p>Dear member,</p><p>This is a reminder for your upcoming payment of <strong>$amount</strong>.</p><p>Please ensure funds are available.</p>',
    });
  }

  /// Queues temporary credentials to a new staff member via the Database Outbox.
  /// This bypasses CORS issues in Flutter Web by letting Supabase handle the HTTP call.
  Future<void> sendStaffCredentials({
    required String toEmail,
    required String fullName,
    required String tempPassword,
  }) async {
    debugPrint('Queuing branded staff credentials for $toEmail');
    
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

    await _client.from('email_outbox').insert({
      'to_email': toEmail,
      'subject': 'Welcome to NSBSA Admin - Your Account is Ready',
      'html_content': htmlTemplate,
    });
  }

  Future<void> sendAnnouncement({required String groupRef, required String message}) async {
    debugPrint('Preparing to send announcement to group $groupRef: $message');
  }
}
