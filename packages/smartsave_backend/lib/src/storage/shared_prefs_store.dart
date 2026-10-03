import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:smartsave_backend/src/errors/smartsave_error.dart';

import 'persisted_data.dart';
import 'smartsave_store.dart';

/// A JSON-backed [SmartSaveStore] using one SharedPreferences key.
final class SharedPrefsStore implements SmartSaveStore {
  /// Creates a store using [prefs] and [key].
  SharedPrefsStore(this.prefs, {this.key = 'smartsave.v1'});

  /// SharedPreferences backend.
  final SharedPreferences prefs;

  /// Key containing the complete JSON snapshot.
  final String key;

  @override
  Future<PersistedData> load() async {
    try {
      final encoded = prefs.getString(key);
      if (encoded == null) return PersistedData.empty();
      final decoded = jsonDecode(encoded);
      if (decoded is! Map) throw const StorageError.corrupt();
      return PersistedData.fromJson(Map<String, Object?>.from(decoded));
    } on StorageError {
      rethrow;
    } on FormatException catch (error) {
      throw StorageError.corrupt(error);
    } catch (error) {
      throw StorageError.readFailed(error);
    }
  }

  @override
  Future<void> save(PersistedData data) async {
    try {
      final success = await prefs.setString(key, jsonEncode(data.toJson()));
      if (!success) throw const StorageError.writeFailed();
    } on StorageError {
      rethrow;
    } catch (error) {
      throw StorageError.writeFailed(error);
    }
  }

  @override
  Future<void> clear() async {
    try {
      final success = await prefs.remove(key);
      if (!success && prefs.containsKey(key)) {
        throw const StorageError.writeFailed();
      }
    } on StorageError {
      rethrow;
    } catch (error) {
      throw StorageError.writeFailed(error);
    }
  }
}
