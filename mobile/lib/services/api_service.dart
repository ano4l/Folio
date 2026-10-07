import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/document.dart';
import 'document_scanner.dart';

class ApiException implements Exception {
  final String message;
  final int statusCode;
  const ApiException(this.message, [this.statusCode = 0]);
  @override
  String toString() => message;
}

class ApiService {
  ApiService({http.Client? client}) : _client = client ?? http.Client();

  static const _configuredBase = String.fromEnvironment(
    'FOLIO_API_URL',
    defaultValue: 'https://folio-vn1g-two.vercel.app/api',
  );
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );
  static const _sessionKey = 'folio_session_cookie';

  final http.Client _client;
  String? _sessionCookie;
  int _sessionGeneration = 0;
  Future<void> _sessionWrites = Future.value();
  String get baseUrl => _configuredBase.replaceAll(RegExp(r'/$'), '');

  Future<void> initialize() async {
    final generation = _sessionGeneration;
    await _sessionWrites;
    final cookie = await _storage.read(key: _sessionKey);
    if (generation == _sessionGeneration) _sessionCookie = cookie;
  }

  Future<void> _saveCookie(String? value) {
    _sessionWrites = _sessionWrites
        .catchError((Object _) {})
        .then(
          (_) =>
              value == null
                  ? _storage.delete(key: _sessionKey)
                  : _storage.write(key: _sessionKey, value: value),
        );
    return _sessionWrites;
  }

  Future<Map<String, dynamic>> _request(
    String path, {
    String method = 'GET',
    Map<String, dynamic>? body,
  }) async {
    final generation = _sessionGeneration;
    final uri = Uri.parse('$baseUrl$path');
    final headers = <String, String>{
      'Accept': 'application/json',
      if (_sessionCookie != null) 'Cookie': _sessionCookie!,
      if (method != 'GET') 'X-Requested-With': 'FolioWeb',
      if (body != null) 'Content-Type': 'application/json',
    };
    late http.Response response;
    try {
      final encoded = body == null ? null : jsonEncode(body);
      response = switch (method) {
        'POST' => await _client
            .post(uri, headers: headers, body: encoded)
            .timeout(const Duration(seconds: 65)),
        'DELETE' => await _client
            .delete(uri, headers: headers, body: encoded)
            .timeout(const Duration(seconds: 30)),
        _ => await _client
            .get(uri, headers: headers)
            .timeout(const Duration(seconds: 30)),
      };
    } on TimeoutException {
      throw const ApiException(
        'Folio took too long to respond. Please try again.',
      );
    } on SocketException {
      throw const ApiException('Check your connection and try again.');
    } catch (_) {
      throw const ApiException(
        'Folio could not connect securely. Please try again.',
      );
    }
    if (generation != _sessionGeneration) {
      throw const ApiException('Session changed. Please sign in again.', 401);
    }
    await _captureSession(response);
    final decoded = _decode(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        '${decoded['message'] ?? 'Request failed'}',
        response.statusCode,
      );
    }
    if (response.body.trim().isNotEmpty) {
      try {
        if (jsonDecode(response.body) is! Map<String, dynamic>) {
          throw const FormatException();
        }
      } catch (_) {
        throw const ApiException(
          'Folio returned an invalid response. Please try again.',
        );
      }
    }
    return decoded;
  }

  Map<String, dynamic> _decode(String value) {
    if (value.trim().isEmpty) return <String, dynamic>{};
    try {
      final decoded = jsonDecode(value);
      return decoded is Map<String, dynamic>
          ? decoded
          : <String, dynamic>{'data': decoded};
    } catch (_) {
      return <String, dynamic>{};
    }
  }

  Future<void> _captureSession(http.Response response) async {
    final raw = response.headers['set-cookie'];
    if (raw == null) return;
    final match = RegExp(r'(FOLIO_SESSION=[^;,\s]*)').firstMatch(raw);
    if (match == null) return;
    final cookie = match.group(1)!;
    if (cookie.endsWith('=')) {
      await clearSession();
    } else {
      _sessionCookie = cookie;
      await _saveCookie(cookie);
    }
  }

  Future<AuthUser> currentUser() async =>
      AuthUser.fromJson(await _request('/v1/auth/me'));

  Future<Map<String, dynamic>> beginAuth({
    required String mode,
    required String email,
    required String password,
    String? displayName,
  }) => _request(
    '/v1/auth/$mode',
    method: 'POST',
    body: {
      'email': email.trim(),
      'password': password,
      if (mode == 'register') 'displayName': displayName?.trim(),
    },
  );

  Future<AuthUser> verifyOtp(String challengeId, String code) async =>
      AuthUser.fromJson(
        await _request(
          '/v1/auth/verify',
          method: 'POST',
          body: {'challengeId': challengeId, 'code': code},
        ),
      );

  Future<Map<String, dynamic>> resendOtp(String challengeId) => _request(
    '/v1/auth/resend',
    method: 'POST',
    body: {'challengeId': challengeId},
  );

  Future<void> logout() async {
    final revocation = _request(
      '/v1/auth/logout',
      method: 'POST',
    ).catchError((Object _) => <String, dynamic>{});
    await clearSession();
    await revocation;
  }

  Future<void> clearSession() async {
    _sessionGeneration++;
    _sessionCookie = null;
    await _saveCookie(null);
  }

  Future<List<Document>> fetchDocuments() async {
    final json = await _request('/v1/documents');
    if (json['documents'] is! List) {
      throw const ApiException(
        'The vault response was incomplete. Your saved documents are unchanged.',
      );
    }
    return (json['documents'] as List? ?? const [])
        .whereType<Map>()
        .map((value) => Document.fromJson(Map<String, dynamic>.from(value)))
        .toList();
  }

  Future<void> deleteDocument(String documentId) =>
      _request('/v1/documents/$documentId', method: 'DELETE');

  Future<void> restoreDocument(String documentId) => _request(
    '/v1/documents/restore',
    method: 'POST',
    body: {'documentId': documentId},
  );

  Future<String> uploadDocument({
    required String filePath,
    required String title,
    String category = 'Document',
    ValueChanged<String>? onStage,
  }) async {
    final generation = _sessionGeneration;
    void ensureCurrent() {
      if (generation != _sessionGeneration) {
        throw const ApiException(
          'Upload interrupted because the account changed.',
          401,
        );
      }
    }

    final file = File(filePath);
    final size = await file.length();
    if (size < 1 || size > 20 * 1024 * 1024) {
      throw const ApiException('Choose a file smaller than 20 MB.');
    }
    onStage?.call('Preparing secure upload…');
    final bytes = await file.readAsBytes();
    final fileName = file.uri.pathSegments.last;
    final mimeType = _mimeType(fileName);
    onStage?.call('Reading text on your device…');
    List<Map<String, dynamic>> extractedPages = [];
    try {
      extractedPages = await DocumentScanner.extract(filePath);
    } catch (_) {
      onStage?.call(
        'Device reading unavailable. Uploading original for review…',
      );
    }
    ensureCurrent();
    final prepared = await _request(
      '/v1/documents/upload-url',
      method: 'POST',
      body: {
        'title': title.trim(),
        'category': category,
        'fileName': fileName,
        'mimeType': mimeType,
        'byteSize': bytes.length,
      },
    );
    final signedUrl = '${prepared['signedUrl'] ?? ''}';
    if (signedUrl.isEmpty) {
      throw const ApiException('Secure upload could not be prepared.');
    }
    onStage?.call('Uploading document…');
    ensureCurrent();
    final upload = await _client
        .put(
          Uri.parse(signedUrl),
          headers: {'Content-Type': mimeType, 'x-upsert': 'false'},
          body: bytes,
        )
        .timeout(const Duration(seconds: 90));
    if (upload.statusCode < 200 || upload.statusCode >= 300) {
      throw const ApiException('The document did not reach secure storage.');
    }
    final documentId = '${prepared['documentId']}';
    onStage?.call('Confirming upload…');
    ensureCurrent();
    await _request(
      '/v1/documents/complete',
      method: 'POST',
      body: {'documentId': documentId},
    );
    onStage?.call('Reading and summarising…');
    ensureCurrent();
    try {
      final result = await _request(
        '/v1/documents/process',
        method: 'POST',
        body: {
          'documentId': documentId,
          if (extractedPages.isNotEmpty) 'extractedPages': extractedPages,
        },
      );
      return '${result['status'] ?? 'UPLOADED'}';
    } on ApiException catch (error) {
      if (error.statusCode == 401) rethrow;
      // The original is safely stored. Do not invite a duplicate upload when processing times out.
      return 'PROCESSING_PENDING';
    }
  }

  Future<String> reprocessDocument(String documentId) async {
    final result = await _request(
      '/v1/documents/process',
      method: 'POST',
      body: {'documentId': documentId},
    );
    return '${result['status'] ?? 'REVIEW_REQUIRED'}';
  }

  Future<Uri> originalDocument(String documentId) async {
    final result = await _request(
      '/v1/documents/source',
      method: 'POST',
      body: {'documentId': documentId},
    );
    final uri = Uri.tryParse('${result['url'] ?? ''}');
    if (uri == null || uri.scheme != 'https') {
      throw const ApiException('The original document is unavailable.');
    }
    return uri;
  }

  Stream<Map<String, dynamic>> ask({
    required String question,
    required List<ChatMessage> history,
    String? documentId,
    Future<void>? abortTrigger,
  }) async* {
    final request =
        http.AbortableRequest(
            'POST',
            Uri.parse('$baseUrl/v1/ai/ask'),
            abortTrigger: abortTrigger,
          )
          ..headers.addAll({
            'Accept': 'application/x-ndjson',
            'Content-Type': 'application/json',
            'X-Requested-With': 'FolioWeb',
            if (_sessionCookie != null) 'Cookie': _sessionCookie!,
          })
          ..body = jsonEncode({
            'question': question,
            'history':
                history
                    .skip(history.length > 10 ? history.length - 10 : 0)
                    .map((item) => {'role': item.role, 'text': item.text})
                    .toList(),
            'documentId': documentId,
          });
    final response = await _client
        .send(request)
        .timeout(const Duration(seconds: 50));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final text = await response.stream.bytesToString();
      throw ApiException(
        '${_decode(text)['message'] ?? 'The document assistant is unavailable.'}',
        response.statusCode,
      );
    }
    await for (final line in response.stream
        .timeout(const Duration(seconds: 50))
        .transform(utf8.decoder)
        .transform(const LineSplitter())) {
      if (line.trim().isEmpty) continue;
      final value = jsonDecode(line);
      if (value is Map<String, dynamic>) yield value;
    }
  }

  String _mimeType(String fileName) {
    final lower = fileName.toLowerCase();
    if (lower.endsWith('.pdf')) return 'application/pdf';
    if (lower.endsWith('.docx')) {
      return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
    }
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return 'image/jpeg';
    throw const ApiException(
      'Only PDF, DOCX, JPG, and PNG files are supported.',
    );
  }

  void dispose() => _client.close();
}
