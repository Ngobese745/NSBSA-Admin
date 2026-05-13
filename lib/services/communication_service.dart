import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'smsworx_service.dart';
import 'wesender_service.dart';

class CommunicationService {
  final _client = Supabase.instance.client;
  final _smsService = SMSWorxService();
  final _whatsappService = WeSenderService();

  // --- MANUAL MESSAGING METHODS ---

  /// Sends a manual email to a vendor and logs it.
  Future<bool> sendManualEmail({
    required String vendorId,
    required String toEmail,
    required String subject,
    required String content,
    bool isRawHtml = false,
  }) async {
    try {
      // 1. Create Log entry
      final logResponse = await _client.from('communication_logs').insert({
        'vendor_id': vendorId,
        'channel': 'Email',
        'recipient': toEmail,
        'subject': subject,
        'content': isRawHtml ? 'Receipt sent (View email for details)' : content,
        'status': 'pending',
      }).select().single();

      final logId = logResponse['id'];

      // 2. Queue for MailerSend via email_outbox
      await _client.from('email_outbox').insert({
        'to_email': toEmail,
        'subject': subject,
        'html_content': isRawHtml ? content : _wrapInBrandedTemplate(content),
        'log_id': logId,
      });

      return true;
    } catch (e) {
      debugPrint('Error sending manual email: $e');
      return false;
    }
  }

  /// Sends a manual WhatsApp to a vendor and logs it.
  Future<bool> sendManualWhatsApp({
    required String vendorId,
    required String toWhatsApp,
    required String content,
  }) async {
    try {
      final logResponse = await _client.from('communication_logs').insert({
        'vendor_id': vendorId,
        'channel': 'WhatsApp',
        'recipient': toWhatsApp,
        'content': content,
        'status': 'pending',
      }).select().single();

      final logId = logResponse['id'];

      // WhatsApp disclaimer as requested
      final fullContent = '$content\n\n_This message is automated. Please do not reply._';

      final success = await _whatsappService.sendWhatsApp(
        to: toWhatsApp,
        message: fullContent,
      );

      await _client.from('communication_logs').update({
        'status': success ? 'sent' : 'failed',
        if (!success) 'error_message': 'WhatsApp delivery failed',
      }).eq('id', logId);

      return success;
    } catch (e) {
      debugPrint('Error sending manual WhatsApp: $e');
      return false;
    }
  }

  /// Sends a manual SMS to a vendor and logs it.
  Future<bool> sendManualSMS({
    required String vendorId,
    required String toPhone,
    required String content,
  }) async {
    try {
      final logResponse = await _client.from('communication_logs').insert({
        'vendor_id': vendorId,
        'channel': 'SMS',
        'recipient': toPhone,
        'content': content,
        'status': 'pending',
      }).select().single();

      final logId = logResponse['id'];

      final success = await _smsService.sendSMS(
        destination: toPhone,
        message: content,
      );

      await _client.from('communication_logs').update({
        'status': success ? 'sent' : 'failed',
        if (!success) 'error_message': 'SMS delivery failed',
      }).eq('id', logId);

      return success;
    } catch (e) {
      debugPrint('Error sending manual SMS: $e');
      return false;
    }
  }

  /// Fetches communication history for a specific vendor.
  Future<List<Map<String, dynamic>>> fetchCommunicationHistory(String vendorId) async {
    try {
      final response = await _client
          .from('communication_logs')
          .select()
          .eq('vendor_id', vendorId)
          .order('created_at', ascending: false);
      
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error fetching communication history: $e');
      return [];
    }
  }

  // --- AUTOMATED NOTIFICATIONS ---

  Future<void> sendPaymentConfirmation({
    required String vendorId,
    required String vendorName,
    required String toEmail,
    required String toPhone,
    required String toWhatsApp,
    required String amount,
    required String transactionId,
    required String date,
    required String paymentMethod,
  }) async {
    debugPrint('Queuing payment confirmation for $vendorName (R$amount)');

    // 1. Email (MailerSend)
    if (toEmail.isNotEmpty) {
      final emailHtml = '''
<!DOCTYPE html>
<html>
<head>
    <meta charset="utf-8">
    <style>
        body { font-family: 'Inter', sans-serif; background-color: #0A0E14; color: #E6E6E6; margin: 0; padding: 0; }
        .container { max-width: 600px; margin: 40px auto; background-color: #161B22; border-radius: 16px; overflow: hidden; border: 1px solid #30363D; }
        .header { background-color: #0D1117; padding: 40px; text-align: center; border-bottom: 2px solid #D4AF37; }
        .logo { max-width: 120px; }
        .tagline { font-size: 12px; color: #D4AF37; letter-spacing: 1px; margin-top: 10px; text-transform: uppercase; }
        .content { padding: 40px 50px; line-height: 1.8; color: #B1BAC4; }
        .receipt-table { width: 100%; border-collapse: collapse; margin: 25px 0; background-color: #0D1117; border-radius: 8px; overflow: hidden; border: 1px solid #30363D; }
        .receipt-table th, .receipt-table td { padding: 15px 20px; text-align: left; border-bottom: 1px solid #1F242D; }
        .receipt-table th { color: #8B949E; font-weight: normal; font-size: 14px; width: 40%; }
        .receipt-table td { color: #FFFFFF; font-weight: bold; font-size: 14px; }
        .receipt-table tr:last-child th, .receipt-table tr:last-child td { border-bottom: none; }
        .footer { padding: 30px; text-align: center; color: #484F58; font-size: 12px; background-color: #0D1117; border-top: 1px solid #30363D; }
        .footer a { color: #D4AF37; text-decoration: none; }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <img src="https://www.stokvelbody.org.za/wp-content/uploads/2019/05/logo02.png" alt="NSBSA Logo" class="logo">
            <div class="tagline">Trusted Financial Services — Compliant & Secure</div>
        </div>
        <div class="content">
            <p>Dear <strong>$vendorName</strong>,</p>
            <p>We confirm that your payment has been successfully recorded in our system.</p>
            
            <table class="receipt-table">
                <tr>
                    <th>Payment Date</th>
                    <td>$date</td>
                </tr>
                <tr>
                    <th>Amount Received</th>
                    <td>R$amount</td>
                </tr>
                <tr>
                    <th>Reference Number</th>
                    <td>$transactionId</td>
                </tr>
                <tr>
                    <th>Payment Method</th>
                    <td>$paymentMethod</td>
                </tr>
            </table>

            <p>Thank you for your continued partnership with NSBSA. This receipt serves as official confirmation of your transaction.</p>
        </div>
        <div class="footer">
            <p>NSBSA is a registered NCR provider. All transactions are logged for audit purposes.</p>
            <p>For queries, contact <a href="mailto:info@nsbsa.org.za">info@nsbsa.org.za</a></p>
        </div>
    </div>
</body>
</html>
''';

      await sendManualEmail(
        vendorId: vendorId,
        toEmail: toEmail,
        subject: 'Payment Confirmation Receipt - NSBSA',
        content: emailHtml,
        isRawHtml: true,
      );
    }

    // 2. WhatsApp (WeSenderAPI)
    final whatsappNumber = toWhatsApp.isNotEmpty ? toWhatsApp : toPhone;
    if (whatsappNumber.isNotEmpty) {
      final whatsappContent = 'Dear $vendorName, your payment of R$amount has been received on $date. Reference: $transactionId.';
      await sendManualWhatsApp(
        vendorId: vendorId,
        toWhatsApp: whatsappNumber,
        content: whatsappContent,
      );
    }

    // 3. SMS (SMSWORX)
    if (toPhone.isNotEmpty) {
      final smsContent = 'NSBSA: Payment of R$amount received on $date. Ref: $transactionId. Thank you.';
      await sendManualSMS(
        vendorId: vendorId,
        toPhone: toPhone,
        content: smsContent,
      );
    }
  }

  Future<void> sendPaymentReminder({
    required String vendorId,
    required String toEmail,
    required String toPhone,
    required String amount,
  }) async {
    debugPrint('Queuing payment reminder for $amount');

    final content = 'Dear member, this is a reminder for your upcoming payment of <strong>$amount</strong>. Please ensure funds are available.';

    // Log & Queue Email
    await sendManualEmail(
      vendorId: vendorId,
      toEmail: toEmail,
      subject: 'Payment Reminder - NSBSA',
      content: content,
    );

    // Log & Send SMS
    if (toPhone.isNotEmpty) {
      await sendManualSMS(
        vendorId: vendorId,
        toPhone: toPhone,
        content: 'Dear Member, reminder for your NSBSA payment of $amount. Please ensure funds are available. Thank you.',
      );
    }
  }

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
        body { font-family: 'Inter', -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif; background-color: #0A0E14; color: #E6E6E6; margin: 0; padding: 0; }
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
        .footer { padding: 40px; text-align: center; color: #7D8590; font-size: 13px; background-color: #0D1117; }
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
                    <div class="credential-row"><span class="label">Username / Email</span><span class="value">$toEmail</span></div>
                    <div class="credential-row"><span class="label">Temporary Password</span><span class="value">$tempPassword</span></div>
                </div>
                <div class="button-container"><a href="https://nsbsa-admin.vercel.app" class="button">Log In to Dashboard</a></div>
            </div>
            <div class="footer"><p>&copy; 2024 NSBSA. Confidential Administrative Communication.</p></div>
        </div>
    </div>
</body>
</html>
''';

    await _client.from('email_outbox').insert({
      'to_email': toEmail,
      'subject': 'Your NSBSA Admin Credentials',
      'html_content': htmlTemplate,
      'metadata': {'full_name': fullName, 'type': 'staff_invite'},
    });
  }

  Future<void> sendPasswordResetApproved({
    required String toEmail,
    required String tempPassword,
  }) async {
    debugPrint('Queuing password reset approval for $toEmail');

    final content = '''
      <h1>Password Reset Approved</h1>
      <p>Your request for a password reset has been reviewed and approved by an administrator.</p>
      <div style="background-color: #0D1117; border: 1px solid #30363D; border-radius: 12px; padding: 25px; margin: 30px 0; text-align: center;">
          <div style="font-size: 11px; text-transform: uppercase; letter-spacing: 1px; color: #8B949E; margin-bottom: 5px;">Temporary Password</div>
          <div style="font-family: monospace; font-size: 20px; color: #D4AF37; font-weight: bold;">$tempPassword</div>
      </div>
      <p style="color: #FF7B72; font-size: 14px;"><strong>Note:</strong> This password is valid for 24 hours. You will be required to change it immediately upon logging in.</p>
      <div style="text-align: center; margin-top: 30px;">
          <a href="https://nsbsa-admin.vercel.app" style="display: inline-block; padding: 16px 32px; background-color: #D4AF37; color: #000000; text-decoration: none; border-radius: 8px; font-weight: bold;">Log In & Secure Account</a>
      </div>
    ''';

    await _client.from('email_outbox').insert({
      'to_email': toEmail,
      'subject': 'Password Reset Approved - NSBSA',
      'html_content': _wrapInBrandedTemplate(content),
      'metadata': {'type': 'password_reset_approved'},
    });
  }

  Future<void> sendPasswordResetRejected({
    required String toEmail,
    String? reason,
  }) async {
    debugPrint('Queuing password reset rejection for $toEmail');

    final content = '''
      <h1>Password Reset Request Update</h1>
      <p>Your request for a password reset has been reviewed and could not be approved at this time.</p>
      <div style="background-color: #0D1117; border-left: 4px solid #FF7B72; padding: 20px; margin: 25px 0; font-style: italic; color: #B1BAC4;">
          "${reason ?? 'The request did not meet security verification requirements.'}"
      </div>
      <p>If you believe this is an error, please contact your department head or system administrator directly.</p>
    ''';

    await _client.from('email_outbox').insert({
      'to_email': toEmail,
      'subject': 'Password Reset Request Update - NSBSA',
      'html_content': _wrapInBrandedTemplate(content),
      'metadata': {'type': 'password_reset_rejected'},
    });
  }

  Future<void> sendAnnouncement({
    required String groupRef,
    required String message,
  }) async {
    debugPrint('Preparing to send announcement to group $groupRef: $message');
    try {
      final vendors = await _client.from('vendors').select('id, phone').eq('reference_number', groupRef);
      for (var vendor in vendors) {
        final phone = vendor['phone']?.toString();
        final vId = vendor['id']?.toString();
        if (phone != null && phone.isNotEmpty && vId != null) {
          await sendManualSMS(vendorId: vId, toPhone: phone, content: message);
        }
      }
    } catch (e) {
      debugPrint('Error sending group announcement: $e');
    }
  }

  // --- HELPERS ---

  String _wrapInBrandedTemplate(String content) {
    final formattedContent = content.replaceAll('\n', '<br>');
    return '''
<!DOCTYPE html>
<html>
<head>
    <meta charset="utf-8">
    <style>
        body { font-family: 'Inter', sans-serif; background-color: #0A0E14; color: #E6E6E6; margin: 0; padding: 0; }
        .container { max-width: 600px; margin: 40px auto; background-color: #161B22; border-radius: 16px; overflow: hidden; border: 1px solid #30363D; }
        .header { background-color: #0D1117; padding: 40px; text-align: center; border-bottom: 2px solid #D4AF37; }
        .logo { max-width: 120px; }
        .content { padding: 40px 50px; line-height: 1.8; color: #B1BAC4; white-space: pre-wrap; }
        .footer { padding: 30px; text-align: center; color: #484F58; font-size: 12px; background-color: #0D1117; }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <img src="https://www.stokvelbody.org.za/wp-content/uploads/2019/05/logo02.png" alt="NSBSA Logo" class="logo">
            <div style="font-size: 10px; color: #D4AF37; letter-spacing: 2px; margin-top: 5px; text-transform: uppercase;">Member Communication</div>
        </div>
        <div class="content">$formattedContent</div>
        <div class="footer"><p>&copy; 2024 NSBSA. Confidential Communication.</p></div>
    </div>
</body>
</html>
''';
  }
}
