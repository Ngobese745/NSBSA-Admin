import 'dart:io';
import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:convert';
import 'package:universal_html/html.dart' as html;

class ExcelExportService {
  static Future<void> exportLoanHistory({
    required String memberName,
    required List<Map<String, dynamic>> loanData,
  }) async {
    var excel = Excel.createExcel();
    excel.rename('Sheet1', 'Loan History');
    Sheet sheet = excel['Loan History'];

    // Define Header Style
    CellStyle headerStyle = CellStyle(
      bold: true,
      backgroundColorHex: ExcelColor.fromHexString('#FFD700'), // Gold
      fontColorHex: ExcelColor.fromHexString('#000000'),
      horizontalAlign: HorizontalAlign.Center,
      leftBorder: Border(borderStyle: BorderStyle.Thin),
      rightBorder: Border(borderStyle: BorderStyle.Thin),
      topBorder: Border(borderStyle: BorderStyle.Thin),
      bottomBorder: Border(borderStyle: BorderStyle.Thin),
    );

    // Define Data Style
    CellStyle dataStyle = CellStyle(
      leftBorder: Border(borderStyle: BorderStyle.Thin),
      rightBorder: Border(borderStyle: BorderStyle.Thin),
      topBorder: Border(borderStyle: BorderStyle.Thin),
      bottomBorder: Border(borderStyle: BorderStyle.Thin),
    );

    // Add headers
    List<String> headers = [
      'Loan Date',
      'Amount',
      'Type',
      'Duration',
      'Status',
      'Total Paid',
      'Arrears',
      'Balance'
    ];
    for (var i = 0; i < headers.length; i++) {
      var cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
      cell.value = TextCellValue(headers[i]);
      cell.cellStyle = headerStyle;
      sheet.setColumnWidth(i, 15);
    }

    // Add data
    for (var r = 0; r < loanData.length; r++) {
      var row = loanData[r];
      List<CellValue> values = [
        TextCellValue(row['date'] ?? ''),
        DoubleCellValue(row['amount'] ?? 0.0),
        TextCellValue(row['type'] ?? ''),
        IntCellValue(row['duration'] ?? 0),
        TextCellValue(row['status'] ?? ''),
        DoubleCellValue(row['totalPaid'] ?? 0.0),
        DoubleCellValue(row['arrears'] ?? 0.0),
        DoubleCellValue(row['balance'] ?? 0.0),
      ];

      for (var c = 0; c < values.length; c++) {
        var cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: r + 1));
        cell.value = values[c];
        cell.cellStyle = dataStyle;
      }
    }

    await _saveExcel(excel, '${memberName.replaceAll(' ', '_')}_Loan_History.xlsx');
  }

  static Future<void> exportMasterLedger({
    required Map<String, dynamic> summary,
    required List<List<String>> ledgerData,
  }) async {
    var excel = Excel.createExcel();
    
    // 1. Dashboard Sheet
    excel.rename('Sheet1', 'Dashboard');
    Sheet dash = excel['Dashboard'];

    // Styles
    CellStyle titleStyle = CellStyle(
      bold: true,
      fontSize: 16,
      fontColorHex: ExcelColor.fromHexString('#FFD700'), // Gold
      backgroundColorHex: ExcelColor.fromHexString('#1A1A1A'), // Dark
      horizontalAlign: HorizontalAlign.Center,
    );

    CellStyle kpiLabelStyle = CellStyle(
      bold: true,
      fontSize: 12,
      backgroundColorHex: ExcelColor.fromHexString('#F5F5F5'),
    );

    CellStyle kpiValueStyle = CellStyle(
      fontSize: 12,
      bold: true,
      fontColorHex: ExcelColor.fromHexString('#000000'),
    );

    CellStyle headerStyle = CellStyle(
      bold: true,
      backgroundColorHex: ExcelColor.fromHexString('#FFD700'),
      fontColorHex: ExcelColor.fromHexString('#000000'),
      horizontalAlign: HorizontalAlign.Center,
      leftBorder: Border(borderStyle: BorderStyle.Thin),
      rightBorder: Border(borderStyle: BorderStyle.Thin),
      topBorder: Border(borderStyle: BorderStyle.Thin),
      bottomBorder: Border(borderStyle: BorderStyle.Thin),
    );

    CellStyle dataStyle = CellStyle(
      leftBorder: Border(borderStyle: BorderStyle.Thin),
      rightBorder: Border(borderStyle: BorderStyle.Thin),
      topBorder: Border(borderStyle: BorderStyle.Thin),
      bottomBorder: Border(borderStyle: BorderStyle.Thin),
    );

    // Header / Branding
    dash.merge(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0), 
               CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: 0));
    var titleCell = dash.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0));
    titleCell.value = TextCellValue('NSBSA FINANCIAL REPORT - MASTER LEDGER');
    titleCell.cellStyle = titleStyle;
    dash.setRowHeight(0, 40);

    dash.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 2)).value = TextCellValue('Report Generated:');
    dash.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: 2)).value = TextCellValue(DateTime.now().toString().substring(0, 16));

    if (summary['period'] != null) {
      dash.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 3)).value = TextCellValue('Report Period:');
      dash.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: 3)).value = TextCellValue(summary['period'].toString());
    }

    // KPI Section
    List<Map<String, String>> kpis = [
      {'label': 'Total Disbursed', 'value': 'R ${summary['totalDisbursed']}'},
      {'label': 'Total Collected', 'value': 'R ${summary['totalCollected']}'},
      {'label': 'Outstanding Capital', 'value': 'R ${summary['totalOutstanding']}'},
      {'label': 'Total Savings', 'value': 'R ${summary['totalSavings']}'},
      {'label': 'Total Expected Fees', 'value': 'R ${summary['totalExpectedFees']}'},
      {'label': 'Collection Rate', 'value': '${summary['collectionRate']}%'},
    ];

    int kpiStartRow = 5;
    for (var i = 0; i < kpis.length; i++) {
      var labelCell = dash.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: kpiStartRow + i));
      labelCell.value = TextCellValue(kpis[i]['label']!);
      labelCell.cellStyle = kpiLabelStyle;

      var valueCell = dash.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: kpiStartRow + i));
      valueCell.value = TextCellValue(kpis[i]['value']!);
      valueCell.cellStyle = kpiValueStyle;
      
      dash.setColumnWidth(0, 25);
      dash.setColumnWidth(1, 20);
    }

    // 2. Ledger Sheet
    Sheet ledger = excel['Master Loan Ledger'];
    
    // Header row with branding
    ledger.merge(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0), 
                 CellIndex.indexByColumnRow(columnIndex: 12, rowIndex: 0));
    var ledgerTitle = ledger.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0));
    ledgerTitle.value = TextCellValue('DETAILED LOAN LEDGER');
    ledgerTitle.cellStyle = titleStyle;

    for (var r = 0; r < ledgerData.length; r++) {
      for (var c = 0; c < ledgerData[r].length; c++) {
        var cell = ledger.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: r + 2));
        cell.value = TextCellValue(ledgerData[r][c]);
        
        if (r == 0) {
          cell.cellStyle = headerStyle;
          ledger.setColumnWidth(c, ledgerData[r][c].length + 10.0);
        } else {
          cell.cellStyle = dataStyle;
        }
      }
    }

    await _saveExcel(excel, 'NSBSA_Master_Ledger_${DateTime.now().millisecondsSinceEpoch}.xlsx');
  }

  static Future<void> exportTableReport({
    required String title,
    required List<List<String>> data,
  }) async {
    var excel = Excel.createExcel();
    String sheetName = title.length > 30 ? title.substring(0, 30) : title;
    excel.rename('Sheet1', sheetName);
    Sheet sheet = excel[sheetName];

    // Define Header Style
    CellStyle headerStyle = CellStyle(
      bold: true,
      backgroundColorHex: ExcelColor.fromHexString('#FFD700'),
      fontColorHex: ExcelColor.fromHexString('#000000'),
      horizontalAlign: HorizontalAlign.Center,
      leftBorder: Border(borderStyle: BorderStyle.Thin),
      rightBorder: Border(borderStyle: BorderStyle.Thin),
      topBorder: Border(borderStyle: BorderStyle.Thin),
      bottomBorder: Border(borderStyle: BorderStyle.Thin),
    );

    // Define Data Style
    CellStyle dataStyle = CellStyle(
      leftBorder: Border(borderStyle: BorderStyle.Thin),
      rightBorder: Border(borderStyle: BorderStyle.Thin),
      topBorder: Border(borderStyle: BorderStyle.Thin),
      bottomBorder: Border(borderStyle: BorderStyle.Thin),
    );

    // Determine which row is the header
    int headerRowIndex = 0;
    for (var i = 0; i < data.length; i++) {
      if (data[i].length > 2) {
        headerRowIndex = i;
        break;
      }
    }

    for (var r = 0; r < data.length; r++) {
      for (var c = 0; c < data[r].length; c++) {
        var cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: r));
        cell.value = TextCellValue(data[r][c]);
        
        if (r == headerRowIndex && data[r].length > 1) {
          cell.cellStyle = headerStyle;
          sheet.setColumnWidth(c, data[r][c].length + 8.0);
        } else {
          cell.cellStyle = dataStyle;
        }
      }
    }

    await _saveExcel(excel, '${title.replaceAll(' ', '_')}.xlsx');
  }

  static Future<void> _saveExcel(Excel excel, String fileName) async {
    final bytes = excel.encode();
    if (bytes == null) return;

    if (kIsWeb) {
      final content = base64Encode(bytes);
      final anchor = html.AnchorElement(
          href: 'data:application/vnd.openxmlformats-officedocument.spreadsheetml.sheet;base64,$content')
        ..setAttribute('download', fileName)
        ..click();
    } else {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/$fileName');
      await file.writeAsBytes(bytes);
    }
  }
}
