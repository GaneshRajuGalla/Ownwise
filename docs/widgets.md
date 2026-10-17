# Turning on the widget

The widget's data half is built, tested and **inert** until this build has an App Group. The widget
target itself is created in Xcode, because an extension needs its own bundle id, provisioning and
capability — none of which can be added from a script without breaking code signing.

What is already built (no capability needed):

| Piece | Where | What it does |
|---|---|---|
| Snapshot | `Ownwise/Services/Import/SharedSnapshot.swift` | The file a widget reads: up to five entries with the item's name, what is running out and the date. Pure Foundation, so the widget target can add it without SwiftData. |
| Builder | `Ownwise/Services/Import/SnapshotBuilder.swift` | Fills it in from the library, using the same "needs attention" rules as the Home screen. Long-expired cover is left out: a widget that only says "expired" is noise. |
| Refresh | `ReminderScheduler.rescheduleAll` | Rewritten whenever reminders are rebuilt — launch, foreground, every edit — so the widget cannot drift from the app. |
| Widget | `Extensions/OwnwiseWidget/OwnwiseWidget.swift` | The widget itself, committed and complete, in **no target** yet. |

`SharedSnapshot.default` resolves the same `OwnwiseAppGroupID` Info.plist key as the share inbox
(`AppGroup`). With no key or no granted capability it reads and writes nothing, so today's build is
exactly as it was.

## The four steps

### 1. App Group

If you have already done `docs/share-extension.md` step 1, this is done. Otherwise: Certificates,
Identifiers & Profiles → Identifiers → `com.ownwise.Ownwise` → enable **App Groups** → create
`group.com.ownwise.Ownwise`.

### 2. The app's entitlements and Info.plist

Also shared with `docs/share-extension.md` step 2. Both halves need the same entitlement, and the app
needs the key it reads:

```xml
<key>OwnwiseAppGroupID</key>
<string>group.com.ownwise.Ownwise</string>
```

Add the same key to the **widget's** Info.plist: `SharedSnapshot.default` reads `Bundle.main`, which is
the widget's bundle when the widget is the one running.

### 3. The widget target

In Xcode: File → New → Target → **Widget Extension**, name `OwnwiseWidget`, bundle id
`com.ownwise.Ownwise.OwnwiseWidget`, team `QH858K43GZ`, same version and build number as the app.
Uncheck "Include Configuration Intent" (this widget needs no configuration), and delete the template's
`@main` file and its sample code. Then:

1. Add **`Extensions/OwnwiseWidget/OwnwiseWidget.swift`** to the target.
2. Add **`Ownwise/Services/Import/SharedSnapshot.swift`** to the target as well. It is pure
   Foundation on purpose, so it compiles there without the app's models. Do *not* add
   `SnapshotBuilder.swift` — that one needs SwiftData and belongs to the app.
3. Add the App Group capability to the widget target in Signing & Capabilities.

### 4. Test it

Open the app once (so it writes a snapshot), then add the widget from the Home Screen or the Lock
Screen. To see what the app actually wrote:

```
# Replace with the app's container path from `xcrun simctl get_app_container`.
cat "$(xcrun simctl get_app_container booted com.ownwise.Ownwise group.com.ownwise.Ownwise)/Widget/expiring.json"
```

## Caveats to respect

- **One writer.** The widget never opens the SwiftData store; it reads the snapshot. That is why the
  app has to be opened for the widget to be exact — the snapshot's `generatedAt` is the honest
  "as of" time, and `getTimeline`'s six-hour refresh only re-renders, it does not re-read the library.
- **The `kind` string is frozen at write time** (already localised). A language change shows the old
  wording until the app is next opened, which is when the snapshot is rewritten.
- **No deep link yet.** Each entry carries its coverage and item ids, so tapping through to
  `ItemDetailView` is a small addition later (a `URL` scheme plus `.onOpenURL`), not a rework.
- **Keep the widget target tiny.** It should contain this file and `SharedSnapshot.swift` and nothing
  else of the app's.
