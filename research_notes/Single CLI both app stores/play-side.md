# Google Play release-automation landscape (Play side)

## What does the Google Play Developer Publishing API cover?

### Takeaway
The Publishing API covers the full release mechanic (transactional edits: bundle/APK upload, tracks, staged rollouts, listings/images, testers, country availability) plus immediate-effect monetization, purchase verification, review replies, user/grant management, internal app sharing, app recovery, device-tier configs, external transactions, and — since a recent addition — writing the Data safety (Safety Labels) declaration; it does not cover app creation, first upload, publish/unpublish state flips, legal consents, or store-listing experiments.

### Cited Findings
- The Publishing API automates "uploading new versions of an app", "releasing apps, by assigning APKs to various Tracks (alpha, beta, staged rollout, or production)", and "creating and modifying Google Play Store listings, including localized text and graphics and multi-device screenshots" — [Source](https://developers.google.com/android-publisher)
- Edits are transactional: "you bundle several changes into a single draft edit, then commit the changes all at once. (None of the changes take effect until the edit is committed.)" — [Source](https://developers.google.com/android-publisher)
- Only one edit may be open per user at a time; creating a new edit invalidates any existing open edit, and any Play Console change or committed edit by anyone invalidates all other edits for the app — [Source](https://developers.google.com/android-publisher/edits)
- In-app products and subscription purchase-status methods take effect immediately "whether or not there is an open edit for the app" — [Source](https://developers.google.com/android-publisher/edits)
- Staged rollouts use release `status` values `inProgress` (with `userFraction`), `halted`, `completed`, and `draft`; halted releases can be resumed, completed rollouts finished at 100% via `completed`, and completed releases can be halted (with fallback to the prior completed release) — [Source](https://developers.google.com/android-publisher/tracks)
- Release notes are set per-release via the `releaseNotes` field (`language` + `text`) on the tracks resource — [Source](https://developers.google.com/android-publisher/tracks)
- Form-factor tracks are prefixed (`automotive`, `wear`, `tv`, `android_xr`, `google_play_games_pc`), e.g. `wear:production`; default names are `production`, `beta` (open testing), `qa` (internal testing); closed-testing tracks have custom names — [Source](https://developers.google.com/android-publisher/tracks)
- Monetization resources in the v3 REST index: `monetization` (`convertRegionPrices`), `monetization.onetimeproducts` (+ purchaseOptions/offers), `monetization.subscriptions` (+ basePlans/offers), legacy `inappproducts`, `orders` (get/refund/reviewrefund), `purchases.products`/`productsv2` (acknowledge/consume/get), `purchases.subscriptions`/`subscriptionsv2` (acknowledge/cancel/defer/revoke), `purchases.voidedpurchases` (list) — [Source](https://developers.google.com/android-publisher/api-ref/rest)
- Review replies are API-covered: `reviews` resource has `get`, `list`, `reply` — [Source](https://developers.google.com/android-publisher/api-ref/rest); the Reply to Reviews and Voided Purchases APIs are called out as specialized APIs on the overview page — [Source](https://developers.google.com/android-publisher)
- User/permission management is API-covered: `users` (create/delete/list/patch) and `grants` (create/delete/patch, scoped to package or developer account) — [Source](https://developers.google.com/android-publisher/api-ref/rest)
- Internal app sharing uploads are API-covered: `internalappsharingartifacts.uploadapk` / `uploadbundle` — [Source](https://developers.google.com/android-publisher/api-ref/rest)
- Data safety IS API-covered for writes: `POST /androidpublisher/v3/applications/{packageName}/dataSafety` "Writes the Safety Labels declaration of an app" — [Source](https://developers.google.com/android-publisher/api-ref/rest) (this contradicts the common assumption that the Data safety form is web-only; there is no corresponding GET/read method in the index)
- App recovery (remote revert/halt-style recovery actions) is API-covered: `apprecovery` create/deploy/addTargeting/cancel/list — [Source](https://developers.google.com/android-publisher/api-ref/rest)
- Play App Signing enrollment/rotation is API-covered only for the self-hosted Cloud KMS path: `appsigning.enrollApp` ("using a self-hosted Google Cloud KMS key") and `rotateAppSigningKey` — [Source](https://developers.google.com/android-publisher/api-ref/rest)
- External (out-of-Play) transactions are API-covered: `externaltransactions` create/get/refund — [Source](https://developers.google.com/android-publisher/api-ref/rest)
- Deobfuscation/mapping upload (`edits.deobfuscationfiles.upload`), expansion files, generated-APK download/list, device-tier configs, and system-APK variants are all in the REST index — [Source](https://developers.google.com/android-publisher/api-ref/rest)
- The API explicitly cannot be used to change an app's state from published to unpublished, or to "fill out the legal consents required for publishing" — publishing the app requires the Play Console — [Source](https://developers.google.com/android-publisher/edits)
- gplay's audit reports that "Google's reviewed public Android Publisher discovery document currently has no store-listing experiment lifecycle or results resource", so creating experiments, reading measurements, and choosing winners remain manual Console workflows (only applying a chosen winner's listing text/images via `edits.listings`/`edits.images` is automatable) — [Source](https://raw.githubusercontent.com/tamtom/play-console-cli/main/docs/policy-safe-automation.md)

### Inferences
- The practical API boundary for a unified CLI: everything from second-upload onward (upload → track → rollout → listing → monetization → reviews → refunds) is automatable; app birth, first artifact, legal/policy questionnaires, and publish-state flips are Console handoffs.
- Data safety write-only API means a CLI can submit the declaration but cannot read back current answers for diffing — a design constraint for idempotent sync.

### Gaps
- Could not verify whether the `dataSafety` write endpoint covers the full questionnaire (data types, purposes) or only a subset; the endpoint reference page was not fetched.
- Could not verify whether Play Console "managed publishing" mode has any API flag beyond `changesNotSentForReview` on edits commit (seen in supply params, not in Google docs fetched).
- Quotas/rate limits for the Publishing API were not checked (`/android-publisher/quotas` not fetched).

## How does Play auth work and how does it differ operationally from Apple's API keys?

### Takeaway
Play auth is identity-based: a Google Cloud service account (or OAuth client, or Application Default Credentials) that must additionally be invited as a user inside Play Console's Users & Permissions with granular per-app roles; this is operationally heavier than Apple's self-contained App Store Connect API keys but enables fine-grained least-privilege and user-level OAuth delegation.

### Cited Findings
- Setup requires: create a Google Cloud Project, enable the Google Play Developer API on it, then configure a service account or OAuth client — [Source](https://developers.google.com/android-publisher/getting_started)
- Since 2025-12-18 docs: "You no longer need to link your developer account to a Google Cloud Project in order to access the Google Play Developer API" — [Source](https://developers.google.com/android-publisher/getting_started)
- Service account is the recommended path ("most common", server-to-server); the key must live in a secure environment and never be exposed — [Source](https://developers.google.com/android-publisher/getting_started)
- The service account must be invited under Play Console Users & Permissions ("Invite new users") with the rights needed; for Billing APIs specifically "View financial data, orders, and cancellation survey responses" plus "Manage orders and subscriptions" are required — [Source](https://developers.google.com/android-publisher/getting_started)
- OAuth Client IDs are for per-user access (e.g. a web client acting on behalf of the user, authenticated with their Google account); a user's actions are limited to their Play Console Users & Permissions; creating OAuth clients requires configuring OAuth consent-screen branding first — [Source](https://developers.google.com/android-publisher/getting_started)
- Some APIs require the numeric Play Console Developer ID, found in the URL of almost any Play Console page (e.g. `.../developers/1234567890123456789/api-access`); app transfer between developer accounts changes the Developer ID used in calls — [Source](https://developers.google.com/android-publisher/getting_started)
- fastlane supply supports service-account JSON keys, raw JSON content, Workload Identity Federation (e.g. GitHub Actions OIDC-style), and legacy .p12 (deprecated since 0.4.0); it recommends Admin but notes you can withhold production-release permissions — [Source](https://docs.fastlane.tools/actions/supply/)
- GPP documents the same service-account flow including least-privilege Play Console roles, plus Application Default Credentials with optional service-account impersonation — [Source](https://github.com/Triple-T/gradle-play-publisher)
- gplay reduces setup to `gplay setup --auto` (installs gcloud, creates service account, opens Play Console for the one manual grant step) plus `gplay auth doctor`; supports profiles for multiple accounts — [Source](https://github.com/tamtom/play-console-cli)
- GPC supports four auth methods: service account, OAuth, env var, Application Default Credentials, plus multi-account profiles (`auth profiles/switch/whoami`) — [Source](https://github.com/yasserstudio/gpc)

### Inferences
- Operational difference vs Apple (inference, Apple docs not re-verified here): Apple ASC API keys are bearer JWTs minted in App Store Connect with an embedded role and no second invite step; Play requires two-sided setup (Cloud IAM credential + Console user invite), which makes onboarding slower but allows per-app scoping and revocation via Console user management rather than key rotation.
- The Console-invite requirement is the irreducible manual step every unified CLI must guide users through; `gplay setup --auto` / `gpc setup` both converge on automating everything except that grant.

### Gaps
- Apple-side auth facts were not re-verified in this pass (covered by a parallel iOS-side researcher); the comparison above should be cross-checked against their notes.
- Exact Play Console permission names/granularity for least-privilege release automation (beyond Billing) were not enumerated from primary docs.

## What do gplay, gpc, and appeeky's tool each cover?

### Takeaway
gplay (Go, 252 stars) and GPC (TypeScript, 86 stars) are near-feature-parity broad-coverage CLIs (200+ endpoints, releases, monetization, vitals, reviews, Managed Google Play, offline preflight) differing mainly in runtime (single Go binary vs Node/standalone) and output philosophy (JSON-first vs human tables + JSON); the "appeeky tool" could not be identified or verified — treat any claims about it as unconfirmed.

### Cited Findings
- gplay ("tamtom/play-console-cli"): 252 stars, 26 forks, 343 commits on main; Go single binary; "250+ commands across 9 official Google APIs" including Android Publisher, Play Developer Reporting, Checks, both Play Games admin APIs, Managed Google Play, Play Integrity, Android Developer ID Status, Cloud Storage for reports; claims all 145 current Android Publisher methods have a CLI path — [Source](https://github.com/tamtom/play-console-cli)
- gplay features: service-account setup + `auth doctor`, one-command release with rollout fraction, subscriptions/base-plans/offers + one-time purchases, purchase verification/refunds/RTDN, crash/ANR/vitals, review replies, financial/statistics reports, users & permission grants, Managed Google Play custom apps, Google Checks gate, offline preflight with 9 scanners (manifest, permissions, 64-bit, 16KB page alignment, listing/screenshots, secrets, billing, privacy SDKs, target API, size), Fastlane metadata interop, minified JSON output, `--dry-run` on every write — [Source](https://github.com/tamtom/play-console-cli)
- gplay explicitly draws a safety boundary: `gplay capabilities` classifies workflows as official/manual/unsupported; `gplay bootstrap plan` is non-executing (no auth, no network); no private Console endpoints or browser automation; store-listing experiments are manual except applying a winner — [Source](https://raw.githubusercontent.com/tamtom/play-console-cli/main/docs/policy-safe-automation.md)
- gplay comparison table claims parity with supply and gradle-play-publisher on upload/tracks/rollouts/listings, and advantages on subscriptions/offers, purchase verification, vitals, reviews, reports, users, preflight, Managed Google Play, Checks, JSON output, and runtime (single Go binary vs Ruby+gems vs JVM+Gradle) — [Source](https://github.com/tamtom/play-console-cli) (vendor claim, not independently verified)
- GPC ("yasserstudio/gpc"): 86 stars, 6 forks, 741 commits on main; TypeScript monorepo (`@gpc-cli/*` packages usable as SDK); claims 234 publisher-focused endpoints across four Play APIs; install via npm, Homebrew, or standalone binary — [Source](https://github.com/yasserstudio/gpc)
- GPC features: releases upload/promote/rollout increase/halt, `--validate-only`, listings pull/push with Fastlane format compat, changelog generation incl. Play Store 500-char budget and AI translation (BYO key), `status` dashboard, `watch` rollout monitor with auto-halt on crash-rate breach, vitals CI gates (exit code 6), reviews list/reply, subscriptions/IAP/pricing-convert, Play Games achievements/leaderboards CRUD, Managed Google Play (`enterprise publish`; README claims "first CLI to support"), 9 offline preflight scanners, `doctor` (20+ checks), bundle analyze/compare, semantic exit codes 0–6, `--dry-run` on writes — [Source](https://github.com/yasserstudio/gpc)
- GPC comparison table claims 234 endpoints vs supply ~20 and GPP ~15, plus reviews/vitals, subscriptions, Managed Google Play, games config, preflight, interactive mode — [Source](https://github.com/yasserstudio/gpc) (vendor claim, not independently verified)
- GPC FAQ states it cannot create new apps ("Google Play does not offer an API endpoint to create apps"); lifecycle after creation is CLI-managed — [Source](https://github.com/yasserstudio/gpc)

### Inferences
- gplay and GPC overlap ~90% on paper (endpoints, preflight, Managed Play, Fastlane interop); the real differentiators for a unified CLI to evaluate are runtime preference (Go binary vs Node), output defaults, test depth (GPC claims 2,844 tests/90%+ coverage), and multi-API breadth (gplay's 9 APIs incl. Checks/Integrity vs GPC's 4 + games).
- Both tools' endpoint counts (250+/234/145) are self-reported and mutually inconsistent in scope definition; a unified CLI should verify against the discovery document rather than trust either count.

### Gaps
- The "appeeky tool" could not be identified: web search returned no results in this environment, so no repo, stars, activity, or coverage could be verified. If the coordinator meant a specific repo (e.g. github.com/appeeky/*), a follow-up with the exact URL is needed.
- Recency/activity (last-commit dates, release cadence, maintainer responsiveness) was not captured — repo pages rendered without dates; open-issue counts observed (gplay: 1 issue/4 PRs; GPP: 22 issues) but not verified as current triage states.
- Neither tool's claims (endpoint counts, "first CLI" claims) were independently verified against the API discovery document.

## What is fastlane supply's state and what breaks most for Play uploaders?

### Takeaway
supply remains the incumbent upload path (APK/AAB, tracks, rollouts, listings, changelogs, promotion) but is a narrow uploader by modern standards — no monetization, verification, vitals, reviews, or Managed Play — with its sharpest edges at first-upload bootstrap, edit-conflict/review-hold errors, and Ruby-toolchain friction.

### Cited Findings
- supply "uploads app metadata, screenshots, binaries, and app bundles to Google Play. You can also select tracks for builds and promote builds to production" — [Source](https://docs.fastlane.tools/actions/supply/)
- Feature list: update apps via CLI, upload APKs/AABs, retrieve/edit multi-locale metadata, upload icon/promo/screenshots, keep local metadata copy in git, retrieve version codes from tracks — [Source](https://docs.fastlane.tools/actions/supply/)
- supply requires manual first setup: "Before using supply to connect to Google Play Store, you'll need to set up your app manually first by uploading at least one build" (links fastlane issue #14686) — [Source](https://docs.fastlane.tools/actions/supply/)
- supply exposes managed-publishing/review-hold handling: `changes_not_sent_for_review` param plus `rescue_changes_not_sent_for_review` (default true) which "catches changes_not_sent_for_review errors when an edit is committed and retries with the configuration that the error message recommended" — i.e. commit-time review routing is a known recurring failure — [Source](https://docs.fastlane.tools/actions/supply/)
- `check_superseded_tracks` and `deactivate_on_promote` are deprecated because "Google Play does this automatically now" — evidence of past breakage from API behavior changes being absorbed — [Source](https://docs.fastlane.tools/actions/supply/)
- Release control params: `release_status` (completed/draft/halted/inProgress), `rollout` fraction, `track_promote_to`, `in_app_update_priority` 0–5, `validate_only`, mapping upload, obb references, `ack_bundle_installation_warning` for >150MB bundles — [Source](https://docs.fastlane.tools/actions/supply/)
- Both rival READMEs agree on supply's scope ceiling: gplay's table marks subscriptions/verification/vitals/reviews/reports/users/preflight/Managed Play/Checks all absent from supply — [Source](https://github.com/tamtom/play-console-cli); GPC rates supply at "~20" endpoints with "No" on reviews/vitals, subscriptions, Managed Play — [Source](https://github.com/yasserstudio/gpc)
- Runtime cost is Ruby + gems with 2–3s cold start per GPC's table (vendor claim) vs single-binary alternatives — [Source](https://github.com/yasserstudio/gpc)

### Inferences
- The most common supply breakages (inference from docs design, not issue counts): (1) first-run bootstrap failures (no prior build); (2) `changesNotSentForReview` commit rejections under managed publishing (needed its own auto-rescue flag); (3) edit conflicts when Console and CI race (single-open-edit model); (4) stale-flag breakage as Google absorbs behaviors (the two deprecated flags).
- supply is stable but scope-frozen around the 2018-era edits model; anything beyond upload/listings (subscriptions v2 base plans/offers, vitals, reviews) requires a second tool — the core justification for a unified CLI.

### Gaps
- Open-issue volume and top specific supply bugs were not measured (fastlane issue tracker not fetched); "what breaks most" above is inferred from docs affordances, not issue data.
- supply's maintenance velocity in 2026 (last substantive supply change) was not verified.

## What is the Gradle Play Publisher plugin and who uses it?

### Takeaway
GPP (Triple-T/gradle-play-publisher, 4.3k stars / 349 forks, now in maintenance mode) is the Android-build-native publisher: Gradle tasks that build, upload, promote, and publish listings/IAP/subscriptions from inside the app module — ideal for Android teams who live in Gradle, but it ties releasing to the JVM build and lacks vitals/reviews/verification breadth.

### Cited Findings
- "Gradle Play Publisher (GPP) is Android's unofficial release automation Gradle Plugin. It can do anything from building, uploading, and then promoting your App Bundle or APK to publishing app listings and other metadata." — 4.3k stars, 349 forks, 888 commits — [Source](https://github.com/Triple-T/gradle-play-publisher)
- "Project status: maintenance mode. Issues are ignored, but pull requests are not." — [Source](https://github.com/Triple-T/gradle-play-publisher)
- Requires first upload via Play Console ("registering the app with the Play Store cannot be done using the Play Developer API"), signed release builds, and a service account — [Source](https://github.com/Triple-T/gradle-play-publisher)
- Task model follows AGP naming (`publishPaidReleaseBundle`, `publishBundle` lifecycle tasks); supports App Bundle (default-switchable), APK splits, internal-sharing upload with download-URL JSON output, promoteArtifact with fromTrack/promoteTrack/user-fraction/update-in-place, finishing rollouts via COMPLETED, retaining existing rollouts, version-conflict strategies (IGNORE/AUTO with version-name post-processing) — [Source](https://github.com/Triple-T/gradle-play-publisher)
- Listings support: contact info, per-locale text (title/short/full/video), graphics (icon, feature-graphic, phone/tablet/TV/wear screenshots), release notes per track, release names; `bootstrapListing` pulls existing listing; one-time products and subscriptions publishable (bootstrapped, with `regionsVersion` metadata caveat: "The Google Play Developer API does not have a way to get the latest regions version, so unfortunately bootstrapping uses a hardcoded value") — [Source](https://github.com/Triple-T/gradle-play-publisher)
- Advanced: per-flavor `playConfigs` (incl. separate service accounts per flavor), multi-flavor single-release commit orchestration, CLI option overrides, ADC + impersonation auth, HTTPS proxy truststore support — [Source](https://github.com/Triple-T/gradle-play-publisher)
- Audience signal: GPC's comparison positions GPP as JVM-bound (3–5s cold start, Gradle logs, ~15 endpoints) for teams already building with Gradle — [Source](https://github.com/yasserstudio/gpc)

### Inferences
- Who uses it: Android-first teams wanting release-as-build-task (flavors → tracks mapping, CI via `./gradlew`) rather than a standalone release CLI; maintenance mode means new API surface (e.g. one-time-product offers, recent Publisher additions) will lag unless community PRs land.
- For a unified iOS+Android CLI, GPP is the pattern to interoperate with (metadata dir layout, track/release-notes conventions), not the runtime to build on.

### Gaps
- Adoption numbers (Gradle Plugin Portal downloads, "Used by" counts) were not captured.
- Exact monetization gap vs current API (base plans/offers support in GPP — gplay's table says "basic, no base plans/offers") was not verified in GPP source, only via gplay's claim — [Source](https://github.com/tamtom/play-console-cli)

## Which Play Console flows have NO API (Console-web-only)?

### Takeaway
App creation/first upload, publish/unpublish flips, legal consents and policy/app-content declarations, store-listing experiments, and ordinary Play App Signing enrollment are Console-only; Data safety is the notable exception that recently gained a write API.

### Cited Findings
- New-app registration and first artifact are Console-only: "You can only use this API to make changes to an existing app (that has at least one APK uploaded); thus, you will have to upload at least one APK through the Play Console" — [Source](https://developers.google.com/android-publisher/edits); echoed by GPP ("The first APK or App Bundle needs to be uploaded via the Google Play Console") — [Source](https://github.com/Triple-T/gradle-play-publisher), supply (manual first build, issue #14686) — [Source](https://docs.fastlane.tools/actions/supply/), and GPC ("You create the app once in the Play Console UI") — [Source](https://github.com/yasserstudio/gpc)
- Publish-state flips and legal consents are Console-only: API "cannot... change an app's state from 'published' to 'unpublished', or... fill out the legal consents required for publishing" — [Source](https://developers.google.com/android-publisher/edits)
- gplay's stated manual handoffs: "Initial public-app setup, first upload, ordinary Google-managed Play App Signing enrollment, and legal declarations still require a manual Play Console handoff" (only enterprise self-hosted Cloud KMS signing has an API path) — [Source](https://github.com/tamtom/play-console-cli); the KMS-only scope matches `appsigning.enrollApp`'s "self-hosted Google Cloud KMS key" description — [Source](https://developers.google.com/android-publisher/api-ref/rest)
- Store-listing experiments: no lifecycle/results resource in the public discovery document; create/measure/choose-winner are manual — [Source](https://raw.githubusercontent.com/tamtom/play-console-cli/main/docs/policy-safe-automation.md)
- The v3 REST index contains no app-content/policy-questionnaire resource (no `appcontent` family; closest are `applications.dataSafety` write-only and subscription tax/compliance types) — [Source](https://developers.google.com/android-publisher/api-ref/rest) (absence-of-evidence, index enumerated in full above)
- Managed publishing has no dedicated API resource in the index; the only related affordance found is the commit-time `changesNotSentForReview`/`rescue` behavior in supply — [Source](https://docs.fastlane.tools/actions/supply/)
- Draft releases straddle the boundary: creatable via API (`status: draft`) but designed to be "inspected and rolled out via the Google Play Console" — [Source](https://developers.google.com/android-publisher/tracks)
- Console-timed human gates both tools acknowledge: managed-publishing review sends, policy declarations, pricing/tax setup beyond `convertRegionPrices` — gplay classifies these via `gplay capabilities` as manual/unsupported rather than automating them — [Source](https://raw.githubusercontent.com/tamtom/play-console-cli/main/docs/policy-safe-automation.md)

### Inferences
- The Console-only list for unified-CLI scoping: (1) account/app creation + first upload; (2) Play App Signing Google-managed enrollment; (3) publish/unpublish + managed-publishing send-for-review clicks; (4) legal agreements + policy/app-content declarations (target audience, content ratings questionnaire, advertising ID, etc.); (5) store-listing experiments; (6) pricing/tax/regional setup beyond price conversion. Items 4–6 rest partly on index-absence evidence and should be spot-checked in Console docs before final scoping.
- Data safety write API (`applications.dataSafety`) is the2014 model exception: declarations that look like questionnaires can gain APIs, so the Console-only list should be re-audited against the discovery document at build time (as gplay does with its checked-in schema audit).

### Gaps
- Target-audience/content-rating/ads-declaration endpoints: asserted absent from the REST index but the full Play Console policy-center surface was not cross-checked page by page.
- Whether price/tax setup (beyond `convertRegionPrices` and base-plan price migration) has API coverage was not fully verified.
- The appeeky tool (if it automates any Console-only flow via unofficial means) could not be assessed — see gap above.
