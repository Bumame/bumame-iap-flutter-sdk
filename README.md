# Bumame IAP Flutter SDK

Authentication flow and UI authorization helpers for Bumame Flutter web applications.

## Install from GitHub

```yaml
dependencies:
  bumame_iap_flutter:
    git:
      url: https://github.com/Bumame/bumame-iap-flutter-sdk.git
      ref: v0.1.0-alpha.4
```

The package repository is public; applications should still pin a released tag.

## Minimal web integration

Use `IapWebSignIn`; applications should not implement PKCE, callback state,
browser storage, token refresh, or profile persistence themselves.

```dart
final iap = IapWebSignIn(
  storagePrefix: 'cis_iap',
  config: IapConfig(
    issuer: 'https://auth.bumame.com',
    clientId: 'cis-web',
    audience: 'urn:bumame:cis',
    redirectUri: 'https://cis.bumame.com/login',
  ),
);

if (iap.isCallback) {
  await iap.complete();
}

await iap.start(); // browser redirect to Bumame IAP
final principal = await iap.session.principal();
final accessToken = await iap.session.accessToken();
```

The SDK keeps the OAuth transaction and token set in browser `sessionStorage`,
not `localStorage`. A new browser session redirects through IAP again; IAP's
secure SSO cookie completes that redirect without prompting for credentials
while the IAP session remains valid.

`IapPermissionGate` and `IapRoleGate` control menus/buttons only. They are not
security controls. Every API request must send the access token to a backend
that validates it and enforces permission plus resource ownership.

Use `IapProfileMenu` in an app bar to render the provider avatar (with an
initials fallback), display name, role label, Profile settings action, and
Logout action. Pass the application-friendly role label because the SDK does
not know how `cis.doctor` should be translated for each product.
