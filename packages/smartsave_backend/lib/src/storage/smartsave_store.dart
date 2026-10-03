import 'persisted_data.dart';

/// Storage boundary used by the repository.
///
/// The prototype stores the complete object in one operation. This is suitable
/// for thousands of transactions, but not tens of thousands. A later
/// sqflite/drift implementation only needs to implement this interface.
abstract interface class SmartSaveStore {
  /// Loads the complete persisted snapshot.
  Future<PersistedData> load();

  /// Atomically replaces the persisted snapshot from the caller's view.
  Future<void> save(PersistedData data);

  /// Removes the persisted snapshot.
  Future<void> clear();
}
