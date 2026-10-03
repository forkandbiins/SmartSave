/// Authentication session state.
enum AuthState {
  /// Authentication state is unknown.
  unknown,
  /// The bank has no PIN.
  pinNotSet,
  /// Not authenticated.
  loggedOut,
  /// Authenticated.
  loggedIn,
  /// Temporarily locked out.
  lockedOut,
}
