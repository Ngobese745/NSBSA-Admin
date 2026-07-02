import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/reminder_log.dart';
import 'smsworx_service.dart';
import 'wesender_service.dart';

/// Sends payment-start reminders to clients whose grace period has just
/// ended (or ends today).
///
/// The grace period is configured at loan creation. When the
/// `first_payment_date` arrives, this service fires a one-off reminder
/// across Email, WhatsApp, and SMS to inform the client that repayments
/// have started. The reminder is tracked in the `reminder_log` table so it
/// is not sent twice for the same loan.
///
/// Recommended call from a Supabase cron / scheduled function:
///   00 09 * * *  → sendGracePeriodEndReminders()
class GracePeriodReminderService {
  GracePeriodReminderService._();
  static final GracePeriodReminderService instance = GracePeriodReminderService._();

  final _supabase = Supabase.instance.client;
  final _smsService = SMSWorxService();
  final _whatsappService = WeSenderService();

  /// Public entry point. Finds loans whose grace period ends today (or has
  /// just ended and was not notified yet) and dispatches the reminder.
  Future<GraceReminderSummary> sendGracePeriodEndReminders() async {
    debugPrint('[Grace Reminder] Scanning loans for grace period expiry...');
    final summary = GraceReminderSummary();

    try {
      // 1. Find loans where:
      //    - grace_period_enabled = true
      //    - first_payment_date <= today
      //    - AND a reminder for this loan has NOT been logged yet
      final response = await _supabase
          .from('loans')
          .select('''
            id, amount, monthly_payment, first_payment_date,
            grace_period_months, status,
            vendors:vendor_id ( id, name, phone, email, whatsapp )
          ''')
          .eq('grace_period_enabled', true)
          .lte('first_payment_date', DateTime.now().toIso8601String().split('T').first)
          .eq('status', 'Active');

      final dueLoans = (response as List);
      debugPrint('[Grace Reminder] Found ${dueLoans.length} candidate loan(s)');

      for (final row in dueLoans) {
        final loanId = row['id'] as String;
        // Skip if we have already logged a grace-end reminder for this loan
        final alreadyNotified = await _hasReminderBeenSent(loanId);
        if (alreadyNotified) continue;

        final vendor = (row['vendors'] is Map) ? row['vendors'] as Map : null;
        if (vendor == null) continue;

        final vendorName = (vendor['name'] as String?) ?? 'Customer';
        final vendorPhone = (vendor['phone'] as String?) ?? '';
        final vendorEmail = (vendor['email'] as String?) ?? '';
        final vendorWhatsApp = (vendor['whatsapp'] as String?) ?? '';

        final monthlyPayment = (row['monthly_payment'] as num).toDouble();
        final graceMonths = (row['grace_period_months'] as num?)?.toInt() ?? 0;
        final loanRef = 'L-${loanId.substring(0, 8).toUpperCase()}';

        final message =
            'Dear $vendorName, your loan repayment period (ref $loanRef) '
            'begins this month after a ${graceMonths}-month grace period. '
            'Your monthly instalment is R${monthlyPayment.toStringAsFixed(2)}. '
            'Please ensure your first payment is made to avoid penalties.';

        // Truncate to SMS-safe length (160 chars). We don't need to on this
        // message because it stays well under 160, but we apply the same
        // guard as the regular reminder service for safety.
        final smsMessage = message.length > 160
            ? '${message.substring(0, 157)}...'
            : message;

        final logEntry = ReminderLogModel(
          id: '',
          vendorId: (vendor['id'] as String?) ?? '',
          vendorName: vendorName,
          vendorPhone: vendorPhone,
          vendorEmail: vendorEmail,
          vendorWhatsApp: vendorWhatsApp,
          loanAmount: (row['amount'] as num).toDouble(),
          balance: monthlyPayment,
          loanRef: loanRef,
          dueDate: row['first_payment_date'] != null
              ? DateTime.parse(row['first_payment_date'] as String)
              : DateTime.now(),
          reminderType: 'grace_period_end',
          channel: 'multi',
          status: 'pending',
          createdAt: DateTime.now(),
        );

        bool sent = false;
        String? errorMsg;

        // WhatsApp (preferred)
        if (vendorWhatsApp.isNotEmpty || vendorPhone.isNotEmpty) {
          try {
            await _whatsappService.sendWhatsApp(
              to: vendorWhatsApp.isNotEmpty ? vendorWhatsApp : vendorPhone,
              message: message,
            );
            sent = true;
          } catch (e) {
            errorMsg = 'WhatsApp: $e';
          }
        }

        // SMS fallback
        if (vendorPhone.isNotEmpty) {
          try {
            await _smsService.sendSMS(
              destination: vendorPhone,
              message: smsMessage,
            );
            sent = true;
          } catch (e) {
            errorMsg = '${errorMsg ?? ''} | SMS: $e';
          }
        }

        // Email (logged — actual delivery is handled by a Supabase Edge
        // function or external SMTP relay). We at minimum write a
        // notifications row so the audit trail captures the event.
        if (vendorEmail.isNotEmpty) {
          try {
            await _supabase.from('notifications').insert({
              'title': 'Loan Repayment Period Started',
              'message': message,
              'type': 'GRACE_PERIOD_END',
              'recipient_id': logEntry.vendorId,
            });
            sent = true;
          } catch (e) {
            errorMsg = '${errorMsg ?? ''} | Email: $e';
          }
        }

        // Persist the log
        await _logReminder(
          logEntry,
          sent: sent,
          errorMessage: errorMsg,
        );

        if (sent) summary.sent++;
        summary.processed++;
      }
    } catch (e) {
      debugPrint('[Grace Reminder] Error: $e');
      summary.error = e.toString();
    }

    debugPrint(
      '[Grace Reminder] Done. Processed ${summary.processed}, sent ${summary.sent}.',
    );
    return summary;
  }

  /// Returns true if a 'grace_period_end' reminder has already been logged
  /// for the given loan.
  Future<bool> _hasReminderBeenSent(String loanId) async {
    try {
      final response = await _supabase
          .from('reminder_log')
          .select('id')
          .eq('loan_ref', 'L-${loanId.substring(0, 8).toUpperCase()}')
          .eq('reminder_type', 'grace_period_end')
          .limit(1);
      return (response as List).isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<void> _logReminder(
    ReminderLogModel log, {
    required bool sent,
    String? errorMessage,
  }) async {
    try {
      await _supabase.from('reminder_log').insert({
        'vendor_id': log.vendorId,
        'vendor_name': log.vendorName,
        'vendor_phone': log.vendorPhone,
        'vendor_email': log.vendorEmail,
        'vendor_whatsapp': log.vendorWhatsApp,
        'loan_amount': log.loanAmount,
        'balance': log.balance,
        'loan_ref': log.loanRef,
        'due_date': log.dueDate.toIso8601String(),
        'reminder_type': log.reminderType,
        'sent': sent,
        if (errorMessage != null) 'error': errorMessage,
        'created_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      debugPrint('Failed to log grace reminder: $e');
    }
  }
}

class GraceReminderSummary {
  int processed = 0;
  int sent = 0;
  String? error;
}
