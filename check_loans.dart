import 'dart:io';
import 'package:supabase/supabase.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

void main() async {
  await dotenv.load(fileName: ".env.production");
  final client = SupabaseClient(
    dotenv.env['SUPABASE_URL']!,
    dotenv.env['SUPABASE_ANON_KEY']!,
  );

  final res = await client.from('loans').select().limit(5);
  for (var row in res) {
    print('Loan ID: ${row['id']}');
    print('Duration: ${row['duration_months']}');
    print('First Instalment Date: ${row['first_instalment_date']}');
    print('Admin Fee: ${row['monthly_admin_fee']}');
    print('---');
  }
}
