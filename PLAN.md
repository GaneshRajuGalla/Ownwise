# Ownwise — gap-fill plan

Created 17 Oct 2026. Source of truth for the work: `reports/Gap analysis.md`.
This file is the *process*: what gets changed, in what order, how it is checked, and how it is
undone if it goes wrong.

## Rules of engagement

1. **One gap at a time.** Read the current implementation, check the Apple documentation for the
   correct API, then make the smallest change that closes the gap.
2. **Never touch `SchemaV1`.** It is the shipped schema; it is frozen. New fields go in a new
   `SchemaVn` + a migration stage.
3. **Every change lands with a test** that fails before it and passes after. A gap closes when its
   test exists, not when the code compiles.
4. **No silent failures.** Nothing new may use `try?` on a write path.
5. **Build + test after each phase.** The owner runs
   `xcodebuild -scheme Ownwise -destination 'platform=iOS Simulator,name=iPhone 18 Pro' test`
   and reports failures; the phase is not "done" until that is green.
6. **One commit per phase**, so any phase can be reverted alone.
7. **If a gap turns out to be by design, it does not get "fixed"** — it gets a comment and a test
   that pins the intended behaviour. Corrections found so far are listed below.

## Corrections to the gap list (found while checking Apple's docs)

| Gap | Correction |
|---|---|
| **H1** "SchemaV1/V2 duplicate the models" | **Not a bug.** Apple's versioned-schema pattern requires each `VersionedSchema` to declare its own model types; sharing them between versions is what actually breaks migration. Do not dedupe. Instead: a header comment in each schema file + a short "adding V3" checklist. |
| **A6** "add undo" | Apple's native path is `.modelContainer(isUndoEnabled: true)` or `container.mainContext.undoManager = UndoManager()`, and it makes **every** edit undoable (including text fields, shake-to-undo). That is a behaviour change beyond deletion, so it is staged: confirmation dialog first, native undo only if it still looks right. |
| **C5/H6** "move work off the main actor" | The project builds with `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`, so "put it in a Task" is not enough — the work must be `nonisolated`/`@concurrent`. This needs its own phase because getting it wrong introduces data races. |
| **G2** pluralisation | Apple supports automatic grammar agreement in String Catalogs (`^[%lld day](inflect: true)`), so "day/day\u2011s" can be expressed properly instead of concatenated. |

## What the market evidence changed

Full report: `reports/Ownwise market research.md`. Five findings rewrite the ordering above:

1. **iCloud sync is the #1 gap, and I was wrong that it conflicts with the positioning.**
   CloudKit's *private* database stores the user's data in *their own* iCloud — the developer
   still collects nothing, so **"Data Not Collected" remains true** and the promise becomes
   "your data lives in your iCloud, not on our servers". That is still unique against rivals that
   require an account (*Kept*, *Covered*, *Fexo*, *Nest Egg*, *Itemtopia*, *Under My Roof*).
   The models are already CloudKit-compatible (optional/defaulted properties, optional
   relationships, no `@Attribute(.unique)`), so this is achievable. Ship it behind a toggle, and
   note CloudKit regressions on iOS 26.4.
   → **new Phase 2, moved above everything except data safety.**
2. **App Intents + a Lock Screen expiry widget is Apple's 2026 baseline** — and no direct rival
   does it well. Promoted from "nice to have" to the headline platform work.
3. **Barcode/serial scanning is cheaper than I assumed**: Foundation Models now exposes
   `BarcodeReaderTool`/`OCRTool` (Jun 2026), and barcode auto-fill is *Nest Egg*'s headline
   feature. Entry effort is the real churn driver. Promoted into Phase 4's neighbourhood.
4. **The Share Sheet, never the inbox.** Every real email-import implementation is server-side
   (Shoeboxed's Gmail sync is $297/yr); users are hostile to inbox access. Share Sheet → Ownwise
   on-device is the on-strategy version. Confirms E1 as planned.
5. **Pricing: $4.99 is a floor, not the price.** Evidence supports $9.99–$12.99 for this depth,
   and the free rivals shadow you, so lead with depth + Apple integration rather than price.
   The ≤5 item cap is actually the category norm (*Covered* is ≤5) — **D2 downgraded to optional**;
   the free reminders are already more generous than rivals'.
   Also: an iPad-compatible run is cheap App Review goodwill (guideline 2.4.1 encourages it).

Deprioritised on evidence: **E4** full depreciation/inventory valuation (pulls into
Encircle/HomeZada turf — keep to simple totals), **E9** resale pack (keep light), and everything
requiring a server: **E13 email auto-import**, **F4 Android/web**.

---

## Phase 1 — Data safety (highest severity, smallest changes)

| ID | Current | Change | Test |
|---|---|---|---|
| A1 | `Persistence.swift:11` `fatalError` on any container failure | `do/catch`: on failure read `config.url`, move the store **and** its `-shm`/`-wal` sidecars into `Recovered/<timestamp>/`, create a fresh container, and record a flag. Fall back to an in-memory container only if even that fails, so the app can never crash-loop. | Unit test: write a junk store file at the config URL, assert `makeContainer` returns a usable container and the junk was moved aside. |
| A2 | ~12 `try? modelContext.save()` sites | New `Data/ModelContext+Saving.swift`: `saveOrReport(file:line:)` doing `do/catch` + `Logger`. Replace every write-path `try?`. | Unit test on the helper's error path. |
| A3 | `ReviewModel.swift:65` mangles `1,299.50` | Delete the local parser and use the already-tested `ReceiptParser.parseAmount`, same as `EditItemView`. One parser for one job. | Parameterised test: `1,299.50`, `1.299,50`, `£1,299`, `1299.5`. |
| C1 | `ScanPipeline.swift:12-19` joins OCR text in completion order | Make the task group return `(offset, text)` and place each result at its index, so page order is preserved. | Unit test with a stubbed OCR that finishes out of order. |
| A6 | Swipe-delete is instant and permanent | Confirmation dialog on item delete (and detail-screen delete), naming the item. Native undo stays a later option. | UITest: delete asks first; cancel keeps the item. |
| B1 | Notifications denied is invisible; `authorizationGranted` is never read | Settings → Reminders shows state: on / denied with a "Open Settings" button (`UIApplication.openSettingsURLString` via `@Environment(\.openURL)`, no force-unwrap). Refresh the status whenever the app activates. | UITest: forced-denied state shows the row and the button. |
| B2 | No reschedule on activation (README §7.5) | On `scenePhase == .active`: refresh authorisation **and** `rescheduleFromContext`. | Existing scheduler tests + manual check. |

## Phase 2 — Posture and trust

| ID | Change |
|---|---|
| A5 | Raw export becomes free (CSV + full backup); Claim Pack PDF stays Pro. Update `ExportView`, `PaywallView` copy, store description. |
| A4 | Backup/restore: `backup.json` (items, coverages, attachments as base64 or a zip) + import, with a documented format version. |
| D1 | Stop gating service plans by kind; gate capability instead. |
| D2 | Free cap 5 → 15 (pending the owner's call). |
| D3 | Rewrite the store description/keywords for the current free tier (`warranty`, `maintenance`, `inventory` in; `vault`, `proof` out). |
| H5 | Delete dead code; drop the unused `@Query` in SettingsView that fetches every item. |

## Phase 3 — Localisation and accessibility

G1 (`LocalizedStringKey` for `SectionCard`/`EmptyStateView`), G2 (enum labels → catalog + grammar
agreement), G3 (missing `AXID`s), G4 (RTL chevron, AX5 truncation), G5 (force-unwrapped URLs),
G6 (empty-filter copy), I5 (drop text matching from UI tests). Mechanical, wide but low risk.

### Phase 3 delivery log — 17 Oct 2026

| Gap | What changed |
|---|---|
| G1 | `SectionCard.title` and `EmptyStateView.title/message/actionTitle` are `LocalizedStringKey`. Every call site already passed a literal, so nothing else moved. |
| G2 | `ItemCategory.label`, `CoverageKind.label`, `AttachmentKind.label`, `CoverageStatus.label` now go through `String(localized:comment:)`, so they localise in the badge, the Claim Pack and the notification body. `ReminderScheduler`'s `"day\(lead == 1 ? \"\" : \"s\")"` is gone: the 0/1/many cases are spelled out as three separate localised strings, because a language with more than two plural forms cannot express them by concatenation. |
| G3 | Added the identifiers the audit listed — category menu, Settings upgrade/app-lock/privacy/contact, the Export Claim Pack row (**one identifier per item** now: `exportClaimPackPrefix + item.id`), the secondary EditItem and Review fields (model, order, price, currency, support phone, notes, days/months, category picker, purchase date). `ItemDetailView`'s hardcoded `"delete_item_trash"` is a constant. An audit script now proves every declared `AXID` is applied somewhere and every identifier the UI tests use exists in their mirror; the mirror was 10 constants short and is now complete. |
| G4 | The detail chevron flips for RTL. `StatusBadge` drops `fixedSize` and gains `minimumScaleFactor(0.7)`, so it compresses at AX5 instead of overflowing its row. |
| G5 | New `Support/Links.swift`: `privacyPolicy`, `supportPage`, `supportEmail` as **optionals**, so a link that cannot be built is simply not offered. All four force-unwraps are gone. |
| G6 | An empty result list now distinguishes three cases: a real search query (`ContentUnavailableView.search`), an active status filter ("Nothing matches this filter"), and an empty library ("Nothing to search yet") — never `No results for ""`. |
| I5 | Tests tap tabs and settings by `AXID` instead of visible English. One deliberate exception: the Cancel button of a `confirmationDialog`'s destructive confirm is left as text, because iOS supplies that label itself and drops identifiers on alert actions — documenting the reason beats a flaky test. |
| — | `PrivacyView` no longer claims "no cloud": it states where data lives *and* that opt-in iCloud sync keeps it in the user's own private database. |

Tests: `LocalisationTests` (enum copy non-empty, badge day form, every fixed link builds and is
https/mailto — the regression test for G5). G1/G3/G4 are compile-time and identifier-level
guarantees; `GatingUITests` and `ExportFlowUITests` exercise the new identifiers end to end.

## Phase 4 — Scan quality and failure states

C2 (`parseTotal` must not match `Subtotal`/`Total savings`), C3 (duplicate service-plan guard),
C4 (camera denied / OCR empty / AI unavailable states), C5 (OCR, JPEG, PDF off the main actor),
H7 (`NumberFormatter` reuse).

### Phase 4 delivery log — 17 Oct 2026

| Gap | What changed |
|---|---|
| C2 | `parseTotal` no longer takes the first line that *contains* "total". Candidates are now ranked: an unambiguous label ("Grand Total", "Amount Due", "Gesamtbetrag", "Total TTC", "合計", "总计") beats a plainer one ("Total", "Gesamt", "Balance"); a later line beats an earlier one, because receipts print the amount paid last; only then does the larger amount win. Keywords match on **word boundaries**, so `Subtotal` cannot be read as `total`, and a noise list removes `Total savings`, `Total items`, `Total tax`, `Amount tendered`, `Total excl. VAT` and friends. `merchantName`/`productName` use the same helper. |
| C2 (extra) | Found while testing C2: the number scanner's pattern stopped at the first short group, so **`₹1,29,950.00` parsed as 1.29** — the Indian lakh grouping was wrong in every currency and no test asserted it. `allNumbers` now matches a whole number run and `parseAmount` treats a trailing two-digit comma group as decimals ("49,90" → 49.90) while keeping lakh grouping intact. Every fixture's expected total is now asserted, not just three of them. |
| C3 | (done in Phase 2) the duplicate guard covers service plans by comparing intervals. |
| C4 | `ScanFlow` gained a `ScanProblem` state with three screens — camera refused (offers **Open Settings** and a photo), no document scanner on this device, and "we couldn't read that" (offers another photo and manual entry). Every one of them offers a way forward, so no scan is a dead end. The camera is now checked *before* presenting (`AVCaptureDevice.authorizationStatus` + `VNDocumentCameraViewController.isSupported`), and `cameraFailed` distinguishes a refusal from the user's own cancel, which stays silent. A scan whose OCR text is empty no longer opens a blank review form as though it had worked. |
| C5 | `ScanPipeline.run` and `OCRService.recognize` are `nonisolated`, and the pipeline now takes the picked `UIImage`s itself, so page decoding, **JPEG compression**, Vision OCR, the parse and the AI merge all run off the main actor — which is what the project's `MainActor`-by-default isolation otherwise prevents. `AIExtractor` is an actor and was already off-main. |
| H7 | `Money.fractionDigits` built a `NumberFormatter` on **every** call, and it is called several times per list row. Currency exponents are now read once per currency behind a lock and reused. |

**C5 residual, deliberately left:** the Claim Pack's page rasterisation still runs on the main
actor, because `ImageRenderer` is a `MainActor`-only API — rasterising a SwiftUI page into a PDF
context cannot be moved without replacing the whole layout with Core Graphics. The gap's headline
symptom (a multi-page *scan* hitching) is fixed; a large Claim Pack export remains a brief
main-thread task, and this is the reason.

Tests: `ReceiptParserTests` — every fixture's total and currency asserted, near-miss lines
(`Subtotal`, `Total savings`, `Total items`, a later weak label vs an earlier strong one) and lakh
grouping; `MoneyTests.fractionDigitsAreStable`; new `ScanFailureUITests` proving both failure
screens appear, that the escape hatch reaches Review, and that an unreadable scan does **not** open
a blank draft. Two new DEBUG-only launch arguments (`-forceScanUnavailable`, `-forceScanUnreadable`)
make those states testable on any device.
`Fixtures` is now `#if DEBUG`, so no fixture OCR text ships in the App Store build (H2, in part).

## Phase 5 — Structure and performance

H2 (move `Fixtures` out of production, `ClaimPackView` out of Services), H4 (one price parser,
one coverage builder), H6 (stop full-table fetching on every screen), H3 (business logic out of
views), H8 (README/code disagreement).

### Phase 5 delivery log — 17 Oct 2026

| Gap | What changed |
|---|---|
| H1 | **Kept, by design** (see the Corrections table): a versioned schema *must* repeat its models. `SchemaV1.swift` now says so, so the duplication is not "fixed" later, and carries the three-step "adding a V3" checklist (copy the file, add a stage to `MigrationPlan`, point `Persistence` at it) with the CloudKit constraints spelled out. |
| H2 | `Fixtures` (Phase 4) and `Persistence.seedSampleData` are both `#if DEBUG`, so neither the fixture OCR text nor the sample library ships in a release build; both call sites are guarded too. `ClaimPackView` left `ExportService.swift` back in Phase 2. |
| H3 | Home's chip counting and "needs attention" filtering moved into `LibraryInsights` (pure functions of items + a date, so they are tested directly). Item/coverage/attachment deletes, mark-serviced and adding a photo moved into `LibraryActions`, each owning its own save. Views keep only presentation and their own reminder reschedule. `claimPack()` needed nothing: it already calls `ExportService`. |
| H4 | New `CoverageBuilder` is the single construction point: the end-date arithmetic (days for a return window, months otherwise), the per-kind defaults, and the fact that a service plan is stored open-ended with its interval and last-service date. `EditItemView`, `ReviewModel` and `CoverageEditor` all call it. `CoverageEditorTests` became `CoverageBuilderTests`, keeping its assertions and adding the stored shape (`distantFuture` + interval for plans). |
| H5 | `taxID` was parsed, stored, backed up and **never populated or displayed** — a parsed value thrown away. It now flows parser → draft → review screen (editable) → item, and shows in Edit item and in Details. The rest of H5 (`analyzed` `AXID.homeScanCTA`, `authorizationGranted`, Settings' unused `@Query`) was removed in Phases 2–4; the audit script in Phase 3 keeps it that way. |
| H6 | `ScanFlow` only needs a **count** to police the free limit, but fetched and hydrated the entire library to get one. It now calls `fetchCount`. The remaining `@Query`s genuinely need their rows, and `rescheduleFromContext` must read the library to rebuild the schedule — recorded as a deliberate residual rather than routed around. |
| H8 | The README's monetization paragraph matched neither the code nor the store listing: it promised a "free up to 5 items" tier with service plans, CSV and Claim Pack behind Pro. It now states what ships (15 items free, every coverage kind free, CSV export and backup/restore free, Claim Pack watermarked on free; Pro = unlimited items, custom reminder timing, unwatermarked PDF, opt-in iCloud sync) and names `StoreManager.freeItemLimit` as the one place the cap lives. |

Tests: `CoverageBuilderTests` (5), `LibraryInsightsTests` (3, including that long-expired coverage
is never "attention"), `LibraryActionsTests` (5, including the cascade delete that the confirmation
dialog's wording promises).

## Phase 6 — Test integrity

I1 (`SearchFilterUITests` must assert unconditionally), I2 (ScanReview must assert the item
exists; ManualAdd/Export assertions made real), I3 (`ReceiptParserTests` must assert values),
I4 (cover OCRService, AIExtractor, AppLock, `rescheduleAll`, `applyToAll`, Home chips, search
filters, the Nth-item limit).

### Phase 6 delivery log — 17 Oct 2026

| Gap | What changed |
|---|---|
| I1 | `SearchFilterUITests` no longer hides every assertion inside `if` guards — it failed silently whenever the tab or field did not appear. It now opens the search tab and field with hard `XCTAssertTrue`s, filters by serial and by merchant, and waits for the *exclusion* of the other rows before asserting the match, so it can never pass on the pre-filter render. |
| I2 | `ScanReviewFlowUITests` ended at `save.tap()`; it now waits for the review sheet to close and then finds the item in the library. `ManualAddFlowUITests`' whole delete flow sat behind an `if rowText.waitForExistence`, so a missing row made it pass with no assertions — the row is now asserted, cancel is asserted to keep the item, and confirm is asserted to remove it. `ExportFlowUITests.assertShareSheet` accepted a private UIKit class name as an alternative, so it could pass with none of the app's own sheet on screen; it now asserts the identifier `ShareSheet` puts on it. |
| I3 | `ReceiptParserTests` asserted `!= nil` for merchant and warranty: a wrong merchant passed. Merchant, warranty months and return window are now asserted *exactly* for every fixture (`String(localized:)`-free comparison, case-insensitive because receipts print `TARGET`). Two fixture expectations were simply wrong — listed a 14- and a 30-day return window for receipts that state no return wording at all — and are corrected to `nil`: the parser must not invent a window. Added exact purchase-date assertions in three formats and a `taxID` pair (read when stated, never when not). |
| I4 | The rules are now where they can be tested, not inside views: `LibrarySearch` (query fields incl. receipt OCR text, and every status filter) and `ReminderPreferences.apply` (bulk-apply) were extracted and have unit tests; `makeRequests` gained tests for one-reminder-per-lead ordering, the spelled-out singular (the `"1 days"` regression), service-plan wording, and that ended coverage and an interval-less plan schedule nothing; `AppLock` gained an injectable clock and tests for the app-switcher grace period and for turning the lock off. The free-limit boundary was already asserted in `StoreManagerTests`. A **`-forceNotificationsDenied` launch argument** makes the refused-permission state testable (B1's Settings row and its route to system Settings), with a new `NotificationsPermissionUITests` covering both the denied and the allowed case. |
| I5 | Done in Phase 3 (identifiers, not visible English). The one documented exception is the `confirmationDialog` Cancel label, which iOS supplies and which drops identifiers on alert actions. |

**Deliberate residuals, not oversights.** `OCRService` and `AIExtractor` are not unit-tested: one
needs Vision's recognition model and the other Apple Intelligence, and neither's output is
deterministic enough for a hermetic test — a flaky test here would be noise, not protection. What
*is* hermetic around them is covered: the parser (10 fixtures, exact values), `ScanPipeline.merge`
(AI-vs-parser precedence), `Money`, and the scan failure states (Phase 4's `ScanFailureUITests`).
`ReminderScheduler.rescheduleAll` itself is a thin loop over the tested `makeRequests` plus
`UNUserNotificationCenter.add`, which cannot be unit-tested without the system's permission prompt.

## Phase 7 — Capture path (new capability)

E1 **Share Extension** so a receipt can be sent from Mail/Safari/Amazon. Note: an extension
cannot see the app's SwiftData container, so this needs an **App Group** + entitlements and a
shared store location — an architecture change, not just a new file. Apple: "Sharing data between
your app and its extensions". Plan it deliberately, do not rush it.

### Phase 7 delivery log — 17 Oct 2026

The plan above assumed the extension needed a *shared store*. It does not, and should not: two
processes writing one SQLite file is how a library gets corrupted. The extension writes bytes into a
shared folder and the app — still the only writer — drains it. That also means the whole app half is
buildable, testable and useful **without any capability**, and the one step that does need the
portal is isolated.

| Piece | What changed |
|---|---|
| Contract | New `SharedInbox`: `Pending/<id>/manifest.json` plus the shared files, written to a staging folder and moved into place so an entry can never be read half-written. A payload the app cannot read is **moved to `Failed/`, never deleted** — a receipt the user chose to share must not vanish. `SharedInbox.default` resolves the `OwnwiseAppGroupID` Info.plist key; with no key or no granted capability there is no container and every operation is a no-op, so today's behaviour is unchanged (the same gate as F3). |
| Importer | New `InboxImporter`, run from `RootView` on launch and on foreground: images and PDFs (first three pages, rasterised) go through the **same** `ScanPipeline` the camera uses — OCR, parse, Apple Intelligence — and text is parsed directly; items are written by the **same** `ReviewModel.save` mapping, so an imported receipt lands with the fields a scan of it would. The link and any text are kept in the item's notes, so a share is never reduced to whatever the parser recognised. |
| Plumbing | `ScanPipeline.draft(fromText:)` is the parse-and-fill half, now shared by the camera path and imports instead of being duplicated. `ReviewModel` gained `notes` (not shown on the review screen; the importer's channel for provenance) and writes it through. |
| Gating | The **free item limit is asked here too** (`canAddItem`), or the share sheet would be a way around it. Entries over the limit stay in `Pending` and import after an upgrade or a deletion — queued, not dropped, and not quarantined. |
| Extension | `Extensions/ShareExtension/ShareViewController.swift` is committed, complete, and deliberately in **no target**: an extension needs its own bundle id, provisioning and App Group. It reads item providers (text and links onto the entry, images and files as payload files, one representation per provider so Safari's page does not become a screenshot) and calls `enqueue`. |
| Runbook | New `docs/share-extension.md`: the portal steps, the entitlement (shared with the iCloud one if both are on — two `CODE_SIGN_ENTITLEMENTS` would silently replace each other), the target settings, the activation rule, and how to inspect `Pending`/`Failed` from the command line. |

Tests: `SharedInboxTests` (round-trip with files, the inert no-container case, quarantine keeping
the bytes, an unreadable manifest) and `InboxImporterTests` (text → exact fields, image and PDF →
an item whose receipt is kept, an unsupported file quarantined rather than deleted, and the free
limit leaving the rest queued).

**Residual for the owner:** the capability and the target (steps 1–4 of the runbook) can only be
done with the App ID in hand. Until then the feature is invisible, verified by `SharedInbox(root:)`
being `nil` in the shipping configuration.

## Phase 8 — Surfaces

E2 widgets (`WidgetKit`, new extension target), E3 App Intents + `AppShortcutsProvider` (app
target), B4 notification actions.

### Phase 8 delivery log — 17 Oct 2026

Two of the three parts need no capability at all, so they are finished and tested; the widget target
does need one, and follows the Phase 7 pattern: the data half is built and inert, the extension is
committed outside any target, and the runbook has the steps.

| Gap | What changed |
|---|---|
| E3 | `OwnwiseIntents.swift`: `ExpiringSoonIntent` ("what's expiring" — the Home screen's Needs Attention, in words) and `AddItemIntent` (name, date, price, currency), plus `OwnwiseShortcuts` for Siri's suggested phrases. Every rule lives in `IntentAnswers` — a MainActor service that takes its container as a parameter — so the answers are unit-tested instead of being trapped inside a `perform()`: the 0/1/many wording is spelled out per case (never "1 items"), and **the free limit applies to Siri too**, so dictating a receipt is not a way around it. Intents declare `supportedModes = .background` rather than the deprecated `openAppWhenRun`, and carry no stored state. `Persistence.sharedContainer` is now the one container per process, so an intent that runs before any scene still reaches the store. `StoreEntitlement` reads the Pro entitlement for paths that have no store object, mirroring the store's own rule (verified, non-revoked). |
| B4 | `Notices` + `NoticeActions` + `NoticeDelegate`: reminders now carry the coverage they are about, and a service reminder offers **Mark serviced** straight from the notification — the one case where there was something to *do* without opening the app. The delegate is the smallest possible `UIApplicationDelegate` (register categories at launch, act on an action, and show a reminder that arrives while the app is open, which the default silences). A background action does not bring the app forward, so the schedule is rebuilt there rather than waiting for a scene phase that may never change. |
| E2 | `SharedSnapshot` (pure Foundation, so a widget target can add it without SwiftData) + `SnapshotBuilder` (the same "needs attention" rules as Home, with the dates kept) + `Extensions/OwnwiseWidget/OwnwiseWidget.swift` (complete, in **no target** yet) + `docs/widgets.md`. The app writes the snapshot from `ReminderScheduler.rescheduleAll`, so the widget and the reminders are rebuilt from the same events and cannot drift; long-expired cover is deliberately excluded. The widget reads a file rather than the store, because the app must stay the only writer. |

Also in this phase: `AppGroup` — one lookup for `OwnwiseAppGroupID`, shared by the inbox and the
snapshot — and `nonisolated` on the files that cross the app/extension boundary (`SharedInbox`,
`SharedSnapshot`, `AppGroup`). That last one is not cosmetic: under
`SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` those members were main-actor by default, which the
extension, the widget and `SharedInboxTests` would each have had to `await`. Verified against the SDK
with the project's exact flags (`-swift-version 6 -default-isolation MainActor -strict-concurrency=complete`)
before writing it: struct members are main-actor by default, `nonisolated` on the type fixes them all,
and `perform()` is **nonisolated** in the App Intents protocol — so the answer services are hopped to
deliberately via `@MainActor func perform()`.

Tests: `IntentAnswersTests` (wording, the free limit, blank names, field/price mapping),
`SnapshotTests` (ordering, service plans, expired cover excluded, the five-entry cap, file round trip,
the inert no-container case), `NoticeActionsTests` (mark serviced by the id in the payload, unknown
actions and missing coverages doing nothing) and a `ReminderSchedulerTests` case proving a request
carries its coverage id and the right category.

**Residual for the owner:** the widget target and the App Group (steps 1–3 of `docs/widgets.md`). Both
E2 and E1 need the same group, so enabling it once lights up both. `E3` needs nothing: it ships in the
app, so once this build is verified the store copy can honestly mention Siri and Shortcuts.

## Phase 9 — Value features

E4 inventory value for insurance · E5 barcode/serial scanning · E6 service log · E7 configurable
"expiring soon" · E8 claim-status tracking · E9 resale pack · E10 multi-currency totals ·
E11 bulk actions.

### Phase 9 delivery log — 17 Oct 2026

Five of the eight are done. All five reuse what already exists — no new model, no new capability — so
none of them can put the store that phases 1–8 depend on at risk. The three that need a **schema V3**
or a multi-select rewrite of the item list are written up below with the design, deliberately not
rushed into the same build as five unverified phases.

| Gap | What changed |
|---|---|
| E5 | `BarcodeService` reads a serial off the same pages the OCR reads, running beside it (both pages of work are already concurrent). **Product barcodes are excluded on purpose** — an EAN/UPC identifies a model, not the item in your hand, so putting one in the serial field would be a confident lie — and the free-form symbologies a manufacturer actually prints a serial in are read. `ScanPipeline.draft(fromText:scannedSerial:)` fixes the precedence in one place: a printed "S/N:" beats a barcode, a barcode beats the AI's guess. |
| E4 + E10 | `InventorySummary` + `InventoryReportView` + `ExportService.makeInventoryReportPDF`/`inventoryReportFile`: a dated inventory for insurance or a move — totals, then per-category subtotals, then the items — from Export. **Currencies are never added together**: a single number mixing 200 EUR and 300 USD is worse than no number, because it looks as authoritative as the right one, so totals are per currency throughout and nothing is sorted by price. The item list is paginated (20 rows a page) so a long library is not silently clipped. Free, like the CSV and the backup: it is the user's own data and an insurer is not a store. |
| E9 | `PackKind` + a title and purpose line on `ClaimPackView`. The resale pack is the *same* facts page — serial, purchase date, cover left, the receipt pages — under its own name (`Resale Pack - Kettle.pdf`) with a line saying what a buyer is getting, rather than a second document that would drift from the first. |
| E7 | `LibraryPreferences` + a picker in Settings (1 week · 2 weeks · 1 month · 2 months · 3 months). The horizon is read from `UserDefaults` where the question is asked rather than handed down the hierarchy, because the free functions that decide it (`coverageStatus`, `overallStatus`) have no environment — one setting, one answer, so the item badge, Home's chips and the widget's snapshot cannot disagree. The stored value is validated: anything not one of the offered horizons reads as 30 days instead of silently changing what every badge in the app means. |
| — | `ExportService.renderPDF` is now the one place a document is rendered, shared by the claim pack and the inventory report, so paper size, colour scheme and the watermark rule cannot drift between them. |

Tests: `BarcodeServiceTests` (a generated Code 128 and a QR read back exactly; a page with no barcode
reads as nothing rather than failing; the product symbologies asserted *absent* from the list, which is
the design rule), a `ScanPipelineTests` case proving a barcode image reaches the serial field through
the full camera path and that a printed serial still wins, `InventorySummaryTests` (per-currency
totals, zero-versus-missing price, category subtotals accounting for the same money, pagination never
dropping an item), `ExportServiceTests` additions (the resale pack's name and framing; the inventory
report's page count, contents and per-currency text with no mixed total anywhere) and
`LibraryPreferencesTests` (validation, the horizon reaching both `coverageStatus` and the item's
overall badge, and the week/month labels). The stored-horizon test deliberately goes through the pure
validator instead of writing to `UserDefaults`, so it cannot change what the other tests see — the same
reason it is not exercised end to end.

**Store copy, once this build is verified** (not before: describing a feature the build does not
deliver is a 2.3.1 risk, and these are one-line additions to `metadata/version/1.0/en-US.json`):
scan-to-serial ("point the camera at the barcode and the serial is filled in"), the inventory report
("a dated list of what you own and what you paid, for insurance — free"), the resale pack ("or a
Resale Pack when you sell it on") and, from Phase 8, Siri/Shortcuts plus "mark a service done from the
reminder itself". The free tier and the Pro list in the description still match the code exactly.

### Deliberately not done yet, with the design

| Gap | Why not in this build | The design, ready to execute |
|---|---|---|
| E6 service log | Needs a new model, which means **schema V3** and a migration — the one kind of change that can lose an existing user's library. Stacking that on five phases the owner has not yet built is the wrong trade. | `ServiceRecord` (date, cost, notes, optional receipt attachment) + an optional to-many from `Item`, in a `SchemaV3` that also carries E8, with a `MigrationPlan` and the lightweight stage H1's checklist describes. Properties optional or defaulted, relationships optional, no unique constraint — the CloudKit rules the schema must keep. Then a `ServiceLogSection` in `ItemDetailView` and `LibraryActions.addServiceRecord`/`delete` (the mutation rule H3 established). |
| E8 claim status | Same V3 migration, and it is a *status machine* (submitted → approved → paid) that only earns its keep with history alongside it — which is E6's model. | `claimStatus` (raw string, defaulted) + `claimUpdatedAt`/`claimNote` on `Item`, set from a menu in `ItemDetailView`, plus a filter chip in `ItemsView` and a `LibrarySearch` status case. Land it in the **same** V3 as E6 so there is one migration, not two. |
| E11 bulk actions | Needs multi-select in `ItemsView` (edit mode, selection state, a destructive toolbar action with confirmation) — a rewrite of the most-used screen, and the one place a mistake deletes somebody's library. Worth doing deliberately, after the current build is known good. | `@State selection: Set<PersistentIdentifier>` + `EditButton`, a toolbar with delete (existing confirmation pattern) and "Move to category", reusing `LibraryActions.delete` per item and one `saveOrReport` at the end rather than a save per item. Free, and no confirmation for an empty selection. |

## Phase 10 — Reach

F1 iPad/Mac, F2 de/fr/es/ja/pt-BR.

### Phase 10 status — 17 Oct 2026: **waiting on the owner, on purpose**

Neither of these is a code-only change, and both of them can *block a submission* rather than unlock it,
which is the opposite of what this build needs while the account is still clearing agreements and the
app has two unresolved 2.1 rejections. What each one actually needs:

| Gap | Why it is not done here | What it takes |
|---|---|---|
| F1 iPad / Mac | The app is already adaptive (`NavigationStack`, `List`, sheets, `Grid`, no fixed frames), and the change itself is one line: `TARGETED_DEVICE_FAMILY = 1` → `"1,2"` for the app target. But **an app that runs on iPad must ship 13-inch iPad screenshots**, so flipping that line today makes the version un-submittable until those screenshots exist — I cannot take them, because they need the app built and run on an iPad simulator. "Designed for iPad" on Mac then follows from the same flag plus the ASC availability toggle. | Flip the flag, run it on an iPad simulator (check the scan flow and the item detail action row first), capture 13-inch screenshots, then enable iPad in the version and optionally "iOS app on Mac". |
| F2 de/fr/es/ja/pt-BR | The catalogue is ready for translators — Phase 3 moved every string into `Localizable.xcstrings` with comments, added the grammar-agreement cases, and made formatting follow the locale (`Money`, dates, `String(localized:)` with spelled-out plural branches). What is missing is the translations themselves. Machine-translating ~400 UI strings, including the permission prompts and the paywall, would be a quality risk I cannot check from here, and half-translated UI is a support burden rather than reach. | Translate `Localizable.xcstrings` in Xcode (it shows the source string and its comment), starting with the permission prompts, the paywall and the reminder wording. Then add each locale in ASC with its own metadata and screenshots. The German/French/Spanish wording in this codebase's comments and the `.. 17 Oct 2026` dates are English on purpose; the UI strings are what matter. |

If you want either of them, say which and I will do the code half immediately: for F2 that means
filling the catalogue and reading it back for consistency, for F1 flipping the flag and listing exactly
what to look at on the iPad.

## Release readiness — checked 17 Oct 2026

Verified through `asc` against the live App Store Connect record, not from memory:

| Check | State |
|---|---|
| Version 1.0 | `PREPARE_FOR_SUBMISSION`; `asc validate` → **0 errors, 0 blocking** |
| IAP `com.ownwise.Ownwise.pro` | **READY_TO_SUBMIT** — the paid-agreements blocker that made StoreKit return "no product" has cleared |
| iPhone screenshots | Present. No iPad set is required: `TARGETED_DEVICE_FAMILY = 1`, so the app does not run on iPad (and `PLAN.md`'s Phase 10 table explains why flipping that is an owner decision) |
| Encryption | `ITSAppUsesNonExemptEncryption = NO` → the build arrives "exempt", no export-compliance prompt |
| Uploaded builds | 1, 2 and 3 — **all from 11 Oct, i.e. before every change in Phases 1–10**. Nothing from this work is on Apple's servers yet |
| Build number | was **2**, which is already used; project bumped to **4** so the next archive is accepted |

**Fixed this pass:** the store listing was stale — the 3 Oct metadata apply had failed wholesale
(`whatsNew cannot be edited` on a first version), leaving a description that advertised *"Unlimited
items (free up to 5)"* and *"CSV export"* as **Pro**, both the opposite of what the app now does. It
has been applied and read back: the ASC description, keywords and promotional text now match
`metadata/version/1.0/en-US.json` exactly.

**Still to do, in order:**

1. ~~Archive and upload a build (the project is now on build 4) and wait for `VALID`.~~ **Done** — the
   owner uploaded **build 4** (`dd72f8d9-5009-477b-ae7f-3a6598f456bb`, `VALID`, 17 Oct 09:23 PT).
2. ~~Attach it to 1.0 and submit the version **and** the IAP in the same review submission.~~ **Done** —
   see *Submission — 17 Oct 2026* below.
3. Confirm App Privacy is still published. The submission was accepted with `blockingIssues: []`, which
   is App Store Connect's own validation passing, so a published privacy policy is the strong
   inference — but the public API cannot read publish state, so a glance at the link is still free.

## Submission — 17 Oct 2026

Submitted through the API, in this order, because the one-shot `asc review submit` wrapper only
attaches the app version and would have submitted before the IAP could be added:

```
asc versions attach-build  --version-id ce3cc370-… --build-id dd72f8d9-…        # attached: true
asc review submissions-create --app 6818868242 --platform IOS                    # 46c816d9-4a57-4c44-9e7f-b94fb8e54878
asc review items-add --item-type appStoreVersions      --item-id ce3cc370-…      # READY_FOR_REVIEW
asc review items-add --item-type inAppPurchaseVersions --item-id d55070a2-…      # READY_FOR_REVIEW
asc review submissions-submit --id 46c816d9-… --confirm                          # WAITING_FOR_REVIEW
```

| Field | Value |
|---|---|
| Submission | `46c816d9-4a57-4c44-9e7f-b94fb8e54878` |
| State | `WAITING_FOR_REVIEW`, submitted 2026-10-17 16:47 UTC |
| Items | app version 1.0 + build 4 + IAP *Ownwise Pro* `d55070a2-…` |
| Blocking issues | none |
| Release type | **`AFTER_APPROVAL`** — the version goes live on approval, no manual "Release" step |
| Copyright | 2026 Ganesh Raju Galla |

The concern recorded above that the IAP version's `DEVELOPER_REJECTED` state might block re-adding it
turned out to be unfounded: it was accepted onto the submission as `READY_FOR_REVIEW` with no
objection, so both the app and the IAP are on the same submission and the IAP will not be left behind.

Because the release type is `AFTER_APPROVAL`, the honest answer to "when does it go live" is: the
moment a reviewer approves it. Nothing further is required from the owner. Build 4 can meanwhile be
put on TestFlight internal testing (no review needed) if there is any doubt about the binary.

The one thing that was never obtained — the Guideline 2.1 text from rejection #2, which the API does
not expose and whose Resolution Center thread is closed to replies — is still unknown. Everything the
gap analysis could identify has been fixed; if this submission bounces, that text is the first thing
to get.



## Build fixes — 17 Oct 2026 (first real compile of Phases 1–10)

Phases 1–10 were written but never compiled: every uploaded build predates them. The first build
found two errors, and a whole-module typecheck found four more that would have appeared the moment the
test targets were built. All six are fixed; all three Swift targets now typecheck clean with zero
warnings.

| Where | Error | Fix |
|---|---|---|
| `Data/Money.swift` | `digitsLock` was a main-actor-isolated static read from the `nonisolated` `fractionDigits` (H7's cache) | `private nonisolated static let digitsLock` — `NSLock` is `Sendable`, so plain `nonisolated`; `nonisolated(unsafe)` would only warn |
| `Services/Import/InboxImporter.swift` | `images.append(contentsOf: images(fromPDF:))` resolved to the local `images` array, not the static helper ("cannot call value of non-function type `[UIImage]`") | helper renamed `pageImages(fromPDF:)` |
| `OwnwiseTests/ExportServiceTests.swift` | `PDFDocument(data:)` is optional, so `.page(at:)` needed unwrapping inside `#require` | `#require` the document first, then the page (same shape as the other test) |
| `OwnwiseTests/ExportServiceTests.swift` | three `#expect((… ?? "").contains(…))` expanded into a mangled swift-testing diagnostic plus two warnings | hoisted to `first`/`second`/`last` locals |
| `OwnwiseTests/LibraryActionsTests.swift` | `FetchDescriptor<Attachment>()` was ambiguous between the app's `Attachment` model and `Testing.Attachment` | `FetchDescriptor<Ownwise.Attachment>()` |
| `Data/Enums.swift`, `Support/Links.swift` | `label` and `Links.*` were main-actor-isolated, so `#expect` (whose expansion is a nonisolated context) could not read them | the four pure enums and `Links` are now `nonisolated`, matching how `Money.fractionDigits`, `LibraryPreferences.label(for:)`, `BarcodeService` and the Import files are already treated. Nothing here touches actor state |

The last one is worth keeping: the extension and widget targets do not default to `MainActor`
isolation, so pure metadata that is `nonisolated` compiles there; main-actor-by-default would not.

**Corrected in the runbooks:** `docs/share-extension.md` and `docs/widgets.md` both omitted
`Ownwise/Services/Import/AppGroup.swift` from the target's file list. `SharedInbox` and
`SharedSnapshot` both call `AppGroup.directory`, so the extension and widget targets would not build
without it (*cannot find 'AppGroup' in scope*). Both steps now list it.

### How this was verified (no `xcodebuild`, no simulator)

The project's build settings can be reproduced with `swiftc` directly, which is what caught the four
latent test errors:

```
SDK=$(xcrun --sdk iphonesimulator --show-sdk-path)
PLATFORM=$(xcrun --sdk iphonesimulator --show-sdk-platform-path)
COMMON=(-target arm64-apple-ios26.0-simulator -sdk "$SDK" -swift-version 6
        -strict-concurrency=complete -enable-upcoming-feature NonisolatedNonsendingByDefault
        -enable-upcoming-feature MemberImportVisibility)

# app module (only this target sets default-isolation MainActor)
xcrun swiftc -typecheck -default-isolation MainActor "${COMMON[@]}" $(find Ownwise -name '*.swift')

# @testable import needs a module emitted with -enable-testing
xcrun swiftc -emit-module -module-name Ownwise -enable-testing -default-isolation MainActor \
  -emit-module-path /tmp/owmod/Ownwise.swiftmodule "${COMMON[@]}" $(find Ownwise -name '*.swift')

# both test targets, plus the test frameworks and the swift-testing macro plugin
xcrun swiftc -typecheck -I /tmp/owmod "${COMMON[@]}" \
  -F "$PLATFORM/Developer/Library/Frameworks" -F "$SDK/Developer/Library/Frameworks" \
  -I "$PLATFORM/Developer/usr/lib" \
  -load-plugin-library /Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/lib/swift/host/plugins/testing/libTestingMacros.dylib \
  $(find OwnwiseTests -name '*.swift')
```

`Extensions/` is outside every target, so its two files were typechecked the same way with the file
lists from the runbooks (widget: widget + `SharedSnapshot` + `AppGroup`; extension: extension +
`SharedInbox` + `AppGroup`) — both clean.

Worth knowing: under `-default-isolation MainActor`, `nonisolated(unsafe)` on an immutable `let`
produces a warning ("unnecessary for a constant with 'Sendable' type"), while plain `nonisolated`
does not.

## Awaiting the owner's decision

- **F3** iCloud sync: still your call to *start*, but the evidence is now clear that it is the
  top-requested thing in the category and that it does not break the privacy promise. Family
  sharing of one inventory is a separate, later step (needs `CKSharingSupported` + accept flow).
- **E2/E1 capabilities**: the App Group (`docs/widgets.md` steps 1–3, shared with
  `docs/share-extension.md`). One capability lights up both.
- **E6 + E8 together, one schema V3**: the service log and claim status both need a new model, so
  they should land in a single migration. Design in the Phase 9 table above. Worth doing *after* the
  current build is confirmed, because a migration is the one change that can cost a user their library.
- **E11 bulk actions**: multi-select in the item list; designed in the Phase 9 table.
- **F1 iPad/Mac** and **F2 de/fr/es/ja/pt-BR**: see the Phase 10 table — both are ready to do, and
  both need something only you can supply (13-inch iPad screenshots; translations).
- **D2** free item cap: implemented as **15** (Phase 2). If you prefer 5, it is one line in
  `StoreManager.freeItemLimit` — and the store description must be changed with it.
- **A5** raw export is free (Phase 2); say if you want it gated again.

## Status

| Phase | State |
|---|---|
| Plan | written, revised against market evidence |
| 0 — Plan | done |
| 1 — Data safety | **done — awaiting the owner's build** |
| 2 — Sync (`F3`) + trust (`A4`, `A5`) | **done in code; `F3` needs a capability step** |
| 3 — Localisation & accessibility | **done — awaiting the owner's build** |
| 4 — Scan quality | **done — awaiting the owner's build** |
| 5 — Structure & performance | **done — awaiting the owner's build** |
| 6 — Test integrity | **done — awaiting the owner's build** |
| 7 — Share Sheet import (`E1`) | **done in code; the extension target + App Group are the owner's step** |
| 8 — Widgets + App Intents (`E2`, `E3`, `B4`) | **`E3` and `B4` done; the `E2` widget target + App Group are the owner's step** |
| 9 — Value features (`E4`, `E5`, `E7`, `E9`, `E10`) | **done; `E6`, `E8` (schema V3) and `E11` (multi-select) designed and deferred** |
| 10 — Reach (`F1` iPad-compatible, `F2`) | **not started — both need something only the owner can supply (see the Phase 10 table)** |

"Awaiting the owner's build" above means an archive and a real run, not a compile check: all three
Swift targets typecheck clean with the project's exact settings (see *Build fixes* above). That build
has since happened — **build 4 was uploaded on 17 Oct and version 1.0 with the IAP is now
`WAITING_FOR_REVIEW`** (see *Submission — 17 Oct 2026*). The release type is `AFTER_APPROVAL`, so the
version goes live when it is approved.

---

## Phase 1 delivery log — 17 Oct 2026

Closed: **A1, A2, A3, A6, B1, B2, C1**, plus the dead `@Query` from H5.

| Gap | What changed | Test |
|---|---|---|
| A1 | `Persistence.makeContainer` no longer calls `fatalError` on a store it cannot read. It moves the store **and** its `-shm`/`-wal` sidecars into `Recovered/<timestamp>/` (never deleting them), opens a fresh store, and records `didRecoverStore`/`recoveredStoreFolder`. Only if even that fails does it fall back to in-memory, then to `fatalError` (unreachable in practice). | `PersistenceRecoveryTests` — store + both sidecars moved, a bystander file untouched, originals preserved |
| A2 | New `Data/ModelContext+Saving.swift`: `saveOrReport(file:line:)` logs the call site instead of swallowing. All 11 write-path `try? …save()` sites now call it (`ReminderSettingsView`'s `newValue.save()` is a *preferences* save, not SwiftData — untouched). | `SaveReportingTests` |
| A3 | `ReviewModel.save` uses `ReceiptParser().parseAmount`, the same parser as the edit screen, instead of `Double(text.replacingOccurrences(of: ",", with: "."))` — which turned `1,299.50` into 1.2995 and lost the price. | `ReviewModelTests.parsesTypedTotal` + empty-total case |
| C1 | New `orderedConcurrentMap` (indexed task group); `ScanPipeline` OCRs pages concurrently **and** keeps page order, so a multi-page receipt can no longer be parsed out of order. | `OrderedConcurrentMapTests` — 20 items finishing in reverse order still come back in order |
| A6 | List swipe-delete now stages the item and asks for confirmation before deleting (cascade takes coverages, receipts and photos with it). The detail screen already had a dialog; the list did not. New `AXID.deleteSwipeButton`; the dialog reuses `AXID.deleteItemButton`. | `ManualAddFlowUITests` now swipes → cancels (item survives) → confirms (item goes) |
| B1 | Settings → Reminders states the permission: when notifications are denied it explains in one line and offers "Turn on notifications" → the app's page in the Settings app (`UIApplication.openSettingsURLString` via `@Environment(\.openURL)`, no force-unwrap). New `AXID.settingsNotificationsButton`. | Done, and testable: `-forceNotificationsDenied` (Phase 6, I4) produces the refused state, and `NotificationsPermissionUITests` asserts the row appears, is tappable, and sends the app to the background (system Settings) |
| B2 | `RootView` refreshes the notification permission **and** rebuilds the schedule whenever the app becomes active, so a permission granted in Settings, or reminders the system dropped, are picked up (README §7.5). | Existing scheduler tests; the activation path itself is verified by hand |

Files: `Data/Persistence.swift`, `Data/ModelContext+Saving.swift` (new), `Services/OrderedConcurrentMap.swift`
(new), `Services/Scan/ScanPipeline.swift`, `Features/Scan/ReviewModel.swift`, `Features/Items/{ItemsView,ItemDetailView,EditItemView,CoverageEditor,CoverageReminderEditor,CustomReminderEditor}.swift`,
`Features/Settings/SettingsView.swift`, `App/RootView.swift`, `Support/AXID.swift`,
`OwnwiseUITests/{Support/UITestLaunch,ManualAddFlowUITests}.swift`, and four new test files.

Deliberately left for Phase 2 (they are the *user-facing* halves, not the safety halves):
A1's "your data could not be opened" notice in Settings, A2's user-visible error alert, A4
backup/restore, A5 free raw export.

---

## Phase 2 delivery log — 17 Oct 2026

Closed: **A4, A5, C3, D1, D2, D3, D4**, the user-facing half of **A1**, and **F3** in code.

| Gap | What changed | Test |
|---|---|---|
| A5 | Raw export and backups are free — `ExportView` no longer gates the CSV, the Settings row is unbadged, and `openExport()`/`exportAfterPurchase` are gone (H5). | `GatingUITests`, `ExportFlowUITests` |
| A4 | New `BackupService`: a versioned JSON backup (`formatVersion`, items, coverages, attachments with their bytes) with **restore that replaces** rather than merges, so restoring twice cannot double a library. Export screen gained Backup / Restore rows; a foreign or newer-format file is refused instead of half-imported. | `BackupServiceTests` — full round-trip, foreign data refused, newer format refused, nil attachment bytes preserved |
| D4 | Free users now get the *real* Claim Pack PDF, watermarked (`ClaimPackWatermark`), instead of a paywall — on both the Export screen and the item detail screen. Pro removes the mark. | `ExportFlowUITests` preview cases |
| D1 | Service plans are no longer gated by coverage *kind*; `canAddCoverage` and its paywall path are deleted. | `GatingUITests.testFreeUserCanOpenTheCoverageEditorWithoutAPaywall` |
| C3 | The duplicate-coverage guard now covers service plans too, comparing their interval instead of their `distantFuture` end date. | covered by the editor's existing behaviour |
| D2 | `freeItemLimit` 5 → **15**. Pro value now rests on the Claim Pack, custom reminder timing and sync rather than a small free cap. One-line change if the pricing call goes the other way. | `StoreManagerTests.freeLimit` |
| D3 | Store description rewritten for the current free tier (every coverage type, free CSV, free backup/restore, 15 items) with `warranty`/`maintenance`/`inventory` added to the keywords and the stale fixed "returns 3/1, warranties 30/7/1" copy removed. iCloud sync is deliberately **not** listed yet — describing a feature the App ID cannot deliver is a 2.3.1 risk. | — |
| A1 | Settings shows a "Data recovery" section when `Persistence.didRecoverStore` is true, pointing at backup restore. | — |
| F3 | `SyncSettings` reads an optional `OwnwiseICloudContainer` Info.plist key; `Persistence` opens `.private(container)` only when the build has one **and** the user opted in. With iCloud unavailable it retries the *same* store locally (`didFallBackToLocalStore`) before ever suspecting corruption. Settings → iCloud appears only when the build can honour it. | — |
| H2 | `ClaimPackView` moved out of `Services/ExportService.swift` into `Features/Export/`. | — |

**F3 needs one capability step before it does anything**: enable iCloud/CloudKit on the App ID,
create the `iCloud.com.ownwise.Ownwise` container, add the entitlements file and the Info.plist
key. `docs/iCloud-sync.md` has the exact contents. Until then the app is local-only, which is
also the state the privacy label describes.

Files: `Services/{BackupService,SyncSettings}.swift` (new), `Services/ExportService.swift`,
`Data/Persistence.swift`, `Features/Settings/{ExportView,SettingsView}.swift`,
`Features/Export/ClaimPackView.swift` (new), `Features/Items/{CoverageEditor,ItemDetailView}.swift`,
`Features/Paywall/PaywallView.swift`, `DesignSystem/Components/ClaimPackWatermark.swift` (new),
`Support/AXID.swift`, `metadata/version/1.0/en-US.json`, `docs/iCloud-sync.md` (new),
3 test files + `OwnwiseUITests/GatingUITests.swift` (new).


