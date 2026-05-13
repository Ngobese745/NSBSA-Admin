import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:io';

void main() async {
  // Load env variables
  final envFile = File('.env');
  if (!envFile.existsSync()) {
    print('Error: .env file not found');
    return;
  }

  await dotenv.load(fileName: ".env");
  
  final supabaseUrl = dotenv.env['SUPABASE_URL'] ?? '';
  final supabaseKey = dotenv.env['SUPABASE_ANON_KEY'] ?? '';

  if (supabaseUrl.isEmpty || supabaseKey.isEmpty) {
    print('Error: SUPABASE_URL or SUPABASE_ANON_KEY is missing in .env');
    return;
  }

  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseKey,
  );

  final client = Supabase.instance.client;

  try {
    // 1. Deactivate existing keys for smsworx
    await client
        .from('api_keys')
        .update({'status': 'replaced', 'updated_at': DateTime.now().toIso8601String()})
        .eq('service_name', 'smsworx')
        .eq('status', 'active');

    // 2. Insert new key
    final clientId = '7d5304c2-8cee-4dd3-bcdb-d0d8a46ee541';
    final apiSecret = '7222b942-c2e6-4785-bbaf-5caec982f75a';
    final combinedKey = '$clientId:$apiSecret';

    await client.from('api_keys').insert({
      'service_name': 'smsworx',
      'label': 'Production SMSWorx API',
      'api_key': combinedKey,
      'status': 'active',
      'metadata': {
        'client_id': clientId,
        'description': 'Main SMS gateway for payment reminders and announcements'
      }
    });

    print('Successfully inserted SMSWorx API keys into the database.');
  } catch (e) {
    print('Error inserting API keys: $e');
  } finally {
    exit(0);
  }
}
