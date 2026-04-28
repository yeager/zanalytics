# ZAnalytics

ZAnalytics is a native macOS SwiftUI app for building and exporting analytics reports through configurable Zscaler OneAPI endpoint templates.

This is an unofficial helper. It is not affiliated with, endorsed by, or sponsored by Zscaler. Use Zscaler Automation Hub as the primary documentation source: https://automate.zscaler.com

## Features

- Canned reports for executive security, web usage, SaaS/Shadow IT, threat overview, firewall/network activity, ZPA access activity, and ZDX experience.
- Customizable report fields, dimensions, filters, date range, sort, and row limit.
- Editable endpoint templates because OneAPI analytics paths, fields, tenant features, RBAC, and rollout timing can vary.
- Mock sample data mode so the app can be explored without credentials.
- JSON, CSV, and printable HTML exports with summary cards and simple bars.
- Keychain storage for OneAPI client ID, client secret/API secret, base URL, vanity domain, cloud name, tenant ID, audience, and token path.

## OneAPI Notes

Public docs and product behavior may vary by tenant. Current assumptions used by this app are based on Zscaler Automation Hub (`https://automate.zscaler.com`):

- OneAPI access is created in ZIdentity.
- Automation Hub describes creating API roles/clients in ZIdentity, authenticating with client secrets or signed JWTs, then calling Zscaler APIs with the resulting token.
- OAuth2 client credentials are supported with client secrets/API secrets.
- Signed JWT authentication is represented in the client abstraction, but local signing setup is intentionally not implemented yet.
- Analytics categories may include Web traffic, cybersecurity, SaaS security, Zero Trust Firewall, IoT, Shadow IT, ZPA, and ZDX, depending on licensing and RBAC.
- Request IDs, RBAC, retry/rate-limit handling, and cache/repeated-query behavior should be expected.

Before using live mode, confirm the base URL, token path, analytics endpoint paths, allowed fields, filters, and dimensions against Automation Hub, your tenant documentation, or your admin portal. The default endpoint paths are placeholders.

## Setup

1. Open `ZAnalytics.xcodeproj` in Xcode 26.2 or newer.
2. Build and run the `ZAnalytics` scheme.
3. Start in mock mode, then open Settings when you have OneAPI credentials.
4. Save OneAPI settings. Sensitive settings are stored in macOS Keychain.
5. Review Settings > Endpoints and adjust endpoint templates for your tenant.

## Security

- Do not commit credentials.
- Keychain stores connection settings and secrets.
- UserDefaults stores only non-sensitive app preferences and endpoint templates.
- The app does not ship hardcoded secrets.
- Use least-privilege RBAC for any ZIdentity API client.

## Build and Test

```sh
xcodebuild -project ZAnalytics.xcodeproj -scheme ZAnalytics -destination 'platform=macOS' build
xcodebuild -project ZAnalytics.xcodeproj -scheme ZAnalytics -destination 'platform=macOS' test
```

## Create Unsigned App and DMG

```sh
scripts/build_dmg.sh
```

The script creates:

- `build/Release/ZAnalytics.app`
- `build/ZAnalytics.dmg`

The DMG is unsigned and not notarized. Main/release automation should handle signing, notarization, and publishing if needed.

## Screenshots

Add release screenshots here:

- `docs/screenshots/onboarding.png`
- `docs/screenshots/report-builder.png`
- `docs/screenshots/html-export.png`

## License

MIT. See `LICENSE`.
