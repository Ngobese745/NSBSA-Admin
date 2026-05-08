import 'dart:io';
import 'package:spreadsheet_decoder/spreadsheet_decoder.dart';

void main() {
  var file = File('/Users/colanengobese/Downloads/VES Loan Book 2026  template.xlsx');
  var bytes = file.readAsBytesSync();
  var decoder = SpreadsheetDecoder.decodeBytes(bytes);
  for (var table in decoder.tables.keys) {
    if (table.toUpperCase().trim() == 'JANUARY.') {
      var sheet = decoder.tables[table]!;
      for(int i = 0; i < 5; i++) {
         print('Row $i: ${sheet.rows[i]}');
      }
      break;
    }
  }
}
