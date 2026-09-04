import 'dart:convert';
import 'package:bumame_iap_flutter/bumame_iap_flutter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('decodes Hydra ext roles and permissions for UI visibility', () {
    String part(Object value) =>
        base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
    final token = '${part({'alg': 'RS256'})}.${part({
          'iss': 'https://auth.bumame.com',
          'sub': 'user-1',
          'aud': ['urn:bumame:cis'],
          'ext': {
            'roles': ['cis.doctor'],
            'permissions': ['cis.patient.read'],
            'resource_scopes': {
              'cis.clinics': {
                'mode': 'selected',
                'ids': ['7']
              }
            }
          },
          'picture': 'https://example.com/avatar.jpg'
        })}.signature';
    final principal = IapPrincipal.fromAccessToken(token);
    expect(principal.hasRole('cis.doctor'), isTrue);
    expect(principal.hasPermission('cis.patient.read'), isTrue);
    expect(principal.picture, 'https://example.com/avatar.jpg');
    expect(principal.hasResource('cis.clinics', '7'), isTrue);
    expect(principal.hasResource('cis.clinics', '8'), isFalse);
  });
}
