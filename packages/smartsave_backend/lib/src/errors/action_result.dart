import 'smartsave_error.dart';

/// The result of an operation exposed to the UI.
sealed class ActionResult<T> {
  /// Creates an action result.
  const ActionResult();

  /// Whether this result represents success.
  bool get isSuccess => this is ActionSuccess<T>;

  /// The value on success, or null on failure.
  T? get valueOrNull => switch (this) {
        ActionSuccess<T>(:final value) => value,
        ActionFailure<T>() => null,
      };

  /// The error on failure, or null on success.
  SmartSaveError? get errorOrNull => switch (this) {
        ActionSuccess<T>() => null,
        ActionFailure<T>(:final error) => error,
      };

  /// Handles either branch of this result.
  R when<R>({
    required R Function(T value) success,
    required R Function(SmartSaveError error) failure,
  }) =>
      switch (this) {
        ActionSuccess<T>(:final value) => success(value),
        ActionFailure<T>(:final error) => failure(error),
      };
}

/// A successful action result containing [value].
final class ActionSuccess<T> extends ActionResult<T> {
  /// Creates a successful result.
  const ActionSuccess(this.value);
  /// The returned value.
  final T value;
}

/// A failed action result containing [error].
final class ActionFailure<T> extends ActionResult<T> {
  /// Creates a failed result.
  const ActionFailure(this.error);
  /// The typed failure.
  final SmartSaveError error;
}
