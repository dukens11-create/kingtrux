import '../config.dart';

/// Determines whether a signed-in user has admin privileges.
///
/// **Authorization rule**: a user is an admin when their (verified) email
/// address appears in the [Config.adminEmails] allowlist, which is populated
/// at build time via:
///
/// ```
/// flutter run --dart-define=ADMIN_EMAILS=admin@example.com,ops@example.com
/// ```
///
/// Pass a custom [adminEmails] set to the constructor for testing.
class AdminService {
  final Set<String> _adminEmails;

  AdminService({Set<String>? adminEmails})
      : _adminEmails = adminEmails ?? Config.adminEmails;

  /// Returns `true` when [email] (case-insensitive) is in the admin allowlist.
  ///
  /// Returns `false` when [email] is `null` or empty.
  /// The input is trimmed and lower-cased before lookup because [_adminEmails]
  /// already stores normalised values.
  bool isAdmin(String? email) {
    if (email == null || email.isEmpty) return false;
    return _adminEmails.contains(email.trim().toLowerCase());
  }
}
