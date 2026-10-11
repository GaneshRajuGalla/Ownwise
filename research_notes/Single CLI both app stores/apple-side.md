# Apple App Store Release-Automation Landscape

Research current as of October 4, 2026. All facts verified from cited sources; inferences and gaps marked as such.

## What is asc's full command taxonomy (major command groups and what each does)?

### Takeaway
`asc` (rorkai/App-Store-Connect-CLI, 7.6k stars, Go, MIT) covers the full Apple release surface in ~60 top-level command families, with canonical high-level paths (`publish appstore`, `validate`, `release stage`) composed over granular API commands, plus local Xcode, signing, and experimental web-session families.

### Cited Findings
- Repo is Go, MIT-licensed, 7.6k stars / 637 forks, tagline "Fast, scriptable CLI for the App Store Connect API. Automate TestFlight, builds, submissions, signing, analytics, screenshots, subscriptions, and more" — [repo](https://github.com/rorkai/App-Store-Connect-CLI)
- Getting-started families: `auth`, `doctor`, `install-skills`, `init`, `docs` — [COMMANDS.md](https://github.com/rorkai/App-Store-Connect-CLI/blob/main/docs/COMMANDS.md)
- Web-session family: `web` (Apple web-session workflows) — [COMMANDS.md](https://github.com/rorkai/App-Store-Connect-CLI/blob/main/docs/COMMANDS.md)
- Analytics/finance families: `analytics`, `ads` (Apple Ads Campaign Management API), `insights`, `finance`, `performance` — [COMMANDS.md](https://github.com/rorkai/App-Store-Connect-CLI/blob/main/docs/COMMANDS.md)
- App-management families: `apps`, `app-setup`, `app-tags`, `versions`, `localizations`, `metadata`, `screenshots`, `video-previews`, `background-assets`, `product-pages`, `routing-coverage`, `pricing`, `pre-orders`, `categories`, `age-rating`, `accessibility`, `encryption`, `eula`, `agreements`, `app-clips`, `android-ios-mapping`, `marketplace`, `alternative-distribution`, `nominations`, `game-center` — [COMMANDS.md](https://github.com/rorkai/App-Store-Connect-CLI/blob/main/docs/COMMANDS.md)
- TestFlight/build families: `testflight`, `builds`, `build-bundles`, `build-localizations`, `xcode` (local archive/export helpers, macOS only), `sandbox` — [COMMANDS.md](https://github.com/rorkai/App-Store-Connect-CLI/blob/main/docs/COMMANDS.md)
- Review/release families: `release`, `status` (pipeline dashboard), `release-notes`, `review`, `reviews` (customer reviews), `submit`, `validate` (canonical readiness report), `publish` (high-level TestFlight/App Store publish) — [COMMANDS.md](https://github.com/rorkai/App-Store-Connect-CLI/blob/main/docs/COMMANDS.md)
- Monetization families: `iap`, `storekit` (StoreKit server APIs, separate IAP key), `app-events`, `subscriptions` — [COMMANDS.md](https://github.com/rorkai/App-Store-Connect-CLI/blob/main/docs/COMMANDS.md)
- Signing families: `signing`, `bundle-ids`, `certificates`, `profiles`, `merchant-ids`, `pass-type-ids`, `notarization` — [COMMANDS.md](https://github.com/rorkai/App-Store-Connect-CLI/blob/main/docs/COMMANDS.md)
- Account/access families: `account`, `users`, `actors`, `devices`; automation families: `workflow`, `webhooks`, `xcode-cloud`, `notify`, `migrate` (fastlane-format metadata migration) — [COMMANDS.md](https://github.com/rorkai/App-Store-Connect-CLI/blob/main/docs/COMMANDS.md)
- Utility/discovery families: `diff`, `capabilities` (CLI/API/web-only/public-API-limited coverage catalog), `search` (agent-oriented command discovery), `snitch`, `version`, `completion`, `schema`, `telemetry`, `api` (raw requests), `system-status` — [COMMANDS.md](https://github.com/rorkai/App-Store-Connect-CLI/blob/main/docs/COMMANDS.md)
- Canonical App Store path is `asc publish appstore --app … --ipa … --version … --submit --confirm`, with `asc release stage --dry-run` preview, `asc validate` readiness, `asc submit status/cancel`, `asc status --watch` monitoring — [README](https://github.com/rorkai/App-Store-Connect-CLI)
- `asc review submit` is the canonical shortcut for attaching a build and sending a prepared version through the modern review-submission flow — [changelog](https://github.com/rorkai/App-Store-Connect-CLI/blob/604b72e4/resources/changelog.mdx)
- Local Xcode→TestFlight verified flow uses `asc xcode build/inject/archive/export/test`, `asc builds next-build-number`, `.asc/deployment.json`, `.asc/workflow.json`, ExportOptions.plist — [README](https://github.com/rorkai/App-Store-Connect-CLI) and [WORKFLOWS reference](https://github.com/rorkai/App-Store-Connect-CLI/blob/main/docs/COMMANDS.md)
- Intentional non-goals (will not build without demand): Android tooling (Play/Gradle/supply), plugin/lane runtime (Fastfile plugins), chat connectors beyond Slack webhook, doc generators, retired actions; note `asc android-ios-mapping` is Apple's Android-to-iOS mapping API, not Android CI — [PARITY.md](https://raw.githubusercontent.com/rorkai/App-Store-Connect-CLI/main/docs/PARITY.md)
- Single-binary distribution: Homebrew (`brew install asc`), install script, WinGet (`Rorkai.ASC`), signed release binaries; no Go toolchain needed for released binaries — [README](https://github.com/rorkai/App-Store-Connect-CLI)

### Inferences
- The taxonomy maps 1:1 onto App Store Connect API resource domains plus release-orchestration verbs, which makes it a good reference model for what a unified CLI must cover on the Apple side.

### Gaps
- Full per-command flag inventory not captured; README designates `asc --help` as the authoritative surface and `asc capabilities` as the live inventory, which I did not execute (no binary installed in this environment).

## How does asc authenticate (API key roles, keychain vs config, CI pattern)? What can API keys NOT do that needs web sessions?

### Takeaway
`asc` authenticates with App Store Connect JWT API keys (team keys need key ID + issuer ID + .p8; individual keys need key ID + .p8 with `--key-type individual`), stored in system keychain by default with config-file and env-var fallbacks for CI; API keys cannot do web-only flows (App Privacy publish, app creation, review-center actions), which require the separate `asc web auth login` Apple-ID session.

### Cited Findings
- Team API keys require Admin account to generate; roles mirror user roles (Admin/App Manager/Developer/etc.), team keys span all apps, individual keys inherit the associated user's access — [Apple: Creating API Keys](https://developer.apple.com/documentation/appstoreconnectapi/creating-api-keys-for-app-store-connect-api)
- Individual keys cannot use Provisioning endpoints, Sales and Finance, or `notaryTool`; each user has one active individual key; individual-key generation requires the Generate Individual API Keys permission — [Apple: Creating API Keys](https://developer.apple.com/documentation/appstoreconnectapi/creating-api-keys-for-app-store-connect-api)
- Role scoping in practice: Admin required for certificates/profiles/Bundle IDs over API; App Manager can upload, manage builds/testers, edit metadata, submit; Developer can upload builds and manage internal testers but not metadata/submission — [Appcircle credential docs summarizing Apple behavior](https://docs.appcircle.io/account/my-organization/security/credentials/adding-an-app-store-connect-api-key)
- `asc auth login --name --key-id --issuer-id --private-key [--network]`; individual keys omit `--issuer-id` and pass `--key-type individual`; keys generated at appstoreconnect.apple.com/access/integrations/api — [README](https://github.com/rorkai/App-Store-Connect-CLI)
- Default storage is system keychain (macOS Keychain, Windows Credential Manager, Linux Secret Service); `--bypass-keychain` writes `~/.asc/config.json` (0600) or `./.asc/config.json` with `--local`; env-var auth via `ASC_KEY_ID`/`ASC_ISSUER_ID`/`ASC_PRIVATE_KEY_PATH|ASC_PRIVATE_KEY|ASC_PRIVATE_KEY_B64`/`ASC_KEY_TYPE`; no single universal precedence — a resolution matrix governs profile/env/keychain/config selection — [authentication.mdx](https://raw.githubusercontent.com/rorkai/App-Store-Connect-CLI/main/authentication.mdx)
- CI pattern: unset `ASC_PROFILE`/`ASC_BYPASS_KEYCHAIN`/`ASC_CONFIG_PATH`, export complete env credential set (prefers `ASC_PRIVATE_KEY_B64` from secret store); officially supported on GitHub Actions (setup-asc action), GitLab components, Bitrise step, CircleCI orb — [authentication.mdx](https://raw.githubusercontent.com/rorkai/App-Store-Connect-CLI/main/authentication.mdx); [CI_CD.md](https://github.com/rorkai/App-Store-Connect-CLI/blob/main/docs/CI_CD.md)
- Fresh-runner code-signing sequence is fully scripted: `signing fetch --create-missing --create-missing-certificate` → `signing sync push/pull` (Git, S3-compatible object storage w/ OIDC workload identity, or experimental GitLab Secure Files / AWS Secrets Manager) → `signing keychain install` → `profiles local install` → `xcode signing plan/apply` → `xcode archive/export` → `signing keychain delete` — [CI_CD.md](https://github.com/rorkai/App-Store-Connect-CLI/blob/main/docs/CI_CD.md)
- Validation/diagnostics: `asc auth status --validate`, `asc auth doctor` (with `--fix --confirm` for migrations/permissions/source conflicts) — [README](https://github.com/rorkai/App-Store-Connect-CLI)
- API keys cannot verify or perform App Privacy publication: "the public App Store Connect API cannot verify whether App Privacy is fully published" — [skills submission-health doc](https://skillshub.wtf/rudrankriyam/app-store-connect-cli-skills/asc-submission-health)
- Web-session-only capabilities with no public API are tracked as open issues #2275–#2301 series (2026-09-02), live inventory via `asc capabilities --status web-session` — [PARITY.md](https://raw.githubusercontent.com/rorkai/App-Store-Connect-CLI/main/docs/PARITY.md)
- Rate limits bound automation: per-key rolling-hour limits reported in `X-Rate-Limit` header (`user-hour-lim`/`user-hour-rem`), 429 + `RATE_LIMIT_EXCEEDED` on excess; asc retries only GET/HEAD on 429/503, honors Retry-After, logs raw header with `--api-debug` — [Apple: Identifying Rate Limits](https://developer.apple.com/documentation/appstoreconnectapi/identifying-rate-limits); [asc API_NOTES](https://github.com/rudrankriyam/App-Store-Connect-CLI/blob/main/docs/API_NOTES.md)
- Support contract: Discussions for how-to/auth/CI questions, Issues for reproducible bugs; bug reports should include `asc version`, OS/shell, install method, exact command, redacted output, `ASC_BYPASS_KEYCHAIN=1` retest, redacted `--api-debug` — [SUPPORT.md](https://raw.githubusercontent.com/rorkai/App-Store-Connect-CLI/main/SUPPORT.md)

### Inferences
- Any unified CLI must model two credential planes on the Apple side: unattended-safe API-key auth for ~95% of flows, and an interactive Apple-ID web session reserved for the web-only remainder.

### Gaps
- Exact per-endpoint rate-limit numbers beyond the documented rolling-hour header mechanism were not verified against primary Apple docs (only example values like 3500–3600/hr appear); one secondary source claims 7,200/hr per app but is not Apple-official.

## What is the `asc web` bridge pattern (which flows use authenticated browser/web-session endpoints, e.g. privacy publish)? Why does this matter?

### Takeaway
`asc web` is an explicitly experimental bridge that logs into Apple as the user (SRP + 2FA, cached cookies) and drives private App Store Connect web (`/iris`) endpoints for flows with no public API — App Privacy pull/plan/apply/publish, app creation, review-center, and deep validation — at the cost of fragility, expiry churn, and account-risk disclaimers.

### Cited Findings
- `asc web` "automates workflows that rely on Apple's private App Store Connect web endpoints instead of the public App Store Connect API. Use this surface only when no supported API flow exists"; "experimental, unofficial, and discouraged… not sanctioned for third-party automation, can break without notice, and may put your account at risk" — [web command docs](https://docs.asccli.sh/commands/web)
- Auth is a cached Apple-Account web session via `asc web auth login --apple-id`, SRP handshake against `idmsa.apple.com` (salt/iteration challenge, PBKDF2-derived password, hashcash puzzle), 2FA via trusted device/SMS or `ASC_WEB_2FA_CODE_COMMAND` script; sessions cached file-backed (`~/.asc/web/`, default) or keychain via `ASC_WEB_SESSION_CACHE_BACKEND`, exportable/importable for CI (`web auth export/import`), non-interactive login via `ASC_WEB_PASSWORD` + 2FA command — [authentication.mdx](https://raw.githubusercontent.com/rorkai/App-Store-Connect-CLI/main/authentication.mdx); [DeepWiki web-session auth](https://deepwiki.com/rorkai/App-Store-Connect-CLI/3.3-web-session-authentication)
- Privacy flow: `web privacy catalog|pull|plan|apply|publish` over web-session `/iris` endpoints; recommended `pull → plan → apply --confirm → publish --confirm` — [web command docs](https://docs.asccli.sh/commands/web)
- Deep validation: `asc validate --deep` reuses the file-backed web cache without new login prompts to check App Privacy publication, relevant agreements, and first auto-renewable subscription attachment; unavailable/changed private endpoints report `unverified`, not blockers, unless `--strict` — [README](https://github.com/rorkai/App-Store-Connect-CLI)
- Other web families: `web apps` (creation, availability, medical-device declarations), `web xcode-cloud`, `web review` (Resolution Center, submission management), `web auth` (login/status/capabilities/logout) — [DeepWiki web commands](https://deepwiki.com/rorkai/App-Store-Connect-CLI/10-web-commands-(unofficial-api))
- Client protections: 1s minimum request interval (`ASC_WEB_MIN_REQUEST_INTERVAL`) to avoid account locking; cached-session-first resolution to reduce fresh logins — [DeepWiki web-session auth](https://deepwiki.com/rorkai/App-Store-Connect-CLI/3.3-web-session-authentication)
- Usage guidance: expect auth churn/expired sessions, prefer one-off human-driven use over unattended automation, expect contract drift, never treat output as stable API — [web command docs](https://docs.asccli.sh/commands/web)

### Inferences
- This matters for unified-CLI design because full release automation (privacy publish, app creation, review-center replies) cannot be achieved on public API alone; the design must either adopt an equivalent session bridge (with its fragility/support-cost implications) or scope those flows out and hand off to the web UI.

### Gaps
- The complete enumerated list of web-only endpoints beyond privacy/app-create/review/Xcode-Cloud was not verified; `asc capabilities --status web-session` is the live source but was not executed here.

## What is fastlane's current maintenance state (open issues/PRs, Ruby dependency burden, which Apple lanes still work)?

### Takeaway
Fastlane is alive but strained: under new volunteer maintenance since late 2025 (releases through 2.233.x in 2026), with ~665 open issues/PRs combined, a lingering Ruby 3.4 support gap, and core Apple lanes (deliver/pilot/match/gym) still functional but brittle around Xcode upgrades and Apple-side changes.

### Cited Findings
- 42,201 stars, 6,037 forks, language Ruby, not archived; `open_issues_count` 665 (GitHub API counts issues + PRs together), last push 2026-10-03 — [GitHub API: fastlane/fastlane](https://api.github.com/repos/fastlane/fastlane)
- "Is this project dead?" (#29713, opened Oct 2025): complaints of unmerged PRs, daily new issues, hard-coded screenshot sizes, Ruby 3.4 unusable without workarounds (released ~a year prior), PR #29184 pending ~a year; funding history (Google sponsorship ended; Josh Holtz full-time 2018–2020; Mobile Native Foundation move proposed 2023, no announced outcome) — [fastlane #29713](https://github.com/fastlane/fastlane/issues/29713)
- Revival: volunteer (iBotPeaches) fixed CI pipelines, cut v2.229.0, joined maintainers; issue closed Nov 2025 with "fastlane is no longer dead… bringing it back to active work" — [fastlane #29713](https://github.com/fastlane/fastlane/issues/29713)
- Post-revival releases observed in the wild: 2.229.x, 2.230, 2.231.x, 2.232.2, 2.233.0/2.233.1 (Apr 2026) — [fastlane #29969 (version table)](https://github.com/fastlane/fastlane/issues/29969); [fastlane #29983](https://github.com/fastlane/fastlane/issues/29983)
- Ruby burden: Ruby 3.4 support missing for ~a year (#29183, PR #29184); psych/erb gem version conflicts breaking `bundle update fastlane` on Ruby 3.3; `setup_ci` keychain side-effects; username/password (spaceship session-cookie) auth increasingly fragile vs API keys — [fastlane #29713](https://github.com/fastlane/fastlane/issues/29713); [fastlane #29969](https://github.com/fastlane/fastlane/issues/29969); [fastlane #29893](https://github.com/fastlane/fastlane/issues/29893); [fastlane #29919](https://github.com/fastlane/fastlane/issues/29919)
- Apple lanes still working but brittle: `deliver` uploads succeed but break on adjacent changes (2.233.0 `sync_app_previews` nil-crash on TestFlight-only flows, fixed in 2.233.1); Xcode 26.x runner transitions triggering agreement/upload failures often traced to Apple-side incidents; `match`/`gym`/`pilot` flows continue to be exercised in current reports — [fastlane #29983](https://github.com/fastlane/fastlane/issues/29983); [fastlane #29971](https://github.com/fastlane/fastlane/issues/29971); [fastlane #29860](https://github.com/fastlane/fastlane/issues/29860)
- A maintainer explicitly recommends moving to App Store Connect API keys: "I don't see much of a future with username/password authentication as Apple tightens the grip" — [fastlane #29919 comment](https://github.com/fastlane/fastlane/issues/29919)

### Inferences
- For unified-CLI design, fastlane is evidence both that Ruby/Fastfile plugin percebeived flexibility has high maintenance cost, and that API-key-first auth plus pinned, hermetic binaries (asc's Go model) avoid fastlane's two biggest failure modes (Ruby env drift, session-cookie auth).

### Gaps
- Separate open-issue vs open-PR counts not isolated (API returns the combined 665); no per-lane reliability statistics found — evidence is issue-report-based, not telemetry.

## What does Xcode Cloud cover and where does it stop (external CI, cross-store)?

### Takeaway
Xcode Cloud covers Apple-only build/test/distribute inside Apple's managed infrastructure with TestFlight integration, but stops at the ecosystem border: no Android/backend/Linux, only three `ci_scripts` customization points, Apple-dictated toolchains, and no self-hosted runners or Vault-style secrets.

### Cited Findings
- Xcode Cloud is "a continuous integration and delivery service built into Xcode… build apps, run automated tests in parallel, deliver apps to testers, and view and manage user feedback"; workflows configurable in Xcode or App Store Connect; ephemeral Apple-silicon build environments destroyed after builds; source via GitHub/Bitbucket/GitLab clone — [Apple: Xcode Cloud Overview](https://developer.apple.com/xcode-cloud/); [Apple Tech Talk](https://developer.apple.com/videos/play/tech-talks/111369/)
- Apple-ecosystem only (iOS/iPadOS/macOS/watchOS/tvOS/visionOS); "No backend, no Android, no Docker, no Linux. Xcode Cloud will not become your company's CI — only your iOS team's CI" — [Dodecaidr 2026 guide](https://dodecaidr.pro/en/articles/xcode-cloud-2026-guide/)
- Customization is three scripts (`ci_post_clone.sh`, `ci_pre_xcodebuild.sh`, `ci_post_xcodebuild.sh`); no arbitrary step graph; SPM resolves out of the box, CocoaPods/Carthage need custom scripts; no `sudo` — [Dodecaidr 2026 guide](https://dodecaidr.pro/en/articles/xcode-cloud-2026-guide/); [Apple dependency docs](https://sosumi.ai/documentation/xcode/making-dependencies-available-to-xcode-cloud)
- Apple dictates macOS/Xcode versions (e.g. Xcode 26.2 export-archive bug with workaround "build on 26.1"); pre-release capacity queues; usage-based pricing — [Dodecaidr 2026 guide](https://dodecaidr.pro/en/articles/xcode-cloud-2026-guide/)
- No self-hosted runners ever; secrets are env vars in App Store Connect UI with no Vault integration — "if your security team requires 'builds never leave the perimeter', the conversation ends at this bullet" — [Dodecaidr 2026 guide](https://dodecaidr.pro/en/articles/xcode-cloud-2026-guide/)
- Has an API + webhooks for integration with external pipelines, enabling a hybrid pattern where the shared pipeline triggers Xcode Cloud as one specialized iOS worker — [Apple WWDC22 deep dive](https://developer.apple.com/videos/play/wwdc2022/110375/); [Dodecaidr 2026 guide](https://dodecaidr.pro/en/articles/xcode-cloud-2026-guide/)
- asc itself wraps Xcode Cloud triggering/monitoring (`xcode-cloud run`, `build-runs get`) for external-CI orchestration — [README](https://github.com/rorkai/App-Store-Connect-CLI)

### Inferences
- A unified single CLI fits the hybrid pattern: keep the shared pipeline external (GitHub Actions etc.) and drive both Xcode Cloud (Apple builds) and Play-side CI from one interface, rather than attempting to replace Xcode Cloud.

### Gaps
- Current Xcode Cloud pricing/hour allotments not verified from Apple primary sources in this pass.

## What agent-facing surfaces exist (asc install-skills, MCP, AXe/Koubou screenshot deps)?

### Takeaway
asc ships a first-party agent-skills pack (25 skills via `asc install-skills`, pinned to a reviewed commit) plus self-documenting CLI surfaces (`--help`, `capabilities`, `search`, `docs`, `schema`), while MCP access comes from third-party servers and screenshot fidelity depends on pinned external tools Koubou (framing) and AXe CLI (simulator automation).

### Cited Findings
- Agent Skills repo (rorkai/app-store-connect-cli-skills) covering builds, TestFlight, metadata sync, submissions, signing; installed via `asc install-skills`, which pins reviewed commit `f52c4f04…` and copies 25 skills into the global agent-skills dir with verification, lock-pinning, and rollback; requires only `git` — [README](https://github.com/rorkai/App-Store-Connect-CLI)
- 25 named skills include asc-cli-usage, asc-workflow, asc-release-flow, asc-testflight-orchestration, asc-build-lifecycle, asc-signing-setup, asc-metadata-sync, asc-localize-metadata, asc-aso-audit, asc-analytics-reports, asc-submission-health, asc-xcode-build, asc-screenshot-resize, asc-shots-pipeline, asc-app-create-ui, asc-apple-ads, asc-subscription-localization, asc-revenuecat-catalog-sync, asc-notarization, asc-crash-triage, asc-ppp-pricing, asc-whats-new-writer, asc-ad-hoc-distribution, asc-id-resolver, asc-wall-submit — [skills repo](https://github.com/rorkai/app-store-connect-cli-skills)
- Agent-oriented CLI discovery: `asc search` (command/example search), `asc capabilities` (coverage catalog incl. web-only rows), `asc docs show workflows|reference`, `asc init` (repo-local reference template), `asc schema` (runtime API endpoint schemas), TTY-aware output defaulting to JSON in pipes/CI with `--output table|json|markdown` — [COMMANDS.md](https://github.com/rorkai/App-Store-Connect-CLI/blob/main/docs/COMMANDS.md); [README](https://github.com/rorkai/App-Store-Connect-CLI)
- MCP servers are third-party, not shipped by asc: Swift-based `asc-mcp` forks expose 200–502 tools across ~33 domains (counts vary by fork: 502, 399, 293, 208/203); Go `asc-mcp` variant speaks MCP 2025-06-18 with stdio + Streamable HTTP; npm `mcp-asc` uses official API with JWT auth — [zelentsov-dev/asc-mcp](https://github.com/zelentsov-dev/asc-mcp); [antisynthesis/asc-mcp](https://github.com/antisynthesis/asc-mcp); [mcp-asc npm](https://www.npmjs.com/package/mcp-asc)
- Screenshot dependencies are pinned externals: Koubou 0.20.0 for deterministic device-frame rendering ([koubou](https://github.com/bitomule/koubou)); AXe CLI for simulator UI automation ([AXe](https://github.com/cameroncooke/AXe)); keyword-difficulty methodology adapted from semihcihan's App-Store-Optimization-CLI (MIT) — [README acknowledgements](https://github.com/rorkai/App-Store-Connect-CLI)
- Screenshot capture contract: targets must be already-booted simulators; `screenshots matrix` (plan JSONC, isolated output, offline review) and `screenshots run/capture` require booted simulator + installed app; simulator create/boot/clone/delete explicitly out of scope (host `simctl`) — [README](https://github.com/rorkai/App-Store-Connect-CLI); [PARITY.md](https://raw.githubusercontent.com/rorkai/App-Store-Connect-CLI/main/docs/PARITY.md)
- Telemetry relevant to agents: pseudonymous command-level telemetry by default (version, OS/arch, command path, duration, outcome class, HTTP status on failure; never args/creds/IDs/paths), controllable via `asc telemetry status|disable|reset-id`, `ASC_TELEMETRY_DISABLED=1`, `DO_NOT_TRACK=1` — [README](https://github.com/rorkai/App-Store-Connect-CLI)

### Inferences
- A unified CLI should copy the skills-pack distribution pattern (pinned, verifiable, rollback-safe `install-skills`) and the `--help`/`capabilities`/`search` self-documentation contract, since those are what make asc agent-operable without MCP.

### Gaps
- Whether any MCP server is officially endorsed by the asc maintainers was not confirmed; all MCP servers found are third-party. AXe/Koubou invocation details (bundled vs external install) not verified beyond the acknowledgement lines.
