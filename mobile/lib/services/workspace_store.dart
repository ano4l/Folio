import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Account-specific device cache. Never store vault text in plain preferences.
class WorkspaceStore {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );
  Future<Map<String, dynamic>> read(String userId) async {
    final value = await _storage.read(key: 'folio_workspace_v1_$userId');
    if (value == null) return {};
    return compute(_decodeWorkspace, value);
  }

  Future<void> write(String userId, Map<String, dynamic> value) async {
    final encoded = await compute(_encodeWorkspace, value);
    await _storage.write(key: 'folio_workspace_v1_$userId', value: encoded);
  }
}

String _encodeWorkspace(Map<String, dynamic> value) => jsonEncode(value);
Map<String, dynamic> _decodeWorkspace(String value) =>
    Map<String, dynamic>.from(jsonDecode(value) as Map);

/// Copy mutable collections before queued writes without encoding/decoding all
/// document text on the UI isolate. Strings and other JSON scalars are immutable.
Map<String, dynamic> snapshotWorkspace(Map<String, dynamic> value) =>
    _copyJson(value) as Map<String, dynamic>;

Object? _copyJson(Object? value) {
  if (value is Map) {
    return <String, dynamic>{
      for (final entry in value.entries)
        entry.key as String: _copyJson(entry.value),
    };
  }
  if (value is List) return value.map(_copyJson).toList();
  return value;
}
