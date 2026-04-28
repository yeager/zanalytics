# ZAnalytics

ZAnalytics is a native macOS SwiftUI app for building and exporting analytics reports through configurable Zscaler OneAPI endpoint templates.

This is an unofficial helper. It is not affiliated with, endorsed by, or sponsored by Zscaler. Use Zscaler Automation Hub as the primary documentation source: https://automate.zscaler.com

## Features

- Canned reports for executive security, web usage, SaaS/Shadow IT, threat overview, firewall/network activity, ZPA access activity, and ZDX experience.
- Customizable report fields, dimensions, filters, date range, sort, and row limit.
- Editable REST and GraphQL endpoint templates because OneAPI analytics paths, fields, tenant features, RBAC, and rollout timing can vary.
- GraphQL templates include endpoint path, query text, and variables JSON. The app posts `{ "query": "...", "variables": { ... } }` and merges built-in report variables with tenant-specific overrides.
- Settings buttons to authenticate, fetch an OAuth token, decode visible JWT metadata such as scopes/expiry, and test the selected report endpoint separately.
- Mock sample data mode so the app can be explored without credentials.
- JSON, CSV, printable HTML, PDF, and PowerPoint (`.pptx`) exports. HTML/PDF/PPTX support Executive Summary, Technical Detail, and Customer Success Review presentation templates.
- Offline HTML charts: KPI cards, CSS bar charts, inline SVG trend charts, severity/category sections, full table, methodology, footer, and an unofficial disclaimer. No external JavaScript, CDN, or network dependency is required for exported reports.
- Keychain storage for OneAPI client ID, client secret/API secret, base URL, vanity domain, cloud name, tenant ID, audience, and token path.

## OneAPI Notes

Public docs and product behavior may vary by tenant. Current assumptions used by this app are based on Zscaler Automation Hub (`https://automate.zscaler.com`):

- OneAPI access is created in ZIdentity.
- Automation Hub describes creating API roles/clients in ZIdentity, authenticating with client secrets or signed JWTs, then calling Zscaler APIs with the resulting token.
- OAuth2 client credentials are supported with client secrets/API secrets.
- Signed JWT authentication is represented in the client abstraction, but local signing setup is intentionally not implemented yet.
- ZAnalytics supports configurable REST requests and configurable GraphQL POST requests (`query` + `variables`) so tenants can adapt to the API shape they have available.
- Analytics categories may include Web traffic, cybersecurity, SaaS security, Zero Trust Firewall, IoT, Shadow IT, ZPA, and ZDX, depending on licensing and RBAC.
- Request IDs, RBAC, retry/rate-limit handling, and cache/repeated-query behavior should be expected.

Before using live mode, confirm the base URL, token path, analytics endpoint paths, GraphQL endpoint/query shape, allowed fields, filters, and dimensions against Automation Hub, your tenant documentation, or your admin portal. The default endpoint paths and queries are placeholders.

## Report Templates and Charts

Each canned report includes friendly presentation guidance and a default HTML template:

- Executive Summary: outcome-focused KPI cards, compact narrative, charts, and concise evidence.
- Technical Detail: operational grouping, severity/category sections, full table, and methodology for validation.
- Customer Success Review: adoption/value framing, trend view, follow-up sections, and customer-ready visuals.

The presentation template can be selected from the report output toolbar. JSON and CSV exports emit raw response JSON or tabular rows; HTML/PDF/PPTX generate formatted report artifacts.

Charts are generated from returned numeric fields using local CSS and SVG only. The renderer prefers common analytics fields such as `detections`, `requests`, `sessions`, `blocked`, `users`, `experience_score`, and `risk_score`, then falls back to the first numeric field it can detect.

## Automation Hub Workflow

Use Zscaler Automation Hub as the source of truth for current OneAPI behavior:

1. Create or verify the API role/client in ZIdentity.
2. Confirm OAuth audience, token path, base URL, tenant/cloud details, and supported auth method.
3. Confirm whether each analytics use case is exposed through REST, GraphQL, or product-specific APIs for your tenant.
4. Copy endpoint paths, GraphQL queries, variable names, fields, filters, dimensions, and RBAC requirements into Settings > Endpoints.
5. Use Authenticate first to isolate credential/token issues, then Test Connection to probe the selected report endpoint with a small limit.

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
- Treat endpoint templates and GraphQL variables as configuration, not secrets. Do not place bearer tokens, client secrets, or customer-sensitive data in template notes or variables JSON.
- Exported JSON, CSV, HTML, PDF, and PPTX may contain tenant data. Store and share generated reports according to your organization policy.

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
