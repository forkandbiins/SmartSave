import 'package:smartsave_backend/src/errors/smartsave_error.dart';

import 'persisted_data.dart';
import 'smartsave_store.dart';

/// An in-memory store for mock mode and tests.
final class InMemoryStore implements SmartSaveStore {
  /// Creates an empty in-memory store, optionally seeded with [initialData].
  InMemoryStore({PersistedData? initialData}) : _data = initialData ?? PersistedData.empty();

  PersistedData _data;

  /// Makes the next load fail with a storage error.
  bool failNextLoad = false;

  /// Makes the next save fail with a storage error.
  bool failNextSave = false;

  @override
  Future<PersistedData> load() async {
    if (failNextLoad) {
      failNextLoad = false;
      throw const StorageError.readFailed();
    }
    return _data;
  }

  @override
  Future<void> save(PersistedData data) async {
    if (failNextSave) {
      failNextSave = false;
      throw const StorageError.writeFailed();
    }
    _data = data;
  }

  @override
  Future<void> clear() async {
    _data = PersistedData.empty();
  }
}
