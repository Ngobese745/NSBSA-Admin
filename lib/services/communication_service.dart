import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CommunicationService {
  final _client = Supabase.instance.client;

  Future<void> sendPaymentReminder({
    required String toEmail,
    required String toPhone,
    required String amount,
  }) async {
    debugPrint('Queuing payment reminder for $amount');

    await _client.from('email_outbox').insert({
      'to_email': toEmail,
      'subject': 'Payment Reminder - NSBSA',
      'html_content':
          '<p>Dear member,</p><p>This is a reminder for your upcoming payment of <strong>$amount</strong>.</p><p>Please ensure funds are available.</p>',
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

    final htmlTemplate =
        '''
<!DOCTYPE html>
<html>
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <style>
        body { font-family: 'Inter', -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif; background-color: #0A0E14; color: #E6E6E6; margin: 0; padding: 0; -webkit-font-smoothing: antialiased; }
        .wrapper { width: 100%; table-layout: fixed; background-color: #0A0E14; padding-bottom: 60px; }
        .container { max-width: 600px; margin: 0 auto; background-color: #161B22; border-radius: 16px; overflow: hidden; border: 1px solid #30363D; margin-top: 40px; }
        .header { background-color: #0D1117; padding: 50px 20px; text-align: center; border-bottom: 2px solid #D4AF37; }
        .logo { max-width: 140px; height: auto; margin-bottom: 15px; filter: drop-shadow(0 0 8px rgba(212, 175, 55, 0.3)); }
        .content { padding: 50px 60px; line-height: 1.8; }
        h1 { color: #FFFFFF; font-size: 28px; margin-top: 0; font-weight: 800; letter-spacing: -0.5px; }
        p { margin: 20px 0; color: #B1BAC4; font-size: 16px; }
        .credentials-box { background-color: #0D1117; border: 1px solid #30363D; border-radius: 12px; padding: 30px; margin: 35px 0; box-shadow: inset 0 2px 4px rgba(0,0,0,0.2); }
        .credential-row { margin-bottom: 20px; }
        .credential-row:last-child { margin-bottom: 0; }
        .label { font-size: 11px; text-transform: uppercase; letter-spacing: 1.5px; color: #8B949E; display: block; margin-bottom: 8px; font-weight: 700; }
        .value { font-family: 'Fira Code', 'Courier New', Courier, monospace; font-size: 18px; color: #D4AF37; font-weight: 700; word-break: break-all; }
        .button-container { text-align: center; margin-top: 45px; }
        .button { display: inline-block; padding: 18px 48px; background-color: #D4AF37; color: #000000 !important; text-decoration: none; border-radius: 8px; font-weight: 800; font-size: 16px; transition: transform 0.2s ease, background-color 0.3s ease; box-shadow: 0 4px 14px rgba(212, 175, 55, 0.4); }
        .important-note { font-size: 14px; color: #FF7B72; background-color: rgba(255, 123, 114, 0.1); border-left: 4px solid #FF7B72; padding: 15px 20px; border-radius: 0 8px 8px 0; margin: 30px 0; }
        .footer { padding: 40px; text-align: center; color: #7D8590; font-size: 13px; background-color: #0D1117; }
        .footer p { font-size: 12px; margin: 5px 0; color: #484F58; }
        @media only screen and (max-width: 600px) {
            .content { padding: 30px 25px; }
            h1 { font-size: 22px; }
            .container { margin-top: 20px; border-radius: 0; }
        }
    </style>
</head>
<body>
    <div class="wrapper">
        <div class="container">
            <div class="header">
                <img src="https://www.stokvelbody.org.za/wp-content/uploads/2019/05/logo02.png" alt="NSBSA Logo" class="logo">
                <div style="font-size: 11px; color: #D4AF37; letter-spacing: 3px; margin-top: 5px; font-weight: 800; text-transform: uppercase;">Administrative Platform</div>
            </div>
            <div class="content">
                <h1>Welcome, $fullName</h1>
                <p>An administrative account has been provisioned for you on the NSBSA Platform. Your access is now active and ready for use.</p>
                
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
                    <strong>Security Notice:</strong> For your protection, you will be required to create a unique permanent password immediately upon your first login.
                </div>

                <div class="button-container">
                    <a href="https://nsbsa-admin.vercel.app" class="button">Log In to Dashboard</a>
                </div>
            </div>
            <div class="footer">
                <p>&copy; 2024 National Small Business Support Agency (NSBSA).</p>
                <p>Confidential Administrative Communication • Do not reply to this email.</p>
                <div style="margin-top: 15px; border-top: 1px solid #30363D; padding-top: 15px; font-style: italic;">
                    Empowering Small Businesses through Excellence.
                </div>
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
      'metadata': {
        'full_name': fullName,
        'type': 'staff_invite',
      },
    });
  }

  Future<void> sendAnnouncement({
    required String groupRef,
    required String message,
  }) async {
    debugPrint('Preparing to send announcement to group $groupRef: $message');
  }
}
