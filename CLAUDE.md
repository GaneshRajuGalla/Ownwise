# Ownwise rules
- Spec: README.md. Read only the § named in the task.
- iOS 26 min, Swift 6, SwiftUI + SwiftData + Observation. No 3rd-party packages. No Combine/GCD/ObservableObject.
- Follow README §5 file layout exactly. One type per file.
- Design: README §8. System fonts (text styles) + system colors only. Glass only on controls.
- Never pass @Model across actors. Value types are Sendable.
- After edits run: xcodebuild -scheme Ownwise -destination 'platform=iOS Simulator,name=iPhone 18 Pro' -quiet build
- Tests: same command with `test` (unit + UI). Every feature ships with its unit tests; every flow in README §11 has a UI test.
- Fix all errors and warnings before replying.
- Reply ≤6 lines: files changed + build status. Don't paste code back. Don't re-read files you just wrote.
