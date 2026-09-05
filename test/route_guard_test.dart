import 'package:bumame_iap_flutter/bumame_iap_flutter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const guard = IapPermissionRouteGuard([
    IapPermissionRouteRule.prefix('/records', {'records.read'}),
    IapPermissionRouteRule.prefix('/records/edit', {'records.manage'}),
    IapPermissionRouteRule.exact('/reports', {
      'reports.read',
      'reports.manage',
    }),
    IapPermissionRouteRule.prefix(
      '/checkout',
      {'patient.read', 'product.read'},
      requireAll: true,
    ),
  ]);

  test('allows routes without a rule', () {
    expect(guard.canAccess('/home', const []), isTrue);
  });

  test('accepts any listed permission by default', () {
    expect(guard.canAccess('/records/42', {'records.read'}), isTrue);
    expect(guard.canAccess('/reports', {'reports.manage'}), isTrue);
  });

  test('uses the most-specific matching rule', () {
    expect(guard.canAccess('/records/edit/42', {'records.read'}), isFalse);
    expect(guard.canAccess('/records/edit/42', {'records.manage'}), isTrue);
  });

  test('supports screens that require every listed permission', () {
    expect(guard.canAccess('/checkout/new', {'patient.read'}), isFalse);
    expect(
      guard.canAccess('/checkout/new', {'patient.read', 'product.read'}),
      isTrue,
    );
  });

  test('does not apply exact rules to child paths', () {
    expect(guard.canAccess('/reports/monthly', const []), isTrue);
  });
}
