# Bumame IAP Flutter SDK

Authentication flow and UI authorization helpers for Bumame Flutter web applications.

## Install from private GitHub

```yaml
dependencies:
  bumame_iap_flutter:
    git:
      url: https://github.com/Bumame/bumame-iap-flutter-sdk.git
      ref: v0.1.0-alpha.1
```

The developer and CI identity must have repository read access. Keep the repository private.

Use `IapAuthClient.createAuthorizationRequest()`, redirect the browser to the returned URI, then call `exchangeCode()` on the callback page. The SDK validates OAuth `state` and uses PKCE S256.

`IapPermissionGate` and `IapRoleGate` control menus/buttons only. They are not security controls. Every API request must send the access token to a backend that validates it and enforces permission plus resource ownership.

The default `MemoryTokenStore` deliberately avoids `localStorage`. For persistent web login, use a Next/Go BFF with secure HttpOnly cookies.
