import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:spreadsheet_decoder/spreadsheet_decoder.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/vendor.dart';
import '../models/loan.dart';
import 'notification_service.dart';
import 'system_audit_service.dart';

// ---------------------------------------------------------------------------
// Result models
// ---------------------------------------------------------------------------

/// Per-sheet import summary used for post-import verification.
class MonthImportSummary {
  /// The raw tab name exactly as it appears in the Excel file.
  final String rawSheetLabel;

  /// Normalised human-readable month name (e.g. "January").
  final String monthLabel;

  /// Number of data rows found in the Excel sheet (excluding header).
  final int rowsInExcel;

  /// Number of rows successfully persisted (or skipped as duplicate).
  final int rowsImported;

  /// Whether the imported count matches what was in the file.
  bool get matched => rowsImported == rowsInExcel;

  const MonthImportSummary({
    required this.rawSheetLabel,
    required this.monthLabel,
    required this.rowsInExcel,
    required this.rowsImported,
  });
}

/// Top-level result returned after a complete import run.
class ImportResult {
  final bool success;
  final int totalRecordsInExcel;
  final int totalRecordsImported;
  final List<MonthImportSummary> monthSummaries;
  final List<String> errors;

  /// Whether the import auto-assigned records to the current month because
  /// no month-named sheets were detected in the file.
  final bool autoAssigned;

  /// When [autoAssigned] is true, this holds the human-readable label of
  /// the month the data was assigned to (e.g. "June").
  final String? detectedMonthLabel;

  /// Whether any sheet in the file contained an interest-rate column that
  /// was detected and deliberately ignored during import.
  final bool rateColumnsFound;

  /// Human-readable labels of the columns that were successfully mapped,
  /// e.g. {"Name", "ID Number", "Loan Amount", "Opening Balance"}.
  final Set<String> mappedColumnLabels;

  /// Names of centres created during this import (empty if none).
  final List<String> newCentres;

  /// Names of fields expected by the system that were NOT found in the
  /// Excel file, e.g. {"Loan Term", "First Payment Date"}.
  Set<String> get missingColumns {
    const required = {
      'Name', 'ID Number', 'Phone', 'Group Name',
      'Loan Amount', 'Loan Term', 'Opening Balance',
    };
    return required.difference(mappedColumnLabels);
  }

  /// Sheets that are present in the Excel file but whose imported count
  /// doesn't match the source – used for the verification failure message.
  List<MonthImportSummary> get mismatchedMonths =>
      monthSummaries.where((s) => !s.matched).toList();

  bool get allMonthsMatch => mismatchedMonths.isEmpty;

  String get verificationMessage {
    if (!success) {
      String msg = 'Month values could not be imported correctly. '
          'Please check your Excel file format.';
      if (rateColumnsFound) {
        msg += '\nInterest rates in Excel are ignored. '
            'Please record loans in the system to apply correct rates.';
      }
      return msg;
    }

    String msg;
    if (autoAssigned) {
      msg = 'Import completed successfully. '
          'Unable to detect month columns. '
          'Data imported for $detectedMonthLabel.';
    } else {
      msg = 'Import completed successfully.';
    }

    msg += ' Interest rates ignored. Balances imported as opening values.';

    if (rateColumnsFound) {
      msg += '\nInterest rates in Excel are ignored. '
          'Please record loans in the system to apply correct rates.';
    }

    final missing = missingColumns;
    if (missing.isNotEmpty) {
      msg += '\nNote: ${missing.join(", ")} not found — skipped.';
    }

    // Centre / D.F Name feedback
    if (mappedColumnLabels.contains('Centre Name')) {
      msg += '\nD.F Name and Centre Name assigned to vendor/group records.';
    }
    if (newCentres.isNotEmpty) {
      msg += '\nNew Centre records created: ${newCentres.join(", ")}.';
    }

    return msg;
  }

  const ImportResult({
    required this.success,
    required this.totalRecordsInExcel,
    required this.totalRecordsImported,
    required this.monthSummaries,
    required this.errors,
    required this.mappedColumnLabels,
    this.autoAssigned = false,
    this.detectedMonthLabel,
    this.rateColumnsFound = false,
    this.newCentres = const [],
  });
}

// ---------------------------------------------------------------------------
// Canonical month definitions
// ---------------------------------------------------------------------------

/// All recognised variants per month (uppercase). The first entry is the
/// canonical full name used when displaying results.
const _monthVariants = [
  ['JANUARY', 'JAN'],
  ['FEBRUARY', 'FEB'],
  ['MARCH', 'MAR'],
  ['APRIL', 'APR'],
  ['MAY'],
  ['JUNE', 'JUN'],
  ['JULY', 'JUL'],
  ['AUGUST', 'AUG'],
  ['SEPTEMBER', 'SEP'],
  ['OCTOBER', 'OCT'],
  ['NOVEMBER', 'NOV'],
  ['DECEMBER', 'DEC'],
];

// ---------------------------------------------------------------------------
// ImportService
// ---------------------------------------------------------------------------

class ImportService {
  final _supabase = Supabase.instance.client;

  // -------------------------------------------------------------------------
  // Public API
  // -------------------------------------------------------------------------

  /// Import an Excel file (.xlsx) encoded as [bytes].
  ///
  /// [fileName]   – used purely for audit-log traceability.
  /// [onProgress] – optional progress callback (0.0 → 1.0, message).
  /// [autoAssignToCurrentMonth] – when true and no month-named sheets are
  ///   found, all records are assigned to the current month automatically.
  ///
  /// Returns a structured [ImportResult] describing what happened per month.
  Future<ImportResult> importExcel(
    List<int> bytes, {
    String fileName = 'unknown.xlsx',
    Function(double, String)? onProgress,
    bool autoAssignToCurrentMonth = true,
  }) async {
    onProgress?.call(0.0, 'Analysing Excel file…');

    final List<MonthImportSummary> summaries = [];
    final List<String> errors = [];
    bool wasAutoAssigned = false;
    String? autoAssignMonth;
    bool rateColumnsFound = false;
    final mappedFields = <String>{};

    late SpreadsheetDecoder decoder;
    try {
      decoder = SpreadsheetDecoder.decodeBytes(bytes);
    } catch (e) {
      throw Exception(
        'Month values could not be imported correctly. '
        'Please check your Excel file format. ($e)',
      );
    }

    onProgress?.call(0.02, 'Pre-loading existing data into memory…');
    await _preloadData();


    // 1. Discover and validate month sheets ---------------------------------
    final List<_SheetInfo> sheets = [];

    for (final tabName in decoder.tables.keys) {
      final info = _resolveMonthSheet(tabName);
      if (info == null) continue; // Not a month sheet – skip silently

      final sheet = decoder.tables[tabName]!;

      // Detect header row and column mapping
      final headerInfo = _detectHeaderRow(sheet);
      if (headerInfo == null) continue; // No recognisable header – skip

      if (headerInfo.cols.containsKey('interest_rate')) {
        rateColumnsFound = true;
      }
      mappedFields.addAll(headerInfo.cols.keys);

      // Count data rows (rows after the header with a non-empty name cell)
      int dataRows = 0;
      for (int i = headerInfo.dataStartRow; i < sheet.maxRows; i++) {
        final row = sheet.rows[i];
        if (row.isEmpty) continue;
        final name = _str(row, headerInfo.cols['name']);
        if (name.isNotEmpty && name.toLowerCase() != 'null') dataRows++;
      }

      if (dataRows == 0) continue; // Empty sheet – skip

      sheets.add(_SheetInfo(
        tabName: tabName,
        monthLabel: info.$1,
        monthNumber: info.$2,
        sheet: sheet,
        headerInfo: headerInfo,
        rowsInExcel: dataRows,
      ));
    }

    if (sheets.isEmpty) {
      // No month-named sheets found – fallback to auto-assign if enabled.
      if (autoAssignToCurrentMonth) {
        final now = DateTime.now();
        final currentMonthIdx = now.month - 1;
        final monthLabel = _monthVariants[currentMonthIdx][0][0] +
            _monthVariants[currentMonthIdx][0].substring(1).toLowerCase();
        final monthNumber = now.month;
        wasAutoAssigned = true;
        autoAssignMonth = monthLabel;

        onProgress?.call(0.03,
            'No month sheets found. Assigning data to $monthLabel…');

        for (final tabName in decoder.tables.keys) {
          final sheet = decoder.tables[tabName]!;
          final headerInfo = _detectHeaderRow(sheet);
          if (headerInfo == null) continue;

          if (headerInfo.cols.containsKey('interest_rate')) {
            rateColumnsFound = true;
          }
          mappedFields.addAll(headerInfo.cols.keys);

          int dataRows = 0;
          for (int i = headerInfo.dataStartRow; i < sheet.maxRows; i++) {
            final row = sheet.rows[i];
            if (row.isEmpty) continue;
            final name = _str(row, headerInfo.cols['name']);
            if (name.isNotEmpty && name.toLowerCase() != 'null') dataRows++;
          }
          if (dataRows == 0) continue;

          sheets.add(_SheetInfo(
            tabName: tabName,
            monthLabel: monthLabel,
            monthNumber: monthNumber,
            sheet: sheet,
            headerInfo: headerInfo,
            rowsInExcel: dataRows,
          ));
        }

        if (sheets.isEmpty) {
          throw Exception(
            'No valid data found. Please check your Excel file format.',
          );
        }
      } else {
        throw Exception(
          'No valid data found in any month sheet (January–December). '
          'Please check your Excel file format.',
        );
      }
    }

    // Sort sheets in calendar order
    sheets.sort((a, b) => a.monthNumber.compareTo(b.monthNumber));

    int totalExcel = sheets.fold(0, (s, sh) => s + sh.rowsInExcel);
    int processedRows = 0;

    onProgress?.call(0.05, 'Importing $totalExcel records…');

    // 2. Process each sheet -------------------------------------------------
    for (final sheetInfo in sheets) {
      int importedForSheet = 0;
      final sheet = sheetInfo.sheet;
      final cols = sheetInfo.headerInfo.cols;
      final dataStart = sheetInfo.headerInfo.dataStartRow;
      final sheetDate = DateTime(DateTime.now().year, sheetInfo.monthNumber, 1);

      for (int i = dataStart; i < sheet.maxRows; i++) {
        final row = sheet.rows[i];
        if (row.isEmpty) continue;

        final name = _str(row, cols['name']);
        if (name.isEmpty || name.toLowerCase() == 'null') continue;

        processedRows++;
        final pct = 0.05 + (processedRows / totalExcel * 0.9);
        onProgress?.call(pct, 'Processing: $name (${sheetInfo.monthLabel})');

        try {
          final idNumber      = _str(row, cols['id_number']);
          final phone         = _str(row, cols['phone']);
          final groupName     = _str(row, cols['group_name'], fallback: 'Default Group');
          final businessType  = _str(row, cols['business_type']);
          final dfName        = _str(row, cols['df_name']);
          final gender        = _str(row, cols['gender']);

          final amount            = _toDouble(row, cols['loan_amount']);
          final term              = _toInt(row, cols['loan_term']);
          final firstPaymentDate  = _toDateTime(row, cols['first_payment']);
          final openingAmount     = _toDouble(row, cols['opening_amount']);
          final initiationFee     = _toDouble(row, cols['init_fee']);
          final adminFee          = _toDouble(row, cols['admin_fee']);
          final monthlyInstalment = _toDouble(row, cols['monthly']);
          final penaltyFee        = _toDouble(row, cols['penalty']);

          // Total Paid comes directly from "Total Monthly Instalments Received"
          // (mapped to 'paid_instalment').  Do NOT sum components — the Excel
          // file is the single source of truth for imported data.
          final totalPaid = _toDouble(row, cols['paid_instalment']);

          // Centre name — create or link
          final centreName = _str(row, cols['centre_name']);
          String? centreId;
          if (centreName.isNotEmpty) {
            centreId = await _getOrCreateCentre(centreName);
          }

          final groupId = await _getOrCreateGroup(
            groupName,
            centreId: centreId,
            dfName: dfName.isNotEmpty ? dfName : null,
          );
          final vendorId = await _getOrCreateVendor(
            groupId: groupId,
            name: name,
            phone: phone,
            idNumber: idNumber,
            businessType: businessType,
            dfName: dfName,
            gender: gender,
          );

          if (amount > 0) {
            String? loanId = await _findExistingLoan(vendorId, amount);
            loanId ??= await _upsertLoan(
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

            if (totalPaid != 0) {
              await _recordPayment(
                loanId: loanId,
                amount: totalPaid.abs(),
                date: sheetDate,
              );
            }
          }

          importedForSheet++;
        } catch (e) {
          final errMsg = 'Row error in ${sheetInfo.monthLabel} for "$name": $e';
          debugPrint(errMsg);
          errors.add(errMsg);
        }
      }

      summaries.add(MonthImportSummary(
        rawSheetLabel: sheetInfo.tabName,
        monthLabel: sheetInfo.monthLabel,
        rowsInExcel: sheetInfo.rowsInExcel,
        rowsImported: importedForSheet,
      ));
    }

    onProgress?.call(0.97, 'Verifying imported month data…');

    // 3. Build the result -----------------------------------------------
    final columnLabels = mappedFields
        .map((k) => _fieldLabels[k] ?? k)
        .toSet();

    final result = ImportResult(
      success: errors.isEmpty,
      totalRecordsInExcel: totalExcel,
      totalRecordsImported: processedRows,
      monthSummaries: summaries,
      errors: errors,
      autoAssigned: wasAutoAssigned,
      detectedMonthLabel: autoAssignMonth,
      rateColumnsFound: rateColumnsFound,
      mappedColumnLabels: columnLabels,
      newCentres: List.unmodifiable(_newCentres),
    );

    // 5. Audit log -------------------------------------------------------
    final userId =
        _supabase.auth.currentUser?.id ?? 'unknown';
    final monthBreakdown = summaries
        .map((s) => '${s.monthLabel}: ${s.rowsImported}/${s.rowsInExcel}'
            '${s.matched ? ' ✓' : ' ✗'}')
        .join(', ');

    final centreInfo = _newCentres.isEmpty
        ? 'No new centres created'
        : 'New centres: ${_newCentres.join(", ")}';

    await SystemAuditService.logAction(
      actionType: 'IMPORT',
      affectedEntity: 'EXCEL_IMPORT',
      description: 'File: $fileName | Records: $processedRows/$totalExcel | '
          'Months: $monthBreakdown | '
          'Detected month: ${autoAssignMonth ?? "multi"} | '
          'User: $userId | '
          'Rates ignored: $rateColumnsFound | '
          'Errors: ${errors.isEmpty ? "None" : errors.length} | '
          '$centreInfo',
    );

    // 6. Admin notification -------------------------------------------------
    onProgress?.call(1.0, result.verificationMessage);

    final notifTitle = wasAutoAssigned
        ? 'Data Import Complete (Auto-assigned)'
        : result.success
            ? 'Data Import Complete'
            : 'Data Import Warning';
    final notifBody = wasAutoAssigned
        ? 'Import completed. All records assigned to $autoAssignMonth.'
        : result.verificationMessage;

    await NotificationService.notifyAdmins(
      notifTitle,
      notifBody,
      type: 'SYSTEM',
    );

    return result;
  }

  // -------------------------------------------------------------------------
  // Month sheet resolution
  // -------------------------------------------------------------------------

  /// Returns (canonicalMonthName, monthNumber) if [tabName] is a month sheet,
  /// or null if it is not.  Handles full names, abbreviations, and trailing
  /// dots (e.g. "JANUARY.", "JAN", "jan.").
  (String, int)? _resolveMonthSheet(String tabName) {
    final normalised = tabName.toUpperCase().replaceAll('.', '').trim();
    for (int i = 0; i < _monthVariants.length; i++) {
      for (final variant in _monthVariants[i]) {
        if (normalised == variant) {
          // Return proper-case full month name + 1-based month number
          final fullName = _monthVariants[i][0][0] +
              _monthVariants[i][0].substring(1).toLowerCase();
          return (fullName, i + 1);
        }
      }
    }
    return null;
  }

  // -------------------------------------------------------------------------
  // Header-row detection & column mapping
  // -------------------------------------------------------------------------

  /// Known column-header aliases mapped to internal keys.
  static const _headerAliases = <String, String>{
    // Name column
    "member's name & surname": 'name',
    "member name": 'name',
    "name": 'name',
    "full name": 'name',
    // ID
    "id number": 'id_number',
    "id no": 'id_number',
    "id": 'id_number',
    // Phone / Cell
    "cell number": 'phone',
    "phone": 'phone',
    "phone number": 'phone',
    "cell": 'phone',
    // Group
    "group name": 'group_name',
    "group": 'group_name',
    // Business
    "business type": 'business_type',
    "business": 'business_type',
    // DF
    "d.f name": 'df_name',
    "df name": 'df_name',
    "facilitator": 'df_name',
    // Gender
    "gender": 'gender',
    // Centre name
    "centre name": 'centre_name',
    "center name": 'centre_name',
    "centre": 'centre_name',
    "center": 'centre_name',
    // Loan amount
    "loan amount": 'loan_amount',
    "amount": 'loan_amount',
    "principal": 'loan_amount',
    // Term
    "loan term": 'loan_term',
    "term": 'loan_term',
    "duration": 'loan_term',
    // First payment
    "1st instal payment": 'first_payment',
    "1st instalment payment": 'first_payment',
    "first instalment": 'first_payment',
    "first instalment payment": 'first_payment',
    "first payment date": 'first_payment',
    "1st payment": 'first_payment',
    "1st instalment payment date": 'first_payment',
    // Opening
    "opening amount": 'opening_amount',
    "opening balance": 'opening_amount',
    "live loan book balance": 'opening_amount',
    "loan book balance": 'opening_amount',
    "live loan balance": 'opening_amount',
    "live balance": 'opening_amount',
    // Fees
    "initiation fee": 'init_fee',
    "initiation fees": 'init_fee',
    "init fee": 'init_fee',
    "loan initiation fee": 'init_fee',
    "admin fee": 'admin_fee',
    "admin fees": 'admin_fee',
    "monthly admin fee": 'admin_fee',
    "monthly instalment": 'monthly',
    "monthly instalments": 'monthly',
    "monthly": 'monthly',
    "penalty fee": 'penalty',
    "penalty": 'penalty',
    // Paid columns
    "paid init": 'paid_init',
    "paid initiation": 'paid_init',
    "initiation fees received": 'paid_init',
    "total initiation fees received": 'paid_init',
    "paid admin": 'paid_admin',
    "admin fees received": 'paid_admin',
    "total admin fees received": 'paid_admin',
    "paid instalment": 'paid_instalment',
    "paid monthly": 'paid_instalment',
    "monthly instalments received": 'paid_instalment',
    "total monthly instalments received": 'paid_instalment',
    "paid penalty": 'paid_penalty',
    // Interest rate (detected and ignored on import)
    "interest rate": 'interest_rate',
    "rate": 'interest_rate',
    "interest": 'interest_rate',
  };

  /// Maps internal field keys to user-facing labels for column-mapping
  /// feedback in the verification message.
  static const _fieldLabels = <String, String>{
    'name': 'Name',
    'id_number': 'ID Number',
    'phone': 'Phone',
    'group_name': 'Group Name',
    'business_type': 'Business Type',
    'df_name': 'D.F Name',
    'gender': 'Gender',
    'loan_amount': 'Loan Amount',
    'loan_term': 'Loan Term',
    'first_payment': 'First Payment Date',
    'opening_amount': 'Opening Balance',
    'init_fee': 'Initiation Fee',
    'admin_fee': 'Admin Fee',
    'monthly': 'Monthly Instalment',
    'penalty': 'Penalty Fee',
    'paid_init': 'Paid Initiation',
    'paid_admin': 'Paid Admin',
    'paid_instalment': 'Paid Instalment',
    'paid_penalty': 'Paid Penalty',
    'interest_rate': 'Interest Rate',
    'centre_name': 'Centre Name',
  };

  /// Strips common prefixes/suffixes from raw column headers so that
  /// variations like "Loan Initiation fee", "Total Admin Fees Received",
  /// "1st Instalment payment date" normalise to keys we recognise.
  String _normaliseHeader(String raw) {
    String h = raw.trim().toLowerCase();
    // Strip "loan " prefix so "Loan Initiation fee" → "initiation fee"
    if (h.startsWith('loan ')) {
      h = h.substring(5);
    }
    return h;
  }

  _HeaderInfo? _detectHeaderRow(dynamic sheet) {
    // Scan first 5 rows for the header
    for (int r = 0; r < 5 && r < (sheet.maxRows as int); r++) {
      final row = sheet.rows[r] as List;
      if (row.isEmpty) continue;

      final Map<String, int> colMap = {};

      for (int c = 0; c < row.length; c++) {
        final raw = row[c]?.toString().trim().toLowerCase() ?? '';
        if (raw.isEmpty) continue;
        final normalised = _normaliseHeader(raw);
        final key = _headerAliases[normalised] ?? _headerAliases[raw];
        if (key != null && !colMap.containsKey(key)) {
          colMap[key] = c;
        }
      }

      // Accept a row as a header if it contains at least the name column
      if (colMap.containsKey('name')) {
        return _HeaderInfo(headerRow: r, dataStartRow: r + 1, cols: colMap);
      }
    }

    // If no header row with a 'name' column was found, bail out with a
    // clear error instead of guessing column positions.
    throw Exception(
      'Could not detect a header row. '
      'Expected a column named "Member\'s Name & Surname", "Name" or similar. '
      'Please check that your Excel file has a header row in the first 5 rows.',
    );
  }

  // -------------------------------------------------------------------------
  // Helper extractors
  // -------------------------------------------------------------------------

  String _str(List<dynamic> row, int? col, {String fallback = ''}) {
    if (col == null || col >= row.length) return fallback;
    final v = row[col]?.toString().trim() ?? '';
    return v.isEmpty ? fallback : v;
  }

  /// Parse a numeric cell, handling currency prefixes ("R"), thousand
  /// separators (spaces), and SA-format comma decimals ("R1 234,56").
  double _toDouble(List<dynamic> row, int? col) {
    if (col == null || col >= row.length || row[col] == null) return 0.0;
    final v = row[col];
    if (v is num) return v.toDouble();
    final raw = v.toString().trim();
    if (raw.isEmpty) return 0.0;
    // Strip currency symbol, thousand separators, normalise decimal comma
    final cleaned = raw
        .replaceAll(RegExp(r'[Rr]'), '')
        .replaceAll(' ', '')
        .replaceAll(',', '.');
    return double.tryParse(cleaned) ?? 0.0;
  }

  /// Parse an integer cell, handling trailing text like "4 Months".
  int _toInt(List<dynamic> row, int? col) {
    if (col == null || col >= row.length || row[col] == null) return 0;
    final v = row[col];
    if (v is num) return v.toInt();
    final raw = v.toString().trim();
    if (raw.isEmpty) return 0;
    // Extract leading digits (e.g. "4 Months" → 4)
    final match = RegExp(r'^\d+').firstMatch(raw);
    return match != null ? int.parse(match.group(0)!) : 0;
  }

  DateTime? _toDateTime(List<dynamic> row, int? col) {
    if (col == null || col >= row.length || row[col] == null) return null;
    final v = row[col];
    if (v is DateTime) return v;
    return DateTime.tryParse(v.toString());
  }

  // -------------------------------------------------------------------------
  // Database helpers (In-Memory Cached)
  // -------------------------------------------------------------------------

  Map<String, String> _groupIdMap = {}; // name (lower) -> id
  Map<String, String> _groupIdRefMap = {}; // id -> reference_number
  
  Map<String, String> _vendorIdNumberMap = {}; // idNumber -> id
  Map<String, String> _vendorPhoneMap = {}; // phone -> id
  Map<String, String> _vendorNameGroupMap = {}; // "name|groupId" -> id

  Map<String, String> _loanKeyMap = {}; // "vendorId|amount" -> id

  Set<String> _paymentKeySet = {}; // "loanId|amount|date" -> id

  Map<String, String> _centreNameMap = {}; // name (lower) -> id
  final List<String> _newCentres = [];

  Future<void> _preloadData() async {
    _groupIdMap.clear();
    _groupIdRefMap.clear();
    _vendorIdNumberMap.clear();
    _vendorPhoneMap.clear();
    _vendorNameGroupMap.clear();
    _loanKeyMap.clear();
    _paymentKeySet.clear();
    _centreNameMap.clear();
    _newCentres.clear();

    // Load groups
    final groups = await _supabase.from('groups').select('id, name, reference_number');
    for (var g in groups) {
      _groupIdMap[g['name'].toString().toLowerCase().trim()] = g['id'];
      _groupIdRefMap[g['id']] = g['reference_number']?.toString() ?? '';
    }

    // Load vendors
    final vendors = await _supabase.from('vendors').select('id, id_number, phone, name, group_id');
    for (var v in vendors) {
      if (v['id_number'] != null && v['id_number'].toString().trim().isNotEmpty) {
        _vendorIdNumberMap[v['id_number'].toString().trim()] = v['id'];
      }
      if (v['phone'] != null && v['phone'].toString().trim().isNotEmpty) {
        _vendorPhoneMap[v['phone'].toString().trim()] = v['id'];
      }
      _vendorNameGroupMap['${v['name']}|${v['group_id']}'] = v['id'];
    }

    // Load loans
    final loans = await _supabase.from('loans').select('id, vendor_id, amount').eq('status', 'Active');
    for (var l in loans) {
      _loanKeyMap['${l['vendor_id']}|${l['amount']}'] = l['id'];
    }

    // Load payments
    final payments = await _supabase.from('payments').select('id, loan_id, amount_paid, date_paid');
    for (var p in payments) {
      _paymentKeySet.add('${p['loan_id']}|${p['amount_paid']}|${p['date_paid']}');
    }

    // Load centres
    final centres = await _supabase.from('centers').select('id, name');
    for (var c in centres) {
      _centreNameMap[c['name'].toString().toLowerCase().trim()] = c['id'];
    }
  }

  Future<void> _recordPayment({
    required String loanId,
    required double amount,
    required DateTime date,
  }) async {
    final paymentKey = '$loanId|$amount|${date.toIso8601String()}';
    if (_paymentKeySet.contains(paymentKey)) {
      return; // Already exists
    }

    await _supabase.from('payments').insert({
      'loan_id': loanId,
      'amount_paid': amount,
      'date_paid': date.toIso8601String(),
      'payment_method': 'Imported',
    });
    
    _paymentKeySet.add(paymentKey);
  }

  Future<String> _getOrCreateCentre(String name) async {
    final lowerName = name.toLowerCase().trim();
    if (_centreNameMap.containsKey(lowerName)) {
      return _centreNameMap[lowerName]!;
    }

    final ref = 'CTR-${DateTime.now().millisecondsSinceEpoch}';
    final inserted = await _supabase
        .from('centers')
        .insert({'name': name, 'reference_number': ref})
        .select('id')
        .single();

    final newId = inserted['id'] as String;
    _centreNameMap[lowerName] = newId;
    _newCentres.add(name);
    return newId;
  }

  Future<String> _getOrCreateGroup(String name, {String? centreId, String? dfName}) async {
    final lowerName = name.toLowerCase().trim();
    if (_groupIdMap.containsKey(lowerName)) {
      final existingId = _groupIdMap[lowerName]!;
      // Update centre/DF on existing group if provided
      if (centreId != null || dfName != null) {
        final update = <String, dynamic>{};
        if (centreId != null) update['center_id'] = centreId;
        if (dfName != null) update['df_name'] = dfName;
        await _supabase.from('groups').update(update).eq('id', existingId);
      }
      return existingId;
    }

    final groupData = <String, dynamic>{
      'name': name,
      'reference_number': 'GRP-${DateTime.now().millisecondsSinceEpoch}',
    };
    if (centreId != null) groupData['center_id'] = centreId;
    if (dfName != null) groupData['df_name'] = dfName;

    final inserted = await _supabase
        .from('groups')
        .insert(groupData)
        .select('id, reference_number')
        .single();
        
    final newId = inserted['id'] as String;
    _groupIdMap[lowerName] = newId;
    _groupIdRefMap[newId] = inserted['reference_number']?.toString() ?? '';
    return newId;
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

    if (idNumber.isNotEmpty && _vendorIdNumberMap.containsKey(idNumber)) {
      existingId = _vendorIdNumberMap[idNumber];
    }

    if (existingId == null && phone.isNotEmpty && _vendorPhoneMap.containsKey(phone)) {
      existingId = _vendorPhoneMap[phone];
    }

    if (existingId == null && _vendorNameGroupMap.containsKey('$name|$groupId')) {
      existingId = _vendorNameGroupMap['$name|$groupId'];
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
      await _supabase.from('vendors').update(vendorData).eq('id', existingId);
      return existingId;
    } else {
      vendorData['reference_number'] = await _getGroupRef(groupId);
      final inserted = await _supabase
          .from('vendors')
          .insert(vendorData)
          .select('id')
          .single();
          
      final newId = inserted['id'] as String;
      
      if (idNumber.isNotEmpty) _vendorIdNumberMap[idNumber] = newId;
      if (phone.isNotEmpty) _vendorPhoneMap[phone] = newId;
      _vendorNameGroupMap['$name|$groupId'] = newId;
      
      return newId;
    }
  }

  Future<String?> _findExistingLoan(String vendorId, double amount) async {
    final key = '$vendorId|$amount';
    return _loanKeyMap[key];
  }

  Future<String> _getGroupRef(String groupId) async {
    return _groupIdRefMap[groupId] ?? 'GRP-UNKNOWN';
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
      await _supabase
          .from('loans')
          .update(loanData)
          .eq('id', existingLoanId);
      return existingLoanId;
    } else {
      final inserted = await _supabase
          .from('loans')
          .insert(loanData)
          .select('id')
          .single();
          
      final newId = inserted['id'] as String;
      _loanKeyMap['$vendorId|$amount'] = newId;
      return newId;
    }
  }

  // -------------------------------------------------------------------------
  // Backup / Restore / Clear (unchanged)
  // -------------------------------------------------------------------------

  Future<void> clearAllData() async {
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

  Future<Map<String, dynamic>> generateBackup() async {
    final Map<String, dynamic> data = {};
    final tables = [
      'groups', 'profiles', 'system_settings', 'email_outbox',
      'password_reset_requests', 'account_audit_log', 'system_audit_log',
      'vendors', 'announcements', 'group_payments', 'loans', 'comments',
      'documents', 'savings_history', 'payments',
    ];
    for (final table in tables) {
      try {
        data[table] = await _supabase.from(table).select();
      } catch (e) {
        debugPrint('Backup: Skipping table $table: $e');
        data[table] = [];
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

  Future<void> restoreBackup(Map<String, dynamic> backup) async {
    final data = backup['data'] as Map<String, dynamic>;
    await clearAllData();
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

    void safeInsert(String table) async {
      if (data[table] != null && (data[table] as List).isNotEmpty) {
        await _supabase.from(table).insert(data[table]);
      }
    }

    void safeUpsert(String table) async {
      if (data[table] != null && (data[table] as List).isNotEmpty) {
        await _supabase.from(table).upsert(data[table]);
      }
    }

    safeInsert('groups');
    safeUpsert('profiles');
    safeUpsert('system_settings');
    safeInsert('email_outbox');
    safeInsert('password_reset_requests');
    safeInsert('account_audit_log');
    safeInsert('system_audit_log');
    safeInsert('vendors');
    safeInsert('announcements');
    safeInsert('group_payments');
    safeInsert('loans');
    safeInsert('comments');
    safeInsert('documents');
    safeInsert('savings_history');
    safeInsert('payments');

    await NotificationService.notifySuperAdmin(
      'System Restored',
      'The system has been successfully restored from a backup.',
      type: 'SYSTEM',
    );
  }
}

// ---------------------------------------------------------------------------
// Private helpers
// ---------------------------------------------------------------------------

class _HeaderInfo {
  final int headerRow;
  final int dataStartRow;
  final Map<String, int> cols;
  const _HeaderInfo({
    required this.headerRow,
    required this.dataStartRow,
    required this.cols,
  });
}

class _SheetInfo {
  final String tabName;
  final String monthLabel;
  final int monthNumber;
  final dynamic sheet;
  final _HeaderInfo headerInfo;
  final int rowsInExcel;

  const _SheetInfo({
    required this.tabName,
    required this.monthLabel,
    required this.monthNumber,
    required this.sheet,
    required this.headerInfo,
    required this.rowsInExcel,
  });
}
