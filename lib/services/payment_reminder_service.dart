import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/reminder_log.dart';
import 'smsworx_service.dart';
import 'wesender_service.dart';

/// Orchestrates the payment reminder workflow across Email, WhatsApp, and SMS.
///
/// Designed to be called by a cron job:
///   - 08:00 → [sendInitialReminders] — first notice for upcoming/overdue payments
///   - 18:00 → [sendFollowUpReminders] — escalated notice for vendors still unpaid
///
/// Each vendor with active loans and a positive balance is evaluated against
/// their first instalment / next due date. If the due date is today or past,
/// a reminder is dispatched over every available channel.
class PaymentReminderService {
  PaymentReminderService._();
  static final PaymentReminderService instance = PaymentReminderService._();

  final _supabase = Supabase.instance.client;
  final _smsService = SMSWorxService();
  final _whatsappService = WeSenderService();

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  /// 08:00 pass — send initial reminders to vendors with upcoming/overdue payments.
  Future<ReminderSummary> sendInitialReminders() async {
    debugPrint('[Reminder 08:00] Starting initial reminder pass...');
    return _processReminders(reminderType: 'initial');
  }

  /// 18:00 pass — send follow-up reminders to vendors still unpaid.
  Future<ReminderSummary> sendFollowUpReminders() async {
    debugPrint('[Reminder 18:00] Starting follow-up reminder pass...');
    return _processReminders(reminderType: 'follow_up');
  }

  // ---------------------------------------------------------------------------
  // Core logic
  // ---------------------------------------------------------------------------

  Future<ReminderSummary> _processReminders({
    required String reminderType,
  }) async {
    final summary = ReminderSummary();

    try {
      // 1. Find vendors with active loans and outstanding balances
      final dueVendors = await _fetchDueVendors();

      for (final row in dueVendors) {
        final vendorId = row['vendor_id'] as String;
        final vendorName = row['vendor_name'] as String;
        final vendorPhone = (row['vendor_phone'] as String?) ?? '';
        final vendorEmail = (row['vendor_email'] as String?) ?? '';
        final vendorWhatsApp = (row['vendor_whatsapp'] as String?) ?? '';
        final loanAmount = (row['loan_amount'] as num).toDouble();
        final balance = (row['balance'] as num).toDouble();
        final loanRef = (row['loan_ref'] as String?) ?? row['loan_id'] as String;
        final dueDate = row['due_date'] != null
            ? DateTime.parse(row['due_date'] as String)
            : DateTime.now();

        // Skip fully paid
        if (balance <= 0) continue;

        final logEntry = ReminderLogModel(
          id: '',
          vendorId: vendorId,
          vendorName: vendorName,
          vendorPhone: vendorPhone,
          vendorEmail: vendorEmail,
          vendorWhatsApp: vendorWhatsApp,
          loanAmount: loanAmount,
          balance: balance,
          loanRef: loanRef.substring(0, 8).toUpperCase(),
          dueDate: dueDate,
          reminderType: reminderType,
          channel: 'Email',
          status: 'pending',
          createdAt: DateTime.now(),
        );

        // 2. Send Email (queue via email_outbox)
        if (vendorEmail.isNotEmpty) {
          await _sendEmailReminder(logEntry, reminderType);
          summary.emailSent++;
        }

        // 3. Send WhatsApp
        final whatsappTarget = vendorWhatsApp.isNotEmpty ? vendorWhatsApp : vendorPhone;
        if (whatsappTarget.isNotEmpty) {
          await _sendWhatsAppReminder(logEntry, whatsappTarget, reminderType);
          summary.whatsappSent++;
        }

        // 4. Send SMS (max 160 chars)
        if (vendorPhone.isNotEmpty) {
          await _sendSmsReminder(logEntry, vendorPhone, reminderType);
          summary.smsSent++;
        }

        summary.totalVendors++;
      }
    } catch (e) {
      debugPrint('[Reminder] Error during pass: $e');
      summary.errors.add(e.toString());
    }

    debugPrint('[Reminder] Pass complete: $summary');
    return summary;
  }

  // ---------------------------------------------------------------------------
  // Queries
  // ---------------------------------------------------------------------------

  /// Fetches vendors with active loans where the balance > 0 and the
  /// payment is due (first_instalment_date <= now).
  Future<List<Map<String, dynamic>>> _fetchDueVendors() async {
    final today = DateTime.now();
    final todayStr = today.toIso8601String().substring(0, 10);

    // We query loans joined with vendors. A loan is "due" when:
    //   - status = 'Active'
    //   - first_instalment_date <= today
    //   - calculated balance > 0
    //
    // The balance calculation is done in Dart via LoanCalculationService,
    // but for the cron batch we use a Supabase view or inline query.
    // Here we use a raw query that returns all active loans with vendor info,
    // then filter by balance in Dart.
    final response = await _supabase.from('loans').select('''
      id,
      amount,
      first_instalment_date,
      status,
      group_id,
      vendor_id,
      vendors!inner(name, phone, email, whatsapp_number)
    ''').eq('status', 'Active');

    final now = DateTime.now();
    final results = <Map<String, dynamic>>[];

    for (final loan in response as List<dynamic>) {
      final loanMap = loan as Map<String, dynamic>;
      final vendorData = loanMap['vendors'] as Map<String, dynamic>;

      final firstDate = loanMap['first_instalment_date'] != null
          ? DateTime.parse(loanMap['first_instalment_date'] as String)
          : null;

      // Only include if due date exists and is today or past
      if (firstDate == null || firstDate.isAfter(now)) continue;

      // Fetch payments for this loan to calculate balance
      final paymentsRes = await _supabase
          .from('payments')
          .select('amount_paid')
          .eq('loan_id', loanMap['id'] as String);

      final totalPaid = (paymentsRes as List).fold<double>(
        0,
        (sum, p) => sum + ((p as Map)['amount_paid'] as num).toDouble(),
      );

      final balance = (loanMap['amount'] as num).toDouble() - totalPaid;
      if (balance <= 0) continue;

      results.add({
        'vendor_id': vendorData['id'] ?? loanMap['vendor_id'] ?? '',
        'vendor_name': vendorData['name'] ?? 'Member',
        'vendor_phone': vendorData['phone'] ?? '',
        'vendor_email': vendorData['email'] ?? '',
        'vendor_whatsapp': vendorData['whatsapp_number'] ?? '',
        'loan_id': loanMap['id'],
        'loan_amount': loanMap['amount'],
        'loan_ref': loanMap['id'],
        'balance': balance,
        'due_date': firstDate.toIso8601String(),
      });
    }

    return results;
  }

  // ---------------------------------------------------------------------------
  // Channel senders
  // ---------------------------------------------------------------------------

  Future<void> _sendEmailReminder(ReminderLogModel entry, String type) async {
    final isFollowUp = type == 'follow_up';
    final subject = isFollowUp
        ? 'Final Reminder — Loan Payment Due'
        : 'Payment Reminder — NSBSA Loan';

    final amountStr = entry.balance.toStringAsFixed(2);
    final dueStr =
        '${entry.dueDate.day} ${_monthName(entry.dueDate.month)} ${entry.dueDate.year}';

    final urgencyBanner = isFollowUp
        ? '''
        <div style="background-color: #FF7B72; color: #FFFFFF; text-align: center; padding: 12px; font-weight: bold; font-size: 14px;">
          ⚠️ FINAL REMINDER — Please pay immediately to avoid penalties.
        </div>'''
        : '';

    final htmlContent = '''
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
        .pay-btn { display: inline-block; padding: 15px 30px; background-color: #D4AF37; color: #000000 !important; text-decoration: none; border-radius: 8px; font-weight: bold; margin-top: 20px; }
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
        $urgencyBanner
        <div class="content">
            <p>Dear <strong>${entry.vendorName}</strong>,</p>
            <p>${isFollowUp ? 'This is a final reminder that your loan payment is overdue.' : 'This is a friendly reminder of your upcoming loan payment.'}</p>

            <table class="info-table">
                <tr><th>Loan Reference</th><td>${entry.loanRef}</td></tr>
                <tr><th>Amount Due</th><td>R$amountStr</td></tr>
                <tr><th>Due Date</th><td>$dueStr</td></tr>
            </table>

            <p>Please arrange payment at your nearest NSBSA branch or via your group representative.</p>
            <p style="font-size: 12px; color: #8B949E;">* A penalty fee is applied if payment is missed by 20 days or more.</p>
        </div>
        <div class="footer">
            <p><strong>Contact NSBSA</strong><br>Email: info@nsbsa.org.za<br>Phone: 087 107 7524<br>WhatsApp: 087 107 7524<br>Website: <a href="https://www.stokvelbody.org.za">https://www.stokvelbody.org.za</a></p>
            <p style="font-size: 10px; color: #484F58;">This is an automated communication from NSBSA. For queries, contact your group administrator.</p>
        </div>
    </div>
</body>
</html>
''';

    try {
      // Log to communication_logs
      final logRes = await _supabase.from('communication_logs').insert({
        'vendor_id': entry.vendorId,
        'channel': 'Email',
        'recipient': entry.vendorEmail,
        'subject': subject,
        'content': 'Reminder sent (View email for details)',
        'status': 'pending',
        'metadata': {
          'reminder_type': entry.reminderType,
          'loan_ref': entry.loanRef,
          'balance': entry.balance,
          'due_date': entry.dueDate.toIso8601String(),
        },
      }).select().single();

      // Queue for MailerSend via email_outbox
      await _supabase.from('email_outbox').insert({
        'to_email': entry.vendorEmail,
        'subject': subject,
        'html_content': htmlContent,
        'log_id': logRes['id'],
        'metadata': {
          'reminder_type': entry.reminderType,
          'vendor_id': entry.vendorId,
          'loan_ref': entry.loanRef,
        },
      });
    } catch (e) {
      debugPrint('[Reminder Email] Error: $e');
    }
  }

  Future<void> _sendWhatsAppReminder(
    ReminderLogModel entry,
    String target,
    String type,
  ) async {
    final isFollowUp = type == 'follow_up';
    final amountStr = entry.balance.toStringAsFixed(2);
    final dueStr =
        '${entry.dueDate.day} ${_monthName(entry.dueDate.month)} ${entry.dueDate.year}';
    final urgency = isFollowUp ? 'FINAL REMINDER — ' : '';

    final message = isFollowUp
        ? 'Final reminder: Your loan payment of *R$amountStr* is overdue. '
            'Ref: ${entry.loanRef}. Please pay immediately to avoid penalties.'
        : 'Dear ${entry.vendorName}, your loan payment of *R$amountStr* is due on '
            '$dueStr. Ref: ${entry.loanRef}. Please settle to avoid penalties.';

    try {
      final logRes = await _supabase.from('communication_logs').insert({
        'vendor_id': entry.vendorId,
        'channel': 'WhatsApp',
        'recipient': target,
        'content': '$urgency$message',
        'status': 'pending',
        'metadata': {
          'reminder_type': entry.reminderType,
          'loan_ref': entry.loanRef,
          'balance': entry.balance,
          'due_date': entry.dueDate.toIso8601String(),
        },
      }).select().single();

      // Mark as one-way automated (no footer for urgency)
      final success = await _whatsappService.sendWhatsApp(
        to: target,
        message: message,
        includeFooter: false,
      );

      await _supabase.from('communication_logs').update({
        'status': success ? 'sent' : 'failed',
        if (!success) 'error_message': 'WhatsApp delivery failed',
      }).eq('id', logRes['id']);
    } catch (e) {
      debugPrint('[Reminder WhatsApp] Error: $e');
    }
  }

  Future<void> _sendSmsReminder(
    ReminderLogModel entry,
    String target,
    String type,
  ) async {
    final isFollowUp = type == 'follow_up';
    final amountStr = entry.balance.toStringAsFixed(0);
    final dueStr =
        '${entry.dueDate.day} ${_monthName(entry.dueDate.month).substring(0, 3)} ${entry.dueDate.year}';

    // Max ~160 chars with sender ID "NSBSA"
    final message = isFollowUp
        ? 'NSBSA: Final reminder. Loan payment R$amountStr overdue. Ref: ${entry.loanRef}. Pay immediately to avoid penalties.'
        : 'NSBSA: Loan payment R$amountStr due $dueStr. Ref: ${entry.loanRef}. Pay now to avoid penalties.';

    try {
      final logRes = await _supabase.from('communication_logs').insert({
        'vendor_id': entry.vendorId,
        'channel': 'SMS',
        'recipient': target,
        'content': message,
        'status': 'pending',
        'metadata': {
          'reminder_type': entry.reminderType,
          'loan_ref': entry.loanRef,
          'balance': entry.balance,
          'due_date': entry.dueDate.toIso8601String(),
        },
      }).select().single();

      final success = await _smsService.sendSMS(
        destination: target,
        message: message,
        senderId: 'NSBSA',
      );

      await _supabase.from('communication_logs').update({
        'status': success ? 'sent' : 'failed',
        if (!success) 'error_message': 'SMS delivery failed',
      }).eq('id', logRes['id']);
    } catch (e) {
      debugPrint('[Reminder SMS] Error: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Cron helpers
  // ---------------------------------------------------------------------------

  /// Starts a periodic timer that runs the initial pass at 08:00 and the
  /// follow-up pass at 18:00 every day. Call once at app startup in a
  /// background isolate or a headless entry point.
  ///
  /// Returns the [Timer] so callers can cancel it when needed.
  Timer startDailyCron() {
    const fiveMin = Duration(minutes: 5);
    return Timer.periodic(fiveMin, (_) async {
      final now = DateTime.now();
      if (now.hour == 8 && now.minute < 5) {
        await sendInitialReminders();
      } else if (now.hour == 18 && now.minute < 5) {
        await sendFollowUpReminders();
      }
    });
  }

  // ---------------------------------------------------------------------------
  // History
  // ---------------------------------------------------------------------------

  /// Fetches reminder logs for a specific vendor, ordered newest first.
  Future<List<ReminderLogModel>> fetchReminderHistory(String vendorId) async {
    try {
      final response = await _supabase
          .from('communication_logs')
          .select()
          .eq('vendor_id', vendorId)
          .order('created_at', ascending: false);

      return (response as List)
          .where((e) => (e['metadata'] as Map<String, dynamic>?)?['reminder_type'] != null)
          .map((e) {
        final meta = e['metadata'] as Map<String, dynamic>? ?? {};
        return ReminderLogModel(
          id: e['id'] ?? '',
          vendorId: vendorId,
          vendorName: '',
          vendorPhone: '',
          vendorEmail: '',
          vendorWhatsApp: '',
          loanAmount: (meta['balance'] as num?)?.toDouble() ?? 0,
          balance: (meta['balance'] as num?)?.toDouble() ?? 0,
          loanRef: meta['loan_ref']?.toString() ?? '',
          dueDate: meta['due_date'] != null
              ? DateTime.parse(meta['due_date'].toString())
              : DateTime.now(),
          reminderType: meta['reminder_type']?.toString() ?? '',
          channel: e['channel']?.toString() ?? '',
          status: e['status']?.toString() ?? '',
          errorMessage: e['error_message']?.toString(),
          createdAt: e['created_at'] != null
              ? DateTime.parse(e['created_at'].toString())
              : DateTime.now(),
        );
      }).toList();
    } catch (e) {
      debugPrint('[Reminder History] Error: $e');
      return [];
    }
  }

  /// Returns aggregated delivery stats for the dashboard preview.
  Future<Map<String, int>> fetchDeliveryStats() async {
    try {
      final today = DateTime.now().toIso8601String().substring(0, 10);
      final response = await _supabase
          .from('communication_logs')
          .select('channel, status')
          .gte('created_at', today);

      final rows = (response as List)
          .where((e) => (e['metadata'] as Map<String, dynamic>?)?['reminder_type'] != null)
          .toList();
      final Map<String, int> stats = {
        'Email_sent': 0, 'Email_delivered': 0, 'Email_failed': 0,
        'WhatsApp_sent': 0, 'WhatsApp_delivered': 0, 'WhatsApp_failed': 0,
        'SMS_sent': 0, 'SMS_delivered': 0, 'SMS_failed': 0,
      };

      for (final row in rows) {
        final channel = row['channel']?.toString() ?? '';
        final status = row['status']?.toString() ?? '';
        final key = '${channel}_$status';
        if (stats.containsKey(key)) stats[key] = stats[key]! + 1;
      }

      return stats;
    } catch (e) {
      debugPrint('[Reminder Stats] Error: $e');
      return {};
    }
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  String _monthName(int m) {
    const names = [
      '', 'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return names[m];
  }
}

/// Lightweight summary returned after each reminder pass.
class ReminderSummary {
  int totalVendors = 0;
  int emailSent = 0;
  int whatsappSent = 0;
  int smsSent = 0;
  List<String> errors = [];

  @override
  String toString() =>
      'ReminderSummary(vendors: $totalVendors, email: $emailSent, '
      'whatsapp: $whatsappSent, sms: $smsSent, errors: ${errors.length})';
}
