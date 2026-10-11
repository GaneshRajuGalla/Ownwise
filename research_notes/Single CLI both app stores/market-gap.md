# Market Gap: Unified Single CLI for Both App Stores

## Is there any maintained unified iOS+Android release CLI?

### Takeaway
fastlane is the only maintained unified iOS+Android release CLI (42.2k stars, still releasing), but it is Ruby-based with volunteer maintenance; every other player covers only one store, one ecosystem, or is a hosted dashboard with no CLI.

### Cited Findings
- fastlane latest release is 2.240.1, published 15 Sep 2026, with regular monthly releases through 2.234.0–2.240.x in 2026 — [fastlane releases](https://github.com/fastlane/fastlane/releases)
- fastlane has 42.2k stars, 6.0k forks, 511 open issues, 154 open PRs, and covers both stores via `deliver` (App Store), `supply` (Play), `pilot`, `snapshot`/`screengrab`, `precheck`, `match` — [fastlane repo](https://github.com/fastlane/fastlane); [fastlane docs](https://docs.fastlane.tools/)
- fastlane requires Ruby 3.2+ (prefers 3.3+), installed via Bundler/Homebrew/RubyGems; recent releases dropped Ruby 3.0 and 2.7 and warn on old Rubies — [fastlane docs](https://docs.fastlane.tools/)
- fastlane maintenance is community-volunteer driven (contributors iBotPeaches, lacostej et al.) and funded via OpenCollective donations — [fastlane releases](https://github.com/fastlane/fastlane/releases) (donation note on 2.234.0); [fastlane repo metrics section](https://github.com/fastlane/fastlane)
- EAS Submit uploads binaries to both Google Play (tracks: internal/alpha/beta/production, draft releaseStatus) and App Store Connect/TestFlight with one command (`eas submit`), works from any OS and CI via `--non-interactive` — [Expo submit docs](https://docs.expo.dev/deploy/submit-to-app-stores/)
- EAS Submit explicitly does NOT manage store metadata, screenshots, or release notes; EAS Metadata is only "in preview" — [Expo submit docs FAQ](https://docs.expo.dev/deploy/submit-to-app-stores/)
- Bitrise CLI (901 stars) is a CI workflow runner (`bitrise local run`, `yml validate`), not a store-release tool; store submission happens via separate Steps inside Bitrise cloud — [bitrise-io/bitrise](https://github.com/bitrise-io/bitrise)
- Codemagic cli-tools (493 stars, GPL-3.0) are fragmented per-store Python utilities (`app-store-connect` and `google-play` are separate executables), built to power codemagic.io builds — [codemagic-ci-cd/cli-tools](https://github.com/codemagic-ci-cd/cli-tools)
- Runway is a hosted release-management dashboard (release trains, rollouts, automations); its CLI/API surface is API access + MCP access gated to paid/Enterprise tiers, not a local release CLI — [Runway pricing](https://www.runway.team/pricing)
- Tramline is a self-hosted Rails web app (407 stars, Apache-2.0), not a CLI; cross-platform release trains and store integrations run server-side — [tramlinehq/tramline](https://github.com/tramlinehq/tramline); [Tramline pricing](https://www.tramline.app/pricing)

### Inferences
- The "decaying" framing of fastlane needs nuance: it ships monthly releases as of Sep 2026, but bus-factor risk is real (handful of volunteer maintainers, donation-funded), and the Ruby toolchain remains a structural adoption barrier for JS/Swift/Kotlin-native teams.
- No credible maintained tool offers `one CLI → both stores → metadata + screenshots + staged rollout + review submission` from a laptop/CI without a hosted account; that is the gap.

### Gaps
- Could not verify per-contributor commit share or Google stewardship end-date for fastlane (relevant to "decaying" quantification); needs a follow-up lookup.
- Ionic Appflow coverage and pricing not checked (tool-call budget exhausted).

## What do developers complain about most in mobile release automation?

### Takeaway
The documented rejection surface (crashes, incomplete metadata, missing demo accounts, dead backends, screenshot/metadata mismatch) matches exactly what fastlane's `precheck` automates only a thin slice of; screenshot-device-matrix overhead and staged-rollout/review-submission fragmentation are structural, per official docs.

### Cited Findings
- Apple's official "Before You Submit" checklist names the top review blockers: test for crashes/bugs, complete metadata, demo accounts or demo mode, live backend services, review notes for non-obvious features/IAP — [App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)
- Guideline 2.1(a) rejects "placeholder text, empty websites, and other temporary content"; 2.3.x requires screenshots to show the app in use with accurate metadata per locale — [App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)
- fastlane `precheck` checks only a community-driven text-rule subset: Apple-sentiment mentions, swear words, other-platform mentions, unreachable URLs, placeholder/test words, future-functionality claims, copyright year, custom word lists; iOS only — [precheck docs](https://docs.fastlane.tools/actions/precheck/)
- fastlane's own precheck docs invite users to "submit an issue on GitHub and provide information about your App Store rejection" to grow the ruleset, confirming rule coverage is crowdsourced and incomplete — [precheck docs](https://docs.fastlane.tools/actions/precheck/)
- EAS splits the release across tools: Submit uploads binaries only; metadata is manual in store consoles or via preview-stage EAS Metadata; iOS still requires completing metadata/screenshots in App Store Connect before App Review — [Expo submit docs](https://docs.expo.dev/deploy/submit-to-app-stores/)
- Runway's automation catalog (auto submit-for-review, phased-rollout accelerate/halt, staged rollouts, review translations) exists only as hosted SaaS automations, implying these steps are painful enough to sell as a service — [Runway pricing feature table](https://www.runway.team/pricing)
- fastlane has 511 open issues against 17,035 commits, a rough proxy for accumulated papercuts in a volunteer-maintained Ruby codebase — [fastlane repo](https://github.com/fastlane/fastlane)

### Inferences
- Recurring pain clusters supported by primary sources: (1) metadata-caused rejections, (2) screenshot/localization matrix toil, (3) staged-rollout + review-submission choreography across two different store consoles/APIs.
- Indie/small-team complaint quotes (Reddit, forums, fastlane issues) would strengthen this but were not retrievable in this pass.

### Gaps
- No direct developer quotes retrieved (web search was unavailable; forum/Reddit/GitHub-issue voices unverified). Recommend a follow-up pass over fastlane issues, Expo forums, and r/iOSProgramming for verbatim complaints.
- Play-side rejection/review pain (policy strikes, staged-rollout halts) not sourced.

## What is the release-readiness / pre-submission lint space?

### Takeaway
Pre-submission linting today is essentially fastlane `precheck` (metadata text rules, iOS-only, crowdsourced) plus Apple's human-readable checklist; there is no cross-store, binary+metadata+policy readiness gate.

### Cited Findings
- `precheck` (alias `check_app_store_metadata`) runs warn-or-error rule levels configurable via Precheckfile and integrates with `deliver` via `precheck_default_rule_level: :error` — [precheck docs](https://docs.fastlane.tools/actions/precheck/)
- EAS Submit failure diagnosis is log-scraping in the EAS dashboard ("Build Annotations" bubbles highlight common failure reasons) — reactive, not pre-upload lint — [Expo submit docs FAQ](https://docs.expo.dev/deploy/submit-to-app-stores/)
- Apple's review guidelines are a ~5-section human document (Safety, Performance, Business, Design, Legal) with no official lint API; automation must encode them by hand, which is what precheck's rules do — [App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)

### Inferences
- A "release readiness" gate spanning both stores (metadata rules + screenshot presence per locale + privacy manifests + track/rollout config + policy-keyword scan) has no incumbent; precheck is the closest ancestor and is iOS-text-only.

### Gaps
- Third-party rejection-prediction or policy-scan startups (if any) not surveyed; screenshots.pro and similar adjacent tools not checked.

## What monetization exists in adjacent devtools?

### Takeaway
Teams already pay per-app per-month for release orchestration (Tramline $50/app/mo; Runway per-app custom) and pay Expo $19–$199/mo+ for build/submit convenience — evidence of willingness to pay, with open-core (Tramline Apache-2.0 + paid hosting) as the proven model in this exact category.

### Cited Findings
- Tramline: Hobby $0 (2 apps, 15 releases/app/yr), Team $50/month per app, Enterprise from $600/month; Enterprise free for open source; on-prem available — [Tramline pricing](https://www.tramline.app/pricing)
- Tramline is Apache-2.0 open source on GitHub (407 stars) with paid hosted/assisted tiers — open-core precedent — [tramlinehq/tramline](https://github.com/tramlinehq/tramline); [Tramline pricing](https://www.tramline.app/pricing)
- Runway: free Basic (2 apps), Team and Enterprise "priced per app" (contact sales), unlimited users on paid plans — [Runway pricing](https://www.runway.team/pricing)
- Expo: Free $0, Starter $19/mo, Production $199/mo, Enterprise custom; Submit included on all plans; overage billed per-build ($1–$4) and per CI minute — [Expo pricing](https://expo.dev/pricing)
- fastlane is MIT, free, donation-funded via OpenCollective — no commercial tier — [fastlane repo](https://github.com/fastlane/fastlane)

### Inferences
- Price anchoring for a unified CLI: free local CLI (MIT/Apache) + paid hosted dashboard/CI minutes in the ~$19–$50/mo/app band matches both Tramline and Expo data points.
- fastlane's zero-revenue volunteer model is arguably the market failure creating the gap.

### Gaps
- screenshots.pro pricing and Runway/Tramline actual ARPU/customer counts not retrieved; willingness-to-pay sizing is directional only.

## What role do agent skills and MCP servers play as CLI distribution in 2026?

### Takeaway
Skills and MCP servers are now first-class distribution for release tooling: Expo ships both an MCP server and a submit/release skill, and Runway ships a Claude connector + MCP access — a new CLI should launch with a skill + MCP surface on day one.

### Cited Findings
- Expo publishes an `eas-app-stores` skill ("Build and submit iOS and Android apps with EAS to TestFlight, the App Store, or Google Play") for AI agents — [Expo submit docs](https://docs.expo.dev/deploy/submit-to-app-stores/)
- Expo lists an "Expo MCP Server" as a plan feature on all tiers (fair-use on Free) — [Expo pricing](https://expo.dev/pricing)
- Expo docs pages carry `<AgentInstructions>` blocks with machine-readable navigation and a feedback-submission CLI (`npx submit-expo-feedback`), showing docs-as-distribution for agents — [Expo EAS docs](https://docs.expo.dev/eas/)
- Runway lists "MCP access" as a paid-tier feature and announced an "Official Claude connector and expanded MCP" in July 2026 — [Runway pricing](https://www.runway.team/pricing) (nav/whats-new entries)
- Bitrise CLI added `rde claude` (attach cloud dev environment to Claude Code), showing CI vendors meeting agents where they are — [bitrise-io/bitrise](https://github.com/bitrise-io/bitrise)
- Classic distribution persists alongside: fastlane via Homebrew/Bundler/RubyGems, Bitrise via brew/nix/binary, Codemagic via PyPI (`pip install codemagic-cli-tools`, Python 3.8+) — [fastlane docs](https://docs.fastlane.tools/); [bitrise-io/bitrise](https://github.com/bitrise-io/bitrise); [codemagic-ci-cd/cli-tools](https://github.com/codemagic-ci-cd/cli-tools)

### Inferences
- 2026 distribution stack for a new CLI: Homebrew (+ version-manager-friendly install) for humans/CI, plus an agent skill and an MCP server for agent-driven releases; Expo and Runway have validated all three motions.

### Gaps
- Community `asc`/`gplay` skills and MCP-registry listings for store CLIs not verified; adoption metrics for Expo MCP/skills usage not public.
