import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/vendor.dart';
import '../models/savings_history.dart';
import 'pdf_service.dart';
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

  /// Sends a manual WhatsApp document to a vendor and logs it.
  Future<bool> sendManualWhatsAppDocument({
    required String vendorId,
    required String toWhatsApp,
    required String documentUrl,
    String? filename,
    String? caption,
    bool includeFooter = true,
  }) async {
    try {
      final logResponse = await _client.from('communication_logs').insert({
        'vendor_id': vendorId,
        'channel': 'WhatsApp (Document)',
        'recipient': toWhatsApp,
        'content': caption ?? 'PDF Document: ${filename ?? documentUrl}',
        'status': 'pending',
      }).select().single();

      final logId = logResponse['id'];

      final success = await _whatsappService.sendWhatsAppDocument(
        to: toWhatsApp,
        documentUrl: documentUrl,
        filename: filename,
        caption: caption,
        includeFooter: includeFooter,
      );

      await _client.from('communication_logs').update({
        'status': success ? 'sent' : 'failed',
        if (!success) 'error_message': 'WhatsApp document delivery failed',
      }).eq('id', logId);

      return success;
    } catch (e) {
      debugPrint('Error sending manual WhatsApp document: $e');
      return false;
    }
  }

  /// Sends a manual WhatsApp to a vendor and logs it.
  ///
  /// Set [includeFooter] to `false` to suppress the NSBSA contact footer
  /// for very short transactional messages.
  Future<bool> sendManualWhatsApp({
    required String vendorId,
    required String toWhatsApp,
    required String content,
    bool includeFooter = true,
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

      // Header/footer are applied automatically by WeSenderService.
      final success = await _whatsappService.sendWhatsApp(
        to: toWhatsApp,
        message: content,
        includeFooter: includeFooter,
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
      final whatsappContent =
          'Dear *$vendorName*,\n\n'
          'Your payment of *R$amount* has been successfully received on *$date*.\n\n'
          '🧾 *Reference:* $transactionId\n'
          '💳 *Payment Method:* $paymentMethod\n\n'
          'Thank you for your continued partnership with NSBSA.';
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

  Future<void> sendGroupWelcomeNotification({
    required String vendorId,
    required String vendorName,
    required String toEmail,
    required String toPhone,
    required String toWhatsApp,
    required String groupName,
    required String groupRef,
    required String centerName,
    required String memberRole,
  }) async {
    debugPrint('Queuing group welcome notification for $vendorName (Group: $groupName)');

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
        .info-table { width: 100%; border-collapse: collapse; margin: 25px 0; background-color: #0D1117; border-radius: 8px; overflow: hidden; border: 1px solid #30363D; }
        .info-table th, .info-table td { padding: 15px 20px; text-align: left; border-bottom: 1px solid #1F242D; }
        .info-table th { color: #8B949E; font-weight: normal; font-size: 14px; width: 40%; }
        .info-table td { color: #FFFFFF; font-weight: bold; font-size: 14px; }
        .info-table tr:last-child th, .info-table tr:last-child td { border-bottom: none; }
        .footer { padding: 30px; text-align: center; color: #484F58; font-size: 12px; background-color: #0D1117; border-top: 1px solid #30363D; }
        .footer a { color: #D4AF37; text-decoration: none; }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <img src="https://www.stokvelbody.org.za/wp-content/uploads/2019/05/logo02.png" alt="NSBSA Logo" class="logo">
            <div class="tagline">Empowering Communities</div>
        </div>
        <div class="content">
            <p>Dear <strong>$vendorName</strong>,</p>
            <p>You have been successfully added to a new NSBSA Group. Please find your group details below.</p>
            
            <table class="info-table">
                <tr>
                    <th>Group Name</th>
                    <td>$groupName</td>
                </tr>
                <tr>
                    <th>Group Ref</th>
                    <td>$groupRef</td>
                </tr>
                <tr>
                    <th>Center</th>
                    <td>$centerName</td>
                </tr>
                <tr>
                    <th>Your Role</th>
                    <td>$memberRole</td>
                </tr>
            </table>

            <p>Welcome to the group! Together, we strive to build stronger financial futures.</p>
        </div>
        <div class="footer">
            <p><strong>Contact NSBSA</strong><br>Email: info@nsbsa.org.za<br>Phone: 087 107 7524<br>WhatsApp: 087 107 7524<br>Website: <a href="https://www.stokvelbody.org.za">https://www.stokvelbody.org.za</a></p>
        </div>
    </div>
</body>
</html>
''';

    if (toEmail.isNotEmpty) {
      await sendManualEmail(
        vendorId: vendorId,
        toEmail: toEmail,
        subject: 'You have been added to a new NSBSA Group',
        content: emailHtml,
        isRawHtml: true,
      );
    }

    // WhatsApp
    final whatsappNumber = toWhatsApp.isNotEmpty ? toWhatsApp : toPhone;
    if (whatsappNumber.isNotEmpty) {
      final whatsappContent =
          'Dear *$vendorName*,\n\n'
          'You have been successfully added to a new NSBSA Group.\n\n'
          '📌 *Group Name:* $groupName\n'
          '🧾 *Group Ref:* $groupRef\n'
          '🏢 *Center:* $centerName\n'
          '👤 *Your Role:* $memberRole\n\n'
          'Welcome to the group!';
      await sendManualWhatsApp(
        vendorId: vendorId,
        toWhatsApp: whatsappNumber,
        content: whatsappContent,
      );
    }

    // SMS
    if (toPhone.isNotEmpty) {
      final smsContent =
          'NSBSA: Welcome $vendorName! You are added to Group $groupName ($groupRef) at Center $centerName. Role: $memberRole.\n\n'
          'Contact NSBSA\n'
          'Email: info@nsbsa.org.za\n'
          'Phone/WA: 087 107 7524\n'
          'Web: www.stokvelbody.org.za';
      await sendManualSMS(
        vendorId: vendorId,
        toPhone: toPhone,
        content: smsContent,
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

  Future<void> sendPaymentNotification({
    required String vendorId,
    required String vendorName,
    required String toEmail,
    required String toPhone,
    required String toWhatsApp,
    required String loanRef,
    required double amountPaid,
    required double balanceRemaining,
    required String groupName,
    required String centerName,
    required DateTime date,
    required Uint8List pdfBytes,
  }) async {
    final dateStr = '${date.day} ${_getMonthName(date.month)} ${date.year}';
    final fileName = 'receipt_${loanRef}_${DateTime.now().millisecondsSinceEpoch}.pdf';
    final filePath = 'receipts/$fileName';

    debugPrint('Queuing payment notification for $vendorName (Loan: $loanRef)');

    // 1. Upload PDF to Supabase Storage (temporarily)
    String? pdfUrl;
    try {
      await _client.storage.from('documents').uploadBinary(filePath, pdfBytes);
      pdfUrl = _client.storage.from('documents').getPublicUrl(filePath);
    } catch (e) {
      debugPrint('Error uploading PDF receipt: $e');
    }

    // 2. Email (Branded HTML + PDF attachment via link or manual logic)
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
        .info-table { width: 100%; border-collapse: collapse; margin: 25px 0; background-color: #0D1117; border-radius: 8px; overflow: hidden; border: 1px solid #30363D; }
        .info-table th, .info-table td { padding: 15px 20px; text-align: left; border-bottom: 1px solid #1F242D; }
        .info-table th { color: #8B949E; font-weight: normal; font-size: 14px; width: 45%; }
        .info-table td { color: #FFFFFF; font-weight: bold; font-size: 14px; }
        .info-table tr:last-child th, .info-table tr:last-child td { border-bottom: none; }
        .receipt-btn { display: inline-block; padding: 15px 30px; background-color: #D4AF37; color: #000000 !important; text-decoration: none; border-radius: 8px; font-weight: bold; margin-top: 20px; }
        .footer { padding: 30px; text-align: center; color: #484F58; font-size: 12px; background-color: #0D1117; border-top: 1px solid #30363D; }
        .footer a { color: #D4AF37; text-decoration: none; }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <img src="https://www.stokvelbody.org.za/wp-content/uploads/2019/05/logo02.png" alt="NSBSA Logo" class="logo">
            <div class="tagline">Empowering Communities</div>
        </div>
        <div class="content">
            <p>Dear <strong>$vendorName</strong>,</p>
            <p>Your payment has been successfully recorded. Thank you for your payment towards your NSBSA loan.</p>
            
            <table class="info-table">
                <tr><th>Loan Ref</th><td>$loanRef</td></tr>
                <tr><th>Amount Paid</th><td>R$amountPaid</td></tr>
                <tr><th>Remaining Balance</th><td>R$balanceRemaining</td></tr>
                <tr><th>Payment Date</th><td>$dateStr</td></tr>
                <tr><th>Group / Center</th><td>$groupName / $centerName</td></tr>
            </table>

            ${pdfUrl != null ? '<p>Please find your official payment receipt below:</p><a href="$pdfUrl" class="receipt-btn">Download Payment Slip (PDF)</a>' : ''}

            <p style="margin-top: 30px; font-size: 12px; color: #8B949E;">* Please note: Initiation Fee (R150) and Admin Fee (R65) apply. A penalty is applied if payment is missed by 20 days.</p>
        </div>
        <div class="footer">
            <p><strong>Contact NSBSA</strong><br>Email: info@nsbsa.org.za<br>Phone: 087 107 7524<br>WhatsApp: 087 107 7524<br>Website: <a href="https://www.stokvelbody.org.za">https://www.stokvelbody.org.za</a></p>
        </div>
    </div>
</body>
</html>
''';

    if (toEmail.isNotEmpty) {
      await sendManualEmail(
        vendorId: vendorId,
        toEmail: toEmail,
        subject: 'Payment Received - $loanRef',
        content: emailHtml,
        isRawHtml: true,
      );
    }

    // 3. WhatsApp (Document if PDF exists, otherwise message)
    final whatsappNumber = toWhatsApp.isNotEmpty ? toWhatsApp : toPhone;
    if (whatsappNumber.isNotEmpty) {
      final whatsappContent =
          'Dear *$vendorName*,\n\n'
          'Your payment of *R$amountPaid* has been successfully received for Loan *$loanRef*.\n\n'
          '📉 *New Balance:* R$balanceRemaining\n'
          '📅 *Date:* $dateStr\n'
          '👥 *Group:* $groupName\n\n'
          'Thank you for your payment. NSBSA | Empowering Communities';

      if (pdfUrl != null) {
        await sendManualWhatsAppDocument(
          vendorId: vendorId,
          toWhatsApp: whatsappNumber,
          documentUrl: pdfUrl,
          filename: fileName,
          caption: whatsappContent,
        );
      } else {
        await sendManualWhatsApp(
          vendorId: vendorId,
          toWhatsApp: whatsappNumber,
          content: whatsappContent,
        );
      }
    }

    // 4. SMS (Concise ≤ 160 chars)
    if (toPhone.isNotEmpty) {
      final smsContent =
          'NSBSA: Payment of R$amountPaid received for Loan Ref#$loanRef. New Balance: R$balanceRemaining. Thank you.';
      await sendManualSMS(
        vendorId: vendorId,
        toPhone: toPhone,
        content: smsContent,
      );
    }

    // 5. Cleanup: Remove PDF after small delay to allow for delivery
    Future.delayed(const Duration(minutes: 10), () async {
      try {
        await _client.storage.from('documents').remove([filePath]);
        debugPrint('Cleaned up payment receipt: $filePath');
      } catch (e) {
        debugPrint('Error cleaning up receipt: $e');
      }
    });
  }

  Future<void> sendLoanCreationNotification({
    required String vendorId,
    required String vendorName,
    required String toEmail,
    required String toPhone,
    required String toWhatsApp,
    required String loanRef,
    required double amount,
    required String groupName,
    required String centerName,
    required DateTime date,
    required int durationMonths,
    DateTime? nextPaymentDate,
    double? initiationFee,
    double? monthlyAdminFee,
  }) async {
    final dateStr = '${date.day} ${_getMonthName(date.month)} ${date.year}';
    final nextPayStr = nextPaymentDate != null
        ? '${nextPaymentDate.day} ${_getMonthName(nextPaymentDate.month)} ${nextPaymentDate.year}'
        : 'To be confirmed';

    debugPrint('Queuing loan creation notification for $vendorName (Loan: $loanRef)');

    // 1. Email (Branded HTML)
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
        .info-table { width: 100%; border-collapse: collapse; margin: 25px 0; background-color: #0D1117; border-radius: 8px; overflow: hidden; border: 1px solid #30363D; }
        .info-table th, .info-table td { padding: 15px 20px; text-align: left; border-bottom: 1px solid #1F242D; }
        .info-table th { color: #8B949E; font-weight: normal; font-size: 14px; width: 45%; }
        .info-table td { color: #FFFFFF; font-weight: bold; font-size: 14px; }
        .info-table tr:last-child th, .info-table tr:last-child td { border-bottom: none; }
        .fee-note { font-size: 12px; color: #8B949E; margin-top: 20px; padding: 15px; border-left: 3px solid #D4AF37; background-color: #0D1117; }
        .footer { padding: 30px; text-align: center; color: #484F58; font-size: 12px; background-color: #0D1117; border-top: 1px solid #30363D; }
        .footer a { color: #D4AF37; text-decoration: none; }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <img src="https://www.stokvelbody.org.za/wp-content/uploads/2019/05/logo02.png" alt="NSBSA Logo" class="logo">
            <div class="tagline">Empowering Communities</div>
        </div>
        <div class="content">
            <p>Dear <strong>$vendorName</strong>,</p>
            <p>A new loan has been successfully created for you. Please find the details and payment schedule below.</p>
            
            <table class="info-table">
                <tr><th>Loan Ref</th><td>$loanRef</td></tr>
                <tr><th>Amount</th><td>R$amount</td></tr>
                <tr><th>Duration</th><td>$durationMonths Months</td></tr>
                <tr><th>First Payment</th><td>$nextPayStr</td></tr>
                <tr><th>Initiation Fee</th><td>R${initiationFee ?? 150.0}</td></tr>
                <tr><th>Admin Fee</th><td>R${monthlyAdminFee ?? 65.0} (Monthly)</td></tr>
                <tr><th>Group</th><td>$groupName</td></tr>
                <tr><th>Center</th><td>$centerName</td></tr>
            </table>

            <div class="fee-note">
                <strong>Penalty Notice:</strong> A penalty fee is applied to your account if any payment is missed by 20 days or more from the scheduled date.
            </div>

            <p>Thank you for being a valued member of NSBSA.</p>
        </div>
        <div class="footer">
            <p><strong>Contact NSBSA</strong><br>Email: info@nsbsa.org.za<br>Phone: 087 107 7524<br>WhatsApp: 087 107 7524<br>Website: <a href="https://www.stokvelbody.org.za">https://www.stokvelbody.org.za</a></p>
        </div>
    </div>
</body>
</html>
''';

    if (toEmail.isNotEmpty) {
      await sendManualEmail(
        vendorId: vendorId,
        toEmail: toEmail,
        subject: 'Loan Confirmation - $loanRef',
        content: emailHtml,
        isRawHtml: true,
      );
    }

    // 2. WhatsApp (Branded)
    final whatsappNumber = toWhatsApp.isNotEmpty ? toWhatsApp : toPhone;
    if (whatsappNumber.isNotEmpty) {
      final whatsappContent =
          'Dear *$vendorName*,\n\n'
          'A new loan has been successfully created for you.\n\n'
          '🧾 *Loan Ref:* $loanRef\n'
          '💰 *Amount:* R$amount\n'
          '📅 *Duration:* $durationMonths Months\n'
          '🗓️ *First Payment:* $nextPayStr\n'
          '💸 *Initiation Fee:* R${initiationFee ?? 150.0}\n'
          '⚙️ *Admin Fee:* R${monthlyAdminFee ?? 65.0} (pm)\n'
          '👥 *Group:* $groupName\n'
          '🏢 *Center:* $centerName\n\n'
          '⚠️ *Penalty Notice:* Applied when payment is missed by 20 days.\n\n'
          'Thank you for your trust in NSBSA.';
      await sendManualWhatsApp(
        vendorId: vendorId,
        toWhatsApp: whatsappNumber,
        content: whatsappContent,
      );
    }

    // 3. SMS (Concise ≤ 160 chars)
    if (toPhone.isNotEmpty) {
      final smsContent =
          'NSBSA: Loan $loanRef (R$amount) created. Term: $durationMonths mos. 1st Pay: $nextPayStr. Fees: R150 init, R65 admin. Penalty applied after 20 days late.';
      await sendManualSMS(
        vendorId: vendorId,
        toPhone: toPhone,
        content: smsContent,
      );
    }
  }

  // --- HELPERS ---

  String _getMonthName(int month) {
    const months = [
      '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return months[month];
  }

  Future<void> sendSavingsTransactionNotification({
    required VendorModel vendor,
    required SavingsHistoryModel history,
    required String groupName,
    required String centerName,
    required List<SavingsHistoryModel> recentHistory,
  }) async {
    debugPrint('Queuing savings notification for ${vendor.name} (R${history.amount})');

    final date = history.createdAt;
    final dateStr = '${date.day} ${_getMonthName(date.month)} ${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.min.toString().padLeft(2, '0')}';
    final fileName = 'profile_${vendor.id}_${DateTime.now().millisecondsSinceEpoch}.pdf';
    final filePath = 'profiles/$fileName';

    // 1. Generate PDF Profile
    Uint8List? pdfBytes;
    String? pdfUrl;
    try {
      pdfBytes = await PdfService.generateVendorProfilePdf(
        memberName: vendor.name,
        idNumber: vendor.idNumber ?? '-',
        phone: vendor.phone ?? '-',
        email: vendor.email ?? '-',
        address: vendor.address ?? '-',
        groupName: groupName,
        centerName: centerName,
        currentBalance: history.newBalance,
        savingsHistory: recentHistory.map((h) => {
          'createdAt': h.createdAt,
          'actionType': h.actionType,
          'amount': h.amount,
          'newBalance': h.newBalance,
        }).toList(),
      );

      // Upload to storage
      await _client.storage.from('documents').uploadBinary(filePath, pdfBytes);
      pdfUrl = _client.storage.from('documents').getPublicUrl(filePath);
    } catch (e) {
      debugPrint('Error generating/uploading vendor profile PDF: $e');
    }

    // 2. Prepare Messages
    final whatsappNumber = vendor.whatsappNumber ?? vendor.phone ?? '';
    final toPhone = vendor.phone ?? '';
    final toEmail = vendor.email ?? '';

    final amountStr = 'R${history.amount.toStringAsFixed(2)}';
    final balanceStr = 'R${history.newBalance.toStringAsFixed(2)}';

    // 2a. SMS (Concise <= 160 chars)
    if (toPhone.isNotEmpty) {
      final smsContent = 'NSBSA: Your savings balance updated (R${history.amount} ${history.actionType}). New Balance: $balanceStr. Ref#${history.id.substring(0, 8)}. Check profile for details.';
      await sendManualSMS(vendorId: vendor.id, toPhone: toPhone, content: smsContent);
    }

    // 2b. WhatsApp (Document + Caption)
    if (whatsappNumber.isNotEmpty) {
      final whatsappCaption = 
          'Dear *${vendor.name}*,\n\n'
          'Your savings account has been updated with a *${history.actionType}*.\n\n'
          '💰 *Amount:* $amountStr\n'
          '📈 *Updated Balance:* $balanceStr\n'
          '📅 *Date:* $dateStr\n'
          '🏢 *Center:* $centerName\n\n'
          'Please find your updated profile and history attached.\n\n'
          'Thank you for your continued partnership with NSBSA.';

      if (pdfUrl != null) {
        await sendManualWhatsAppDocument(
          vendorId: vendor.id,
          toWhatsApp: whatsappNumber,
          documentUrl: pdfUrl,
          filename: 'NSBSA_Profile_${vendor.name.replaceAll(' ', '_')}.pdf',
          caption: whatsappCaption,
        );
      } else {
        await sendManualWhatsApp(
          vendorId: vendor.id,
          toWhatsApp: whatsappNumber,
          content: whatsappCaption,
        );
      }
    }

    // 2c. Email (Branded HTML + PDF link)
    if (toEmail.isNotEmpty) {
      final emailContent = '''
        <p>Dear <strong>${vendor.name}</strong>,</p>
        <p>This notification confirms a new transaction on your NSBSA savings account.</p>
        <div style="background-color: #0D1117; border: 1px solid #30363D; border-radius: 12px; padding: 25px; margin: 25px 0;">
            <table style="width: 100%; border-collapse: collapse;">
                <tr><td style="color: #8B949E; padding: 5px 0;">Transaction Type:</td><td style="color: #FFFFFF; font-weight: bold; text-align: right;">${history.actionType}</td></tr>
                <tr><td style="color: #8B949E; padding: 5px 0;">Amount:</td><td style="color: #FFFFFF; font-weight: bold; text-align: right;">$amountStr</td></tr>
                <tr><td style="color: #8B949E; padding: 5px 0;">Updated Balance:</td><td style="color: #D4AF37; font-weight: bold; text-align: right; font-size: 18px;">$balanceStr</td></tr>
                <tr><td style="color: #8B949E; padding: 5px 0;">Date/Time:</td><td style="color: #FFFFFF; text-align: right;">$dateStr</td></tr>
            </table>
        </div>
        ${pdfUrl != null ? '<p>You can download your full vendor profile and savings history report using the button below:</p><div style="text-align: center; margin: 30px 0;"><a href="$pdfUrl" style="display: inline-block; padding: 15px 30px; background-color: #D4AF37; color: #000000; text-decoration: none; border-radius: 8px; font-weight: bold;">Download Profile Report (PDF)</a></div>' : ''}
        <p style="font-size: 12px; color: #8B949E; margin-top: 30px;">This is an automated notification. For any discrepancies, please contact your group administrator or center manager.</p>
      ''';

      await sendManualEmail(
        vendorId: vendor.id,
        toEmail: toEmail,
        subject: 'Savings Transaction Notification - ${history.actionType}',
        content: emailContent,
        isRawHtml: true,
      );
    }

    // 3. Cleanup: Remove PDF after 10 minutes
    Future.delayed(const Duration(minutes: 10), () async {
      try {
        await _client.storage.from('documents').remove([filePath]);
        debugPrint('Cleaned up vendor profile PDF: $filePath');
      } catch (e) {
        debugPrint('Error cleaning up profile PDF: $e');
      }
    });
  }

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
