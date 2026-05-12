import 'package:flutter/services.dart';
import 'package:pdf/widgets.dart' as pw;

import 'app_assets.dart';

/// NSBSA logo as [pw.MemoryImage] for PDF headers (single load path).
abstract final class PdfBranding {
  static Future<pw.MemoryImage> loadLogo() async {
    final data = await rootBundle.load(AppAssets.logo);
    return pw.MemoryImage(data.buffer.asUint8List());
  }
}
