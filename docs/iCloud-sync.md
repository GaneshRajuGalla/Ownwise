# Turning on iCloud sync

Sync is implemented in code and **off** until this build is given somewhere to sync to. That is
deliberate: a CloudKit entitlement the App ID has not been granted fails code signing, which
would break the release build — so the app only offers sync once the build genuinely has it.

`SyncSettings` decides everything from one Info.plist key:

| State | `OwnwiseICloudContainer` | Behaviour |
|---|---|---|
| Today | absent | Local-only. No Settings row. `cloudKitDatabase: .none`. |
| Enabled | `iCloud.com.ownwise.Ownwise` | Settings → iCloud shows the toggle. Off by default; the user opts in. |

## The three steps

### 1. App ID and container (Apple Developer portal)

1. Certificates, Identifiers & Profiles → Identifiers → `com.ownwise.Ownwise` → enable **iCloud**
   with **CloudKit**.
2. Create a CloudKit container named `iCloud.com.ownwise.Ownwise` and assign it to the App ID.
3. Let Xcode refresh the provisioning profile (`-allowProvisioningUpdates` does it in CI).

### 2. Entitlements

Add `Ownwise/Ownwise.entitlements`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>com.apple.developer.icloud-container-identifiers</key>
	<array>
		<string>iCloud.com.ownwise.Ownwise</string>
	</array>
	<key>com.apple.developer.icloud-services</key>
	<array>
		<string>CloudKit</string>
	</array>
	<key>com.apple.developer.ubiquity-kvstore-identifier</key>
	<string>$(TeamIdentifierPrefix)$(CFBundleIdentifier)</string>
</dict>
</plist>
```

and set it on the app target's **both** configurations in `Ownwise.xcodeproj/project.pbxproj`:

```
CODE_SIGN_ENTITLEMENTS = Ownwise/Ownwise.entitlements;
```

### 3. Info.plist

Add to `Info.plist` (the same file `INFOPLIST_FILE` points at):

```xml
<key>OwnwiseICloudContainer</key>
<string>iCloud.com.ownwise.Ownwise</string>
```

Rebuild. Settings → iCloud appears, off by default; the user turns it on and reopens the app.

## Why the models already work

SwiftData + CloudKit requires every attribute to be optional or defaulted, every relationship to
be optional, and no `@Attribute(.unique)`. `SchemaV2` satisfies all three already, so no schema
change is needed to sync — which also means the *next* schema must keep satisfying them:

- never add `@Attribute(.unique)`
- never add a non-optional relationship
- give every new property a default value
- keep migrations lightweight

## Caveats to respect

- **`@Attribute(.externalStorage)` receipts become CloudKit assets** and count against the user's
  iCloud storage. The Settings footer says so; a 200-receipt library is tens of megabytes.
- **CloudKit regressed on iOS 26.4**; sync stays behind a toggle for that reason.
- **Enabling sync on an existing local store exports it** to the user's private database on first
  launch. Turning it back off leaves everything local — nothing is deleted.
- If iCloud cannot be opened at launch (no account, no network, entitlement missing),
  `Persistence.makeContainer` retries the *same* store locally before it ever suspects the store
  is damaged. See `didFallBackToLocalStore`.
