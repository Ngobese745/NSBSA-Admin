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
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <style>
        body { font-family: 'Segoe UI', Roboto, Helvetica, Arial, sans-serif; background-color: #f4f4f7; color: #333333; margin: 0; padding: 0; -webkit-font-smoothing: antialiased; }
        .wrapper { width: 100%; table-layout: fixed; background-color: #f4f4f7; padding-bottom: 40px; }
        .container { max-width: 600px; margin: 0 auto; background-color: #ffffff; border-radius: 8px; overflow: hidden; box-shadow: 0 4px 12px rgba(0,0,0,0.05); margin-top: 40px; }
        .header { background-color: #ffffff; padding: 40px 20px; text-align: center; border-bottom: 4px solid #D4AF37; }
        .logo { max-width: 180px; height: auto; }
        .content { padding: 40px 50px; line-height: 1.6; }
        h1 { color: #1a1a1a; font-size: 24px; margin-top: 0; font-weight: 700; }
        p { margin: 15px 0; color: #555555; }
        .credentials-box { background-color: #f9f9f9; border: 1px solid #eeeeee; border-radius: 8px; padding: 25px; margin: 30px 0; }
        .credential-row { margin-bottom: 15px; }
        .credential-row:last-child { margin-bottom: 0; }
        .label { font-size: 11px; text-transform: uppercase; letter-spacing: 1px; color: #999999; display: block; margin-bottom: 5px; font-weight: 600; }
        .value { font-family: 'Courier New', Courier, monospace; font-size: 18px; color: #D4AF37; font-weight: bold; }
        .button-container { text-align: center; margin-top: 35px; }
        .button { display: inline-block; padding: 18px 36px; background-color: #D4AF37; color: #ffffff !important; text-decoration: none; border-radius: 6px; font-weight: 700; font-size: 16px; transition: background-color 0.3s ease; }
        .important-note { font-size: 13px; color: #e67e22; background-color: #fff9f4; border-left: 3px solid #e67e22; padding: 10px 15px; margin: 25px 0; }
        .footer { padding: 30px; text-align: center; color: #aaaaaa; font-size: 12px; }
    </style>
</head>
<body>
    <div class="wrapper">
        <div class="container">
            <div class="header">
                <!-- Replace with actual hosted logo URL -->
                <img src="https://nsbsa.org.za/wp-content/uploads/2022/03/NSBSA-Logo-1.png" alt="NSBSA Logo" class="logo">
                <div style="font-size: 10px; color: #D4AF37; letter-spacing: 2px; margin-top: 10px; font-weight: bold;">ADMINISTRATIVE PLATFORM</div>
            </div>
            <div class="content">
                <h1>Welcome, $fullName</h1>
                <p>An administrative account has been provisioned for you on the NSBSA Platform. Please use the secure credentials below to access your dashboard.</p>
                
                <div class="credentials-box">
                    <div class="credential-row">
                        <span class="label">Username / Email</span>
                        <span class="value">$toEmail</span>
                    </div>
                    <div class="credential-row">
                        <span class="label">Temporary Password</span>
                        <span class="value">$tempPassword</span>
                    </div>
                </div>

                <div class="important-note">
                    <strong>Security Requirement:</strong> You will be prompted to create a permanent password immediately upon your first login.
                </div>

                <div class="button-container">
                    <a href="https://nsbsa-admin.vercel.app" class="button">Access Platform</a>
                </div>
            </div>
            <div class="footer">
                <p>&copy; 2024 National Small Business Support Agency (NSBSA). All rights reserved.</p>
                <p>This is an automated administrative notification. Please do not reply to this email.</p>
            </div>
        </div>
    </div>
</body>
</html>
''';

    await _client.from('email_outbox').insert({
      'to_email': toEmail,
      'subject': 'Your NSBSA Admin Credentials',
      'html_content': htmlTemplate,
    });
  }

  Future<void> sendAnnouncement({required String groupRef, required String message}) async {
    debugPrint('Preparing to send announcement to group $groupRef: $message');
  }
}
