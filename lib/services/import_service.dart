import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:spreadsheet_decoder/spreadsheet_decoder.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/vendor.dart';
import '../models/loan.dart';
import 'notification_service.dart';

class ImportService {
  final _supabase = Supabase.instance.client;

  Future<void> importExcel(List<int> bytes, {Function(double, String)? onProgress}) async {
    onProgress?.call(0.0, 'Analyzing Excel file...');
    var decoder = SpreadsheetDecoder.decodeBytes(bytes);
    
    // 1. Calculate total valid rows for progress tracking
    int totalValidRows = 0;
    List<String> validSheets = [];
    for (var table in decoder.tables.keys) {
      if (_isMonthSheet(table)) {
        validSheets.add(table);
        var sheet = decoder.tables[table]!;
        for (int i = 1; i < sheet.maxRows; i++) {
          if (sheet.rows[i].isNotEmpty && sheet.rows[i][0] != null) {
            totalValidRows++;
          }
        }
      }
    }

    if (totalValidRows == 0) {
      throw Exception('No valid data found in any month sheet (January-December).');
    }

    int processedRows = 0;
    onProgress?.call(0.05, 'Importing $totalValidRows records...');

    for (var table in validSheets) {
      var sheet = decoder.tables[table]!;
      DateTime sheetDate = _getSheetDate(table);

      for (int i = 1; i < sheet.maxRows; i++) {
        var row = sheet.rows[i];
        if (row.isEmpty || row[0] == null) continue;

        String name = row[0]?.toString() ?? '';
        if (name.isEmpty || name == 'null') continue;

        processedRows++;
        double progress = 0.05 + (processedRows / totalValidRows * 0.9);
        onProgress?.call(progress, 'Processing: $name ($table)');

        try {
          String idNumber = row[1]?.toString() ?? '';
          String phone = row[2]?.toString() ?? '';
          String groupName = row[3]?.toString() ?? 'Default Group';
          String businessType = row[4]?.toString() ?? '';
          String dfName = row[5]?.toString() ?? '';
          String gender = row[6]?.toString() ?? '';

          double amount = _toDouble(row[7]);
          int term = _toInt(row[8]);
          DateTime? firstPaymentDate = _toDateTime(row[9]);
          double openingAmount = _toDouble(row[10]);
          double initiationFee = _toDouble(row[11]);
          double adminFee = _toDouble(row[12]);
          double monthlyInstalment = _toDouble(row.length > 13 ? row[13] : 0);
          double penaltyFee = _toDouble(row.length > 14 ? row[14] : 0);

          double paidInit = _toDouble(row.length > 15 ? row[15] : 0);
          double paidAdmin = _toDouble(row.length > 16 ? row[16] : 0);
          double paidInstalment = _toDouble(row.length > 17 ? row[17] : 0);
          double paidPenalty = _toDouble(row.length > 18 ? row[18] : 0);
          double totalPaidThisMonth = paidInit + paidAdmin + paidInstalment + paidPenalty;

          // 1. Get or Create Group
          String groupId = await _getOrCreateGroup(groupName);

          // 2. Get or Create Vendor
          String vendorId = await _getOrCreateVendor(
            groupId: groupId,
            name: name,
            phone: phone,
            idNumber: idNumber,
            businessType: businessType,
            dfName: dfName,
            gender: gender,
          );

          // 3. Handle Loan & Payment Logic
          if (amount > 0) {
            String? existingLoanId = await _findExistingLoan(vendorId, amount);

            if (existingLoanId == null) {
              existingLoanId = await _upsertLoan(
                groupId: groupId,
                vendorId: vendorId,
                amount: amount,
                term: term,
                monthlyPayment: monthlyInstalment,
                initiationFee: initiationFee,
                adminFee: adminFee,
                penaltyFee: penaltyFee,
                openingAmount: openingAmount,
                firstPaymentDate: firstPaymentDate,
              );
            }

            if (totalPaidThisMonth > 0) {
              await _recordPayment(
                loanId: existingLoanId,
                amount: totalPaidThisMonth,
                date: sheetDate,
              );
            }
          }
        } catch (e) {
          debugPrint('Error importing row for $name: $e');
          // Continue with next row
        }
      }
    }

    onProgress?.call(1.0, 'Finalizing import...');
    await NotificationService.notifyAdmins(
      'Data Import Complete',
      'The Excel data import has finished successfully. $totalValidRows records processed.',
      type: 'SYSTEM',
    );
  }

  Future<void> _recordPayment({
    required String loanId,
    required double amount,
    required DateTime date,
  }) async {
    // Check if this payment already exists to prevent duplicate payments on re-import
    final existing = await _supabase
        .from('payments')
        .select('id')
        .eq('loan_id', loanId)
        .eq('amount_paid', amount)
        .eq('date_paid', date.toIso8601String())
        .maybeSingle();

    if (existing == null) {
      await _supabase.from('payments').insert({
        'loan_id': loanId,
        'amount_paid': amount,
        'date_paid': date.toIso8601String(),
        'payment_method': 'Imported',
      });
    }
  }

  bool _isMonthSheet(String name) {
    final months = [
      'JANUARY',
      'FEBRUARY',
      'MARCH',
      'APRIL',
      'MAY',
      'JUNE',
      'JULY',
      'AUGUST',
      'SEPTEMBER',
      'OCTOBER',
      'NOVEMBER',
      'DECEMBER',
    ];
    String upper = name.toUpperCase().replaceAll('.', '').trim();
    return months.contains(upper);
  }

  DateTime _getSheetDate(String sheetName) {
    String upper = sheetName.toUpperCase().replaceAll('.', '').trim();
    int month = 1;
    if (upper.contains('FEB'))
      month = 2;
    else if (upper.contains('MAR'))
      month = 3;
    else if (upper.contains('APR'))
      month = 4;
    else if (upper.contains('MAY'))
      month = 5;
    else if (upper.contains('JUN'))
      month = 6;
    else if (upper.contains('JUL'))
      month = 7;
    else if (upper.contains('AUG'))
      month = 8;
    else if (upper.contains('SEP'))
      month = 9;
    else if (upper.contains('OCT'))
      month = 10;
    else if (upper.contains('NOV'))
      month = 11;
    else if (upper.contains('DEC'))
      month = 12;

    // Stable date based on the month sheet to prevent duplicates if re-run
    return DateTime(2026, month, 1);
  }

  double _toDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0.0;
  }

  int _toInt(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString()) ?? 0;
  }

  DateTime? _toDateTime(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    return DateTime.tryParse(value.toString());
  }

  Future<String> _getOrCreateGroup(String name) async {
    final existing = await _supabase
        .from('groups')
        .select('id')
        .eq('name', name)
        .maybeSingle();

    if (existing != null) return existing['id'];

    final inserted = await _supabase
        .from('groups')
        .insert({
          'name': name,
          'reference_number': 'GRP-${DateTime.now().millisecondsSinceEpoch}',
        })
        .select('id')
        .single();

    return inserted['id'];
  }

  Future<String> _getOrCreateVendor({
    required String groupId,
    required String name,
    required String phone,
    required String idNumber,
    required String businessType,
    required String dfName,
    required String gender,
  }) async {
    String? existingId;

    // 1. Check by ID number (strongest unique identifier)
    if (idNumber.isNotEmpty) {
      final byId = await _supabase
          .from('vendors')
          .select('id')
          .eq('id_number', idNumber)
          .maybeSingle();
      if (byId != null) existingId = byId['id'];
    }

    // 2. Check by phone number if ID number wasn't found
    if (existingId == null && phone.isNotEmpty) {
      final byPhone = await _supabase
          .from('vendors')
          .select('id')
          .eq('phone', phone)
          .maybeSingle();
      if (byPhone != null) existingId = byPhone['id'];
    }

    // 3. Fall back to name + group (legacy safety net)
    if (existingId == null) {
      final byName = await _supabase
          .from('vendors')
          .select('id')
          .eq('name', name)
          .eq('group_id', groupId)
          .maybeSingle();
      if (byName != null) existingId = byName['id'];
    }

    final vendorData = {
      'group_id': groupId,
      'name': name,
      'phone': phone,
      'id_number': idNumber,
      'business_type': businessType,
      'df_name': dfName,
      'gender': gender,
    };

    if (existingId != null) {
      // UPDATE existing vendor details
      await _supabase.from('vendors').update(vendorData).eq('id', existingId);
      return existingId;
    } else {
      // CREATE new vendor
      vendorData['reference_number'] = await _getGroupRef(groupId);
      final inserted = await _supabase
          .from('vendors')
          .insert(vendorData)
          .select('id')
          .single();
      return inserted['id'];
    }
  }

  Future<String?> _findExistingLoan(String vendorId, double amount) async {
    // Look for an active loan with this amount for this specific vendor
    final response = await _supabase
        .from('loans')
        .select('id')
        .eq('vendor_id', vendorId)
        .eq('amount', amount)
        .eq('status', 'Active')
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();

    return response?['id'];
  }

  Future<String> _getGroupRef(String groupId) async {
    final res = await _supabase
        .from('groups')
        .select('reference_number')
        .eq('id', groupId)
        .single();
    return res['reference_number'];
  }

  Future<String> _upsertLoan({
    required String groupId,
    required String vendorId,
    required double amount,
    required int term,
    required double monthlyPayment,
    double? initiationFee,
    double? adminFee,
    double? penaltyFee,
    double? openingAmount,
    DateTime? firstPaymentDate,
  }) async {
    final existingLoanId = await _findExistingLoan(vendorId, amount);

    final loanData = {
      'group_id': groupId,
      'vendor_id': vendorId,
      'amount': amount,
      'duration_months': term,
      'monthly_payment': monthlyPayment,
      'status': 'Active',
      'initiation_fee': initiationFee,
      'monthly_admin_fee': adminFee,
      'penalty_fee': penaltyFee,
      'opening_amount': openingAmount,
      'first_instalment_date': firstPaymentDate?.toIso8601String(),
    };

    if (existingLoanId != null) {
      // Update existing loan parameters if they differ (e.g. fees changed in spreadsheet)
      await _supabase.from('loans').update(loanData).eq('id', existingLoanId);
      return existingLoanId;
    } else {
      // Insert new loan
      final inserted = await _supabase
          .from('loans')
          .insert(loanData)
          .select('id')
          .single();
      return inserted['id'];
    }
  }

  Future<void> clearAllData() async {
    // Delete in reverse order of dependencies to respect foreign keys
    await _supabase
        .from('payments')
        .delete()
        .neq('id', '00000000-0000-0000-0000-000000000000');
    await _supabase
        .from('savings_history')
        .delete()
        .neq('id', '00000000-0000-0000-0000-000000000000');
    await _supabase
        .from('documents')
        .delete()
        .neq('id', '00000000-0000-0000-0000-000000000000');
    await _supabase
        .from('comments')
        .delete()
        .neq('id', '00000000-0000-0000-0000-000000000000');
    await _supabase
        .from('loans')
        .delete()
        .neq('id', '00000000-0000-0000-0000-000000000000');
    await _supabase
        .from('group_payments')
        .delete()
        .neq('id', '00000000-0000-0000-0000-000000000000');
    await _supabase
        .from('announcements')
        .delete()
        .neq('id', '00000000-0000-0000-0000-000000000000');
    await _supabase
        .from('vendors')
        .delete()
        .neq('id', '00000000-0000-0000-0000-000000000000');
    await _supabase
        .from('password_reset_requests')
        .delete()
        .neq('id', '00000000-0000-0000-0000-000000000000');
    await _supabase
        .from('groups')
        .delete()
        .neq('id', '00000000-0000-0000-0000-000000000000');
  }

  /// Generates a full system backup as a JSON string
  Future<Map<String, dynamic>> generateBackup() async {
    final Map<String, dynamic> data = {};

    final tables = [
      'groups',
      'profiles',
      'system_settings',
      'email_outbox',
      'password_reset_requests',
      'account_audit_log',
      'system_audit_log',
      'vendors',
      'announcements',
      'group_payments',
      'loans',
      'comments',
      'documents',
      'savings_history',
      'payments',
    ];

    for (var table in tables) {
      try {
        final response = await _supabase.from(table).select();
        data[table] = response;
      } catch (e) {
        debugPrint('Backup: Skipping table $table as it might not exist: $e');
        data[table] = []; // Default to empty if table is missing
      }
    }

    await NotificationService.notifyAdmins(
      'System Backup Created',
      'A full system data backup has been generated.',
      type: 'SYSTEM',
    );

    return {
      'version': '1.1.1',
      'timestamp': DateTime.now().toIso8601String(),
      'data': data,
    };
  }

  /// Restores the system from a backup map
  Future<void> restoreBackup(Map<String, dynamic> backup) async {
    final data = backup['data'] as Map<String, dynamic>;

    // 1. Wipe existing data (Full system wipe)
    await clearAllData();
    // Wipe independent log tables too
    await _supabase
        .from('system_audit_log')
        .delete()
        .neq('id', '00000000-0000-0000-0000-000000000000');
    await _supabase
        .from('account_audit_log')
        .delete()
        .neq('id', '00000000-0000-0000-0000-000000000000');
    await _supabase
        .from('email_outbox')
        .delete()
        .neq('id', '00000000-0000-0000-0000-000000000000');

    // 2. Restore in strict order of dependencies
    if (data['groups'] != null && (data['groups'] as List).isNotEmpty) {
      await _supabase.from('groups').insert(data['groups']);
    }

    // Profiles and Settings (Independent/Critical)
    if (data['profiles'] != null && (data['profiles'] as List).isNotEmpty) {
      await _supabase.from('profiles').upsert(data['profiles']);
    }
    if (data['system_settings'] != null &&
        (data['system_settings'] as List).isNotEmpty) {
      await _supabase.from('system_settings').upsert(data['system_settings']);
    }

    // Independent Logs
    if (data['email_outbox'] != null &&
        (data['email_outbox'] as List).isNotEmpty) {
      await _supabase.from('email_outbox').insert(data['email_outbox']);
    }
    if (data['password_reset_requests'] != null &&
        (data['password_reset_requests'] as List).isNotEmpty) {
      await _supabase
          .from('password_reset_requests')
          .insert(data['password_reset_requests']);
    }
    if (data['account_audit_log'] != null &&
        (data['account_audit_log'] as List).isNotEmpty) {
      await _supabase
          .from('account_audit_log')
          .insert(data['account_audit_log']);
    }
    if (data['system_audit_log'] != null &&
        (data['system_audit_log'] as List).isNotEmpty) {
      await _supabase.from('system_audit_log').insert(data['system_audit_log']);
    }

    // Level 2 (Depends on Groups)
    if (data['vendors'] != null && (data['vendors'] as List).isNotEmpty) {
      await _supabase.from('vendors').insert(data['vendors']);
    }
    if (data['announcements'] != null &&
        (data['announcements'] as List).isNotEmpty) {
      await _supabase.from('announcements').insert(data['announcements']);
    }
    if (data['group_payments'] != null &&
        (data['group_payments'] as List).isNotEmpty) {
      await _supabase.from('group_payments').insert(data['group_payments']);
    }

    // Level 3 (Depends on Vendors/Groups/GroupPayments)
    if (data['loans'] != null && (data['loans'] as List).isNotEmpty) {
      await _supabase.from('loans').insert(data['loans']);
    }
    if (data['comments'] != null && (data['comments'] as List).isNotEmpty) {
      await _supabase.from('comments').insert(data['comments']);
    }
    if (data['documents'] != null && (data['documents'] as List).isNotEmpty) {
      await _supabase.from('documents').insert(data['documents']);
    }
    if (data['savings_history'] != null &&
        (data['savings_history'] as List).isNotEmpty) {
      await _supabase.from('savings_history').insert(data['savings_history']);
    }

    // Level 4 (Depends on Loans and GroupPayments)
    if (data['payments'] != null && (data['payments'] as List).isNotEmpty) {
      await _supabase.from('payments').insert(data['payments']);
    }

    await NotificationService.notifySuperAdmin(
      'System Restored',
      'The system has been successfully restored from a backup.',
      type: 'SYSTEM',
    );
  }
}
