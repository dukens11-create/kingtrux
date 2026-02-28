/// Canonical entry-point for the KINGTRUX login / account UI.
///
/// The full implementation – map-style background, "Driver account" / "GPS
/// Ready" top badges, signed-in info card, email/password auth form, sign-out
/// button, and branded footer – lives in [KingtruxLoginPage].
///
/// Import this file or [package:kingtrux/ui/kingtrux_login_page.dart]
/// interchangeably to plug the login page into the app's navigation.
///
/// ## Navigation example
/// ```dart
/// Navigator.of(context).push(
///   MaterialPageRoute(builder: (_) => const KingtruxLoginPage()),
/// );
/// ```
///
/// ## Injecting auth logic
/// Provide an [AuthService] implementation above this widget in the tree:
/// ```dart
/// Provider<AuthService>(
///   create: (_) => AuthService(),   // or your custom auth service
///   child: const KingtruxLoginPage(),
/// )
/// ```
export 'kingtrux_login_page.dart';
