# EasyStreet native

- Keep iOS, Android, and the sibling easystreet-monorepo aligned on sweeping and holiday semantics. Calculate observed holidays dynamically; do not hardcode year lists.
- Preserve memory-conscious street-data loading. Location/time changes need notification, permission, and map-flow verification on the affected platform.
- `EasyStreet/project.yml` is the generated Xcode project's source. Regenerate with xcodegen when its inputs change; use the current installed simulator destination for builds/tests.
- Validate the affected iOS target or Android Gradle build/tests. Build/setup details belong in README.md and platform project configuration.
