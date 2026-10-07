import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Account-specific device cache. Never store vault text in plain preferences.
class WorkspaceStore {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );
  Future<Map<String, dynamic>> read(String userId) async {
    final value = await _storage.read(key: 'folio_workspace_v1_$userId');
    if (value == null) return {};
    return Map<String, dynamic>.from(jsonDecode(value) as Map);
  }

  Future<void> write(String userId, Map<String, dynamic> value) => _storage
      .write(key: 'folio_workspace_v1_$userId', value: jsonEncode(value));
}
