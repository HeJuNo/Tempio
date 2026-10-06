# Tempio

Tempio is a native iOS app (Swift / SwiftUI, iOS 26+) for creating on-brand social media posts
from reusable Template Sets and a Brand Kit, then saving them to the Camera Roll or sharing them
via the Share Sheet.

It is built and shipped to **TestFlight entirely in the browser** with GitHub Actions — no Mac
needed — using the same setup as [LoopWorkspace](https://github.com/HeJuNo/LoopWorkspace).

| | |
|---|---|
| App name | Tempio |
| Bundle ID | `com.<TEAMID>.tempio` (TEAMID is injected at build time) |
| Minimum iOS | 26.0 |
| Certificates | stored in the existing private `HeJuNo/Match-Secrets` repo (fastlane match) |

---

## 1. Repository secrets

Set these under **Settings → Secrets and variables → Actions → Secrets**.
They are the same values already used for LoopWorkspace.

| Secret | Description |
|---|---|
| `GH_PAT` | GitHub personal access token with `repo` + `workflow` access (must reach `Match-Secrets`) |
| `TEAMID` | 10-character Apple Developer Team ID |
| `FASTLANE_KEY_ID` | App Store Connect API key ID |
| `FASTLANE_ISSUER_ID` | App Store Connect API issuer ID |
| `FASTLANE_KEY` | Contents of the App Store Connect API key (`.p8` file) |
| `MATCH_PASSWORD` | Password used to encrypt the `Match-Secrets` repo |

## 2. Repository variables (optional)

Set under **Settings → Secrets and variables → Actions → Variables**.

| Variable | Effect |
|---|---|
| `ENABLE_NUKE_CERTS` | `true` = automatically revoke & recreate an expired/missing distribution certificate |
| `FORCE_NUKE_CERTS` | `true` = always revoke & recreate certificates on the next run (set back afterwards!) |
| `SCHEDULED_BUILD` | `false` = disable the monthly scheduled build (enabled by default) |

## 3. First-time setup (run once, in order, from the **Actions** tab)

1. **1. Validate Secrets** — checks all secrets and access to `Match-Secrets`.
2. **2. Add Identifiers** — registers `com.<TEAMID>.tempio` in your Apple Developer account.
3. In [App Store Connect](https://appstoreconnect.apple.com/apps) create a new app:
   platform iOS, name *Tempio*, bundle ID `com.<TEAMID>.tempio`, any SKU.
4. **3. Create Certificates** — creates/updates the App Store provisioning profile in `Match-Secrets`.
5. **4. Build Tempio Manual** — builds, signs and uploads Tempio to TestFlight.

## 4. Workflows

| Workflow | Trigger | Purpose |
|---|---|---|
| `validate_secrets.yml` | manual / called by others | Validate secrets and `Match-Secrets` access |
| `add_identifiers.yml` | manual | Create the app identifier |
| `create_certs.yml` | manual / called by builds | Check, create (and optionally nuke) certificates |
| `build_tempio.yml` | manual | Build & upload to TestFlight |
| `build_tempio_auto.yml` | push to `main` (code changes), manual, weekly schedule (builds on the 2nd Sunday of the month) | Automatic build & upload to TestFlight |

## 5. Project layout

```
Tempio.xcodeproj/        Xcode project (shared scheme "Tempio")
Tempio/                  SwiftUI sources, assets, app icon
fastlane/                Fastfile, Matchfile, Appfile
.github/workflows/       GitHub Actions workflows
Gemfile, Gemfile.lock    Pinned fastlane version
```

Fastlane lanes: `validate_secrets` (`validate`), `identifiers` (`add_identifiers`),
`certs` (`create_certs`), `build_tempio`, `release`, `build_and_upload`, `nuke_certs`,
`check_and_renew_certificates`.

## 6. Building locally (optional, requires a Mac with Xcode 26)

Open `Tempio.xcodeproj`, select your team under *Signing & Capabilities* (this also sets the
bundle ID to `com.<your team ID>.tempio`), and run the **Tempio** scheme.
