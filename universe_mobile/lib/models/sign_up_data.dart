/// Accumulates sign-up state across steps 1-5, which are pure local
/// state — /auth/register needs email AND password together, so there's
/// no backend account to save anything to until step 5 completes and
/// registration actually fires. Passed forward through each screen's
/// constructor since this app has no shared state management library.
class SignUpData {
  String email;
  String fullName;
  String username;
  String password;

  SignUpData({
    this.email = '',
    this.fullName = '',
    this.username = '',
    this.password = '',
  });

  SignUpData copyWith({
    String? email,
    String? fullName,
    String? username,
    String? password,
  }) {
    return SignUpData(
      email: email ?? this.email,
      fullName: fullName ?? this.fullName,
      username: username ?? this.username,
      password: password ?? this.password,
    );
  }
}
