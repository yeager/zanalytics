# ZAnalytics

ZAnalytics is a native macOS SwiftUI app for building, previewing, and exporting Zscaler OneAPI analytics reports.

It is designed for teams that need repeatable security, web, SaaS, ZPA, ZDX, and firewall reporting without hand-building the same exports every time. The app ships with mock data so you can explore the workflow immediately, then switch to live OneAPI credentials when your tenant endpoints and RBAC are ready.

> [!IMPORTANT]
> ZAnalytics is an unofficial helper. It is not affiliated with, endorsed by, or sponsored by Zscaler. Use Zscaler Automation Hub as the source of truth for current OneAPI behavior: <https://automate.zscaler.com>

## Download

Download the latest macOS DMG from the GitHub Releases page:

- <https://github.com/yeager/zanalytics/releases/latest>

The distributed app/DMG is currently unsigned and not notarized. macOS may require you to approve it manually in Privacy & Security, or you can build it locally from source.

## What it does

- Builds analytics reports from configurable Zscaler OneAPI endpoint templates.
- Supports REST and GraphQL-style endpoint definitions.
- Stores OneAPI connection settings securely in macOS Keychain.
- Lets you test authentication separately from report endpoint/RBAC issues.
- Provides mock sample data for demos, UI testing, and report design without credentials.
- Exports report output as JSON, CSV, HTML, PDF, and PowerPoint (`.pptx`).

## Current report catalog

ZAnalytics includes canned report definitions for:

- Executive Security Summary
- Web Usage Overview
- SaaS / Shadow IT Review
- Threat Overview
- Firewall / Network Activity
- ZPA Access Activity
- ZDX Experience Summary

Each report includes default fields, dimensions, filters, endpoint template hints, and a preferred presentation style.

## Export formats

| Format | Purpose |
| --- | --- |
| JSON | Raw response JSON for debugging, archival, or custom processing. |
| CSV | Tabular rows for spreadsheet workflows. |
| HTML | Offline formatted report with KPI cards, charts, full table, methodology, and disclaimer. |
| PDF | Formatted report artifact for sharing and review. |
| PPTX | PowerPoint deck with title, key metrics, and row preview slides. |

HTML, PDF, and PPTX exports use the selected presentation template:

- **Executive Summary** — outcome-focused KPI cards, concise narrative, and leadership-friendly evidence.
- **Technical Detail** — operational grouping, severity/category sections, full evidence table, and methodology.
- **Customer Success Review** — adoption/value framing, trends, and customer-ready discussion points.

All generated report files may contain tenant data. Store and share them according to your organization’s policy.

## OneAPI configuration

OneAPI behavior can vary by tenant, product, cloud, licensing, RBAC, and rollout timing. ZAnalytics intentionally keeps endpoint definitions editable instead of pretending there is one universal analytics API shape.

Settings include:

- Client ID
- Client secret / API secret
- Base URL
- Token path
- Vanity domain
- Cloud name
- Tenant ID
- OAuth audience (defaults to `https://api.zscaler.com`, matching the Zscaler SDK)
- Authentication method
- REST/GraphQL endpoint templates
- GraphQL query and variables JSON

The app can:

1. Request an OAuth token.
2. Decode visible JWT metadata such as expiry, scopes, subject, issuer, and audience when present.
3. Run a tiny endpoint probe to separate credential/token failures from endpoint or RBAC failures.

ZAnalytics never displays or logs the raw token value.

## Suggested Automation Hub workflow

1. Create or verify the API role/client in ZIdentity.
2. Confirm the tenant vanity domain and cloud.
3. Confirm OAuth audience (`https://api.zscaler.com` for the standard OneAPI client-secret flow), token path, and supported authentication method.
4. Confirm whether the analytics use case is exposed through REST, GraphQL, or product-specific APIs for your tenant.
5. Copy endpoint paths, GraphQL queries, variables, fields, filters, dimensions, and RBAC requirements into **Settings > Endpoints**.
6. Use **Authenticate** first.
7. Use **Test Connection** with a small row limit.
8. Run the full report and export the result.

## Security model

- Credentials are stored in macOS Keychain.
- Non-sensitive preferences and endpoint templates are stored in UserDefaults.
- No API keys, bearer tokens, client secrets, or tenant secrets are hardcoded in the app.
- Use least-privilege RBAC for the ZIdentity API client.
- Treat endpoint template notes and GraphQL variables as configuration, not as a secret store.
- Review generated exports before sharing; they may contain customer or tenant-sensitive data.

## Build from source

Requirements:

- macOS 14 or newer target
- Xcode 26.2 or newer

Build:

```sh
xcodebuild -project ZAnalytics.xcodeproj -scheme ZAnalytics -destination 'platform=macOS' build
```

Run tests:

```sh
xcodebuild -project ZAnalytics.xcodeproj -scheme ZAnalytics -destination 'platform=macOS' test
```

Create an unsigned release app and DMG:

```sh
scripts/build_dmg.sh
```

Output:

- `build/Release/ZAnalytics.app`
- `build/ZAnalytics.dmg`

## Development status

ZAnalytics is early-stage and intentionally conservative:

- Endpoint templates are placeholders until you confirm your tenant’s actual OneAPI paths and schema.
- Signed JWT authentication is represented in the client abstraction, but local signing configuration is not implemented yet.
- The PDF/PPTX renderers are built-in lightweight exporters, not full design tools.
- Signing/notarization is not yet automated.

## Screenshots

Screenshots are planned. Useful captures to add:

- Onboarding / setup wizard
- Report builder
- Report output preview
- HTML/PDF/PPTX exports

## License

MIT. See [`LICENSE`](LICENSE).
