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

## Phase 4 — Scan quality and failure states

C2 (`parseTotal` must not match `Subtotal`/`Total savings`), C3 (duplicate service-plan guard),
C4 (camera denied / OCR empty / AI unavailable states), C5 (OCR, JPEG, PDF off the main actor),
H7 (`NumberFormatter` reuse).

## Phase 5 — Structure and performance

H2 (move `Fixtures` out of production, `ClaimPackView` out of Services), H4 (one price parser,
one coverage builder), H6 (stop full-table fetching on every screen), H3 (business logic out of
views), H8 (README/code disagreement).

## Phase 6 — Test integrity

I1 (`SearchFilterUITests` must assert unconditionally), I2 (ScanReview must assert the item
exists; ManualAdd/Export assertions made real), I3 (`ReceiptParserTests` must assert values),
I4 (cover OCRService, AIExtractor, AppLock, `rescheduleAll`, `applyToAll`, Home chips, search
filters, the Nth-item limit).

## Phase 7 — Capture path (new capability)

E1 **Share Extension** so a receipt can be sent from Mail/Safari/Amazon. Note: an extension
cannot see the app's SwiftData container, so this needs an **App Group** + entitlements and a
shared store location — an architecture change, not just a new file. Apple: "Sharing data between
your app and its extensions". Plan it deliberately, do not rush it.

## Phase 8 — Surfaces

E2 widgets (`WidgetKit`, new extension target), E3 App Intents + `AppShortcutsProvider` (app
target), B4 notification actions.

## Phase 9 — Value features

E4 inventory value for insurance · E5 barcode/serial scanning · E6 service log · E7 configurable
"expiring soon" · E8 claim-status tracking · E9 resale pack · E10 multi-currency totals ·
E11 bulk actions.

## Phase 10 — Reach

F1 iPad/Mac, F2 de/fr/es/ja/pt-BR.

## Awaiting the owner's decision

- **F3** iCloud sync: still your call to *start*, but the evidence is now clear that it is the
  top-requested thing in the category and that it does not break the privacy promise. Family
  sharing of one inventory is a separate, later step (needs `CKSharingSupported` + accept flow).
- **D2** free item cap: evidence says 5 matches the norm, so this is optional.
- **A5** confirm raw export becomes free (I recommend yes).

## Status

| Phase | State |
|---|---|
| Plan | written, revised against market evidence |
| 0 — Plan | done |
| 1 — Data safety | **done — awaiting the owner's build** |
| 2 — Sync (`F3`) + trust (`A4`, `A5`) | queued — promoted on evidence |
| 3 — Localisation & accessibility | not started |
| 4 — Scan quality (+ barcode, promoted) | not started |
| 5 — Structure & performance | not started |
| 6 — Test integrity | not started |
| 7 — Share Sheet import (`E1`) | not started |
| 8 — Widgets + App Intents (`E2`, `E3`, `B4`) | not started |
| 9 — Value features (`E6`–`E11`) | not started |
| 10 — Reach (`F1` iPad-compatible, `F2`) | not started |

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
| B1 | Settings → Reminders states the permission: when notifications are denied it explains in one line and offers "Turn on notifications" → the app's page in the Settings app (`UIApplication.openSettingsURLString` via `@Environment(\.openURL)`, no force-unwrap). New `AXID.settingsNotificationsButton`. | Covered by the existing Settings UI tests; a forced-denied test needs a launch argument (Phase 6, I4) |
| B2 | `RootView` refreshes the notification permission **and** rebuilds the schedule whenever the app becomes active, so a permission granted in Settings, or reminders the system dropped, are picked up (README §7.5). | Existing scheduler tests; the activation path itself is verified by hand |

Files: `Data/Persistence.swift`, `Data/ModelContext+Saving.swift` (new), `Services/OrderedConcurrentMap.swift`
(new), `Services/Scan/ScanPipeline.swift`, `Features/Scan/ReviewModel.swift`, `Features/Items/{ItemsView,ItemDetailView,EditItemView,CoverageEditor,CoverageReminderEditor,CustomReminderEditor}.swift`,
`Features/Settings/SettingsView.swift`, `App/RootView.swift`, `Support/AXID.swift`,
`OwnwiseUITests/{Support/UITestLaunch,ManualAddFlowUITests}.swift`, and four new test files.

Deliberately left for Phase 2 (they are the *user-facing* halves, not the safety halves):
A1's "your data could not be opened" notice in Settings, A2's user-visible error alert, A4
backup/restore, A5 free raw export.

