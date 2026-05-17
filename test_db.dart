import 'package:supabase/supabase.dart';
import 'package:dotenv/dotenv.dart';

void main() async {
  var env = DotEnv(includePlatformEnvironment: true)..load();
  final supabaseUrl = env['SUPABASE_URL']!;
  final supabaseKey = env['SUPABASE_ANON_KEY']!;
  final client = SupabaseClient(supabaseUrl, supabaseKey);

  try {
    await client.from('vendors').select('email').limit(1);
    print('SUCCESS: email column exists.');
  } catch (e) {
    print('ERROR: $e');
  }
}
