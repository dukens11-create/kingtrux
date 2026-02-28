import 'package:flutter_test/flutter_test.dart';
import 'package:kingtrux/services/admin_service.dart';

void main() {
  group('AdminService.isAdmin', () {
    late AdminService adminService;

    setUp(() {
      adminService = AdminService(
        adminEmails: {'admin@example.com', 'ops@kingtrux.com'},
      );
    });

    test('returns true for an email in the allowlist', () {
      expect(adminService.isAdmin('admin@example.com'), isTrue);
    });

    test('is case-insensitive', () {
      expect(adminService.isAdmin('Admin@Example.COM'), isTrue);
      expect(adminService.isAdmin('OPS@KINGTRUX.COM'), isTrue);
    });

    test('trims whitespace before checking', () {
      expect(adminService.isAdmin('  admin@example.com  '), isTrue);
    });

    test('returns false for an email not in the allowlist', () {
      expect(adminService.isAdmin('user@example.com'), isFalse);
    });

    test('returns false for null email', () {
      expect(adminService.isAdmin(null), isFalse);
    });

    test('returns false for empty email', () {
      expect(adminService.isAdmin(''), isFalse);
    });

    test('returns false when allowlist is empty', () {
      final noAdmins = AdminService(adminEmails: const {});
      expect(noAdmins.isAdmin('admin@example.com'), isFalse);
    });

    test('can be constructed with default Config allowlist', () {
      // Verifies the no-arg constructor compiles and does not throw.
      expect(() => AdminService(), returnsNormally);
    });
  });
}
