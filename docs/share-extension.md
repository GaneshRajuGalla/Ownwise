# Turning on the Share Sheet import

Importing a receipt from Mail, Safari, Amazon or Files is implemented in the app and **inert** until
this build is given a shared container. That is deliberate: an App Group the App ID has not been
granted fails code signing, which would break the release build — so the app only looks for shared
items once it genuinely has somewhere to look.

What is already built and tested (no capability needed):

| Piece | Where | What it does |
|---|---|---|
| Inbox contract | `Ownwise/Services/Import/SharedInbox.swift` | The folder format both halves use: `Pending/<id>/manifest.json` + the shared files, staged then moved so an entry is never half-written. `Failed/<id>/` holds anything the app cannot read, so nothing a user shared is deleted. |
| Importer | `Ownwise/Services/Import/InboxImporter.swift` | Drains the inbox: images and PDFs go through the same `ScanPipeline` (OCR · parse · Apple Intelligence) the camera uses, text is parsed directly, and the item is written by the same `ReviewModel.save` mapping. |
| Wiring | `Ownwise/App/RootView.swift` | Drains on launch/foreground. The free item limit applies here too — anything over it stays queued in `Pending`, not dropped. |
| Extension | `Extensions/ShareExtension/ShareViewController.swift` | Reads the shared item provider and calls `SharedInbox.enqueue`. **Not in a target yet** (see below). |

`SharedInbox.default` uses the container named by the `OwnwiseAppGroupID` key in Info.plist. With no
key — or without the capability — `containerURL(forSecurityApplicationGroupIdentifier:)` returns
nothing, so the inbox is a no-op and the app behaves exactly as it does today.

## The five steps

### 1. App Group (Apple Developer portal)

Certificates, Identifiers & Profiles → Identifiers → `com.ownwise.Ownwise` → enable **App Groups** and
create `group.com.ownwise.Ownwise`. Then do the same for the extension's App ID once it exists
(step 3) and tick the same group.

### 2. The app's entitlements and Info.plist

Add `Ownwise/Ownwise.entitlements`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>com.apple.security.application-groups</key>
	<array>
		<string>group.com.ownwise.Ownwise</string>
	</array>
</dict>
</plist>
```

set it on the app target's **both** configurations:

```
CODE_SIGN_ENTITLEMENTS = Ownwise/Ownwise.entitlements;
```

and add the key the app reads:

```xml
<key>OwnwiseAppGroupID</key>
<string>group.com.ownwise.Ownwise</string>
```

If iCloud sync is enabled as well (`Docs/iCloud-sync.md`), use **one** entitlements file containing
both dictionaries — a second `CODE_SIGN_ENTITLEMENTS` would silently replace the first.

### 3. The extension target

In Xcode: File → New → Target → **Share Extension**, name `ShareExtension`, bundle id
`com.ownwise.Ownwise.ShareExtension`, team `QH858K43GZ`, same version and build number as the app,
and uncheck "Activate scheme" prompts. Then:

1. Delete the template's `MainInterface.storyboard` reference and set `NSExtensionPrincipalClass` to
   `$(PRODUCT_MODULE_NAME).ShareViewController`.
2. Add **`Extensions/ShareExtension/ShareViewController.swift`** to the target (it is committed at
   the repo root but belongs to no target today, so nothing breaks until you do this).
3. Add **`Ownwise/Services/Import/SharedInbox.swift`** to the target as well. Both halves must agree
   on the manifest format, so they share one file instead of each having its own copy.
4. Add **`Ownwise/Services/Import/AppGroup.swift`** too. `SharedInbox` calls `AppGroup.directory` to
   find the container, so without this file the extension fails to build with *cannot find 'AppGroup'
   in scope*. It is deliberately a separate file (no SwiftData, read from any bundle) so both halves
   resolve the same container.
5. Give the extension its own entitlements file with the same App Group, and add the App Group
   capability in Xcode's Signing & Capabilities tab for both targets.
6. Add the **same `OwnwiseAppGroupID` key** to the extension's Info.plist. `SharedInbox.default`
   reads it from `Bundle.main` — which is the *extension's* bundle when the extension is the one
   running — so without this key the extension would quietly write nothing.

`Info.plist` for the extension:

```xml
<key>NSExtension</key>
<dict>
	<key>NSExtensionPointIdentifier</key>
	<string>com.apple.share-services</string>
	<key>NSExtensionPrincipalClass</key>
	<string>$(PRODUCT_MODULE_NAME).ShareViewController</string>
	<key>NSExtensionAttributes</key>
	<dict>
		<key>NSExtensionActivationRule</key>
		<dict>
			<key>NSExtensionActivationSupportsImageWithMaxCount</key><integer>5</integer>
			<key>NSExtensionActivationSupportsFileWithMaxCount</key><integer>5</integer>
			<key>NSExtensionActivationSupportsText</key><true/>
			<key>NSExtensionActivationSupportsWebURLWithMaxCount</key><integer>1</integer>
		</dict>
	</dict>
</dict>
```

### 4. Embed it

The app target must embed the extension (Xcode does this automatically for a new extension target).
For the App Store the extension needs its own **App Privacy** answers — none are needed: it collects
nothing and has no network code. Its display name should be `Ownwise` so the share sheet reads
"Ownwise" rather than "ShareExtension".

### 5. Test it

On a device or simulator with the app installed: share a PDF invoice from Files (or a receipt photo
from Photos) to Ownwise, then open Ownwise. The item is there with the receipt attached. Everything
that could not be read is in the App Group's `SharedInbox/Failed/`, which is also how to debug a
payload that does not import:

```
# Replace with the app's container path from `xcrun simctl get_app_container`.
ls "$(xcrun simctl get_app_container booted com.ownwise.Ownwise group.com.ownwise.Ownwise)/SharedInbox"
```

## Caveats to respect

- **The app is the only writer.** The extension never opens the SwiftData store; two processes on one
  SQLite file is how a library gets corrupted. Keep it that way: if the extension ever needs to show
  the library, pass a snapshot through the inbox, not the store.
- **The free limit applies to shares.** Over the limit the entries stay in `Pending` and import after
  an upgrade or a deletion, rather than being dropped or bypassing the limit.
- **A PDF is read through its first three pages**, rendered on the main actor (one receipt, not a
  twenty-page scan — the same trade-off as the Claim Pack, see C5). Everything after that is off it.
- **The extension should stay tiny.** Extensions are memory-limited (roughly 120 MB); it currently
  copies bytes and returns, doing no parsing, OCR or rendering of its own.
- **Not supported yet: a shared web page's full content.** Safari offers the URL and often the page
  text, which land in the item's notes; there is no article extractor, on purpose.
