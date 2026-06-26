import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class IDriveE2Service {
  static final IDriveE2Service instance = IDriveE2Service._();
  IDriveE2Service._();

  // ──────────────────────────────────────────────────────────────────────────
  // Credential helpers
  // ──────────────────────────────────────────────────────────────────────────

  /// Returns { accessKeyId, secretAccessKey, endpoint, bucket }
  /// stored as colon‑separated string:  accessKeyId:secretAccessKey:endpoint:bucket
  Future<Map<String, String>?> _getCredentials() async {
    try {
      final response = await Supabase.instance.client
          .from('api_keys')
          .select('api_key')
          .eq('service_name', 'idrive_e2')
          .eq('status', 'active')
          .maybeSingle();

      if (response == null) return null;
      final raw = response['api_key']?.toString();
      if (raw == null || raw.isEmpty) return null;

      final parts = raw.split(':');
      if (parts.length < 4) return null;

      return {
        'accessKeyId': parts[0],
        'secretAccessKey': parts[1],
        'endpoint': parts[2],
        'bucket': parts[3],
      };
    } catch (_) {
      return null;
    }
  }

  Map<String, String>? _cachedCreds;

  Future<bool> loadCredentials() async {
    _cachedCreds = await _getCredentials();
    return _cachedCreds != null;
  }

  // ──────────────────────────────────────────────────────────────────────────
  // AWS Signature V4 helpers
  // ──────────────────────────────────────────────────────────────────────────

  String _sha256(String data) {
    return sha256.convert(utf8.encode(data)).toString();
  }

  String _sha256Bytes(List<int> data) {
    return sha256.convert(data).toString();
  }

  String _hmacSha256(String key, String data) {
    final hmacSha256 = Hmac(sha256, utf8.encode(key));
    return hmacSha256.convert(utf8.encode(data)).toString();
  }

  List<int> _hmacSha256Bytes(List<int> key, String data) {
    final hmac = Hmac(sha256, key);
    return hmac.convert(utf8.encode(data)).bytes;
  }

  String _signatureKey(String secretKey, String date, String region, String service) {
    final kDate = _hmacSha256Bytes(utf8.encode('AWS4$secretKey'), date);
    final kRegion = _hmacSha256Bytes(kDate, region);
    final kService = _hmacSha256Bytes(kRegion, service);
    final kSigning = _hmacSha256Bytes(kService, 'aws4_request');
    return base64.encode(kSigning);
  }

  /// Returns the region from the endpoint, e.g. "us-east-1"
  String _extractRegion(String endpoint) {
    final uri = Uri.tryParse(endpoint);
    if (uri == null) return 'us-east-1';
    final host = uri.host;
    final parts = host.split('.');
    if (parts.length >= 3) return parts[1];
    return 'us-east-1';
  }

  // ──────────────────────────────────────────────────────────────────────────
  // HTTP S3 request with Signature V4 signing
  // ──────────────────────────────────────────────────────────────────────────

  Future<http.Response> _s3Request({
    required String method,
    required String bucket,
    required String key,
    Uint8List? body,
    Map<String, String>? extraHeaders,
  }) async {
    final creds = _cachedCreds;
    if (creds == null) throw Exception('iDrive e2 credentials not loaded.');

    final accessKey = creds['accessKeyId']!;
    final secretKey = creds['secretAccessKey']!;
    final endpoint = creds['endpoint']!;
    final region = _extractRegion(endpoint);
    final service = 's3';

    final now = DateTime.now().toUtc();
    final amzDate = DateFormat("yyyyMMdd'T'HHmmss'Z'").format(now);
    final dateStamp = DateFormat('yyyyMMdd').format(now);

    final host = Uri.parse(endpoint).host;
    final uri = Uri.parse('$endpoint/$bucket/$key');
    final canonicalUri = '/$bucket/$key';
    final canonicalQueryString = '';
    final payloadHash = body != null ? _sha256Bytes(body) : 'UNSIGNED-PAYLOAD';

    final canonicalHeaders = 'host:$host\nx-amz-content-sha256:$payloadHash\nx-amz-date:$amzDate\n';
    final signedHeaders = 'host;x-amz-content-sha256;x-amz-date';

    final canonicalRequest = [
      method,
      canonicalUri,
      canonicalQueryString,
      canonicalHeaders,
      signedHeaders,
      payloadHash,
    ].join('\n');

    final credentialScope = '$dateStamp/$region/$service/aws4_request';
    final stringToSign = [
      'AWS4-HMAC-SHA256',
      amzDate,
      credentialScope,
      _sha256(canonicalRequest),
    ].join('\n');

    final signingKey = _signatureKey(secretKey, dateStamp, region, service);
    final signature = _hmacSha256(signingKey, stringToSign);

    final authorization = 'AWS4-HMAC-SHA256 '
        'Credential=$accessKey/$credentialScope, '
        'SignedHeaders=$signedHeaders, '
        'Signature=$signature';

    final headers = <String, String>{
      'Host': host,
      'x-amz-date': amzDate,
      'x-amz-content-sha256': payloadHash,
      'Authorization': authorization,
      if (extraHeaders != null) ...extraHeaders,
    };

    final request = http.Request(method, uri);
    request.headers.addAll(headers);
    if (body != null) request.bodyBytes = body;

    final client = http.Client();
    try {
      final streamed = await client.send(request);
      return await http.Response.fromStream(streamed);
    } finally {
      client.close();
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Public API
  // ──────────────────────────────────────────────────────────────────────────

  /// Upload a file to iDrive e2.
  Future<String> uploadFile({
    required String key,
    required Uint8List bytes,
    required String contentType,
  }) async {
    final creds = await _getCredentials();
    if (creds == null) throw Exception('iDrive e2 not configured.');
    _cachedCreds = creds;

    final response = await _s3Request(
      method: 'PUT',
      bucket: creds['bucket']!,
      key: key,
      body: bytes,
      extraHeaders: {'Content-Type': contentType},
    );

    if (response.statusCode == 200 || response.statusCode == 204) {
      return '${creds['endpoint']}/${creds['bucket']}/$key';
    }
    throw Exception('iDrive e2 upload failed (${response.statusCode}): ${response.body}');
  }

  /// Download a file from iDrive e2.
  Future<Uint8List?> downloadFile(String key) async {
    final creds = await _getCredentials();
    if (creds == null) return null;
    _cachedCreds = creds;

    final response = await _s3Request(
      method: 'GET',
      bucket: creds['bucket']!,
      key: key,
    );

    if (response.statusCode == 200) {
      return response.bodyBytes;
    }
    return null;
  }

  /// Delete a file from iDrive e2.
  Future<bool> deleteFile(String key) async {
    final creds = await _getCredentials();
    if (creds == null) return false;
    _cachedCreds = creds;

    final response = await _s3Request(
      method: 'DELETE',
      bucket: creds['bucket']!,
      key: key,
    );

    return response.statusCode == 204 || response.statusCode == 200;
  }

  /// List files in the bucket (optional prefix).
  Future<List<Map<String, dynamic>>> listFiles({String? prefix}) async {
    final creds = await _getCredentials();
    if (creds == null) return [];
    _cachedCreds = creds;

    final qs = prefix != null ? '?prefix=$prefix' : '';
    final response = await _s3Request(
      method: 'GET',
      bucket: creds['bucket']!,
      key: qs,
    );

    if (response.statusCode != 200) return [];

    // Simple XML parsing for S3 ListBucketResult
    final body = response.body;
    final files = <Map<String, dynamic>>[];
    final keyRegex = RegExp(r'<Key>(.*?)</Key>');
    final sizeRegex = RegExp(r'<Size>(\d+)</Size>');
    final modRegex = RegExp(r'<LastModified>(.*?)</LastModified>');

    final keys = keyRegex.allMatches(body).map((m) => m.group(1)).toList();
    final sizes = sizeRegex.allMatches(body).map((m) => m.group(1)).toList();
    final mods = modRegex.allMatches(body).map((m) => m.group(1)).toList();

    for (var i = 0; i < keys.length && i < sizes.length; i++) {
      files.add({
        'key': keys[i],
        'size': int.tryParse(sizes[i] ?? '0') ?? 0,
        'lastModified': mods.length > i ? mods[i] : null,
      });
    }
    return files;
  }

  /// Test connection to iDrive e2.
  Future<bool> testConnection({
    required String accessKeyId,
    required String secretAccessKey,
    required String endpoint,
    required String bucket,
  }) async {
    // Temporarily set credentials for the test
    _cachedCreds = {
      'accessKeyId': accessKeyId,
      'secretAccessKey': secretAccessKey,
      'endpoint': endpoint,
      'bucket': bucket,
    };

    try {
      // Try to list bucket (head bucket would be better, but list prefix works)
      final response = await _s3Request(
        method: 'GET',
        bucket: bucket,
        key: '?max-keys=1',
      );
      return response.statusCode == 200;
    } catch (_) {
      return false;
    } finally {
      _cachedCreds = null;
    }
  }
}
