# Carpschool Native iOS Client

Pure native Swift 6 and SwiftUI application targeting **iOS 17.0+** for the Carpschool federated campus ridesharing network.

---

## Architecture

- **UI Framework**: SwiftUI with Observation framework (`@Observable`)
- **Maps**: Native Apple **MapKit** (`Map`, `MapCircle`, `Marker`)
- **Authentication**: Official `clerk-ios` SDK
- **WebSockets**: `Socket.IO-Client-Swift` for live negotiation chat
- **Location**: `CoreLocation` for discrete GPS snapshots (boarding and arrival)

---

## Generating Xcode Project

This project uses [XcodeGen](https://github.com/yonaskolb/XcodeGen) for clean, reproducible `.xcodeproj` generation from `project.yml`:

```bash
xcodegen generate
```

Then open `Carpschool.xcodeproj` in Xcode.
## UI tests

`CarpschoolUITests` drives the tap flows (add home, boarding PIN, board, drop-off, counter offer, report/block) against a live school server and attaches screenshots to the result bundle.

```sh
TEST_RUNNER_CS_PASSWORD=... TEST_RUNNER_CS_DRIVE=<locked carpool drive id> TEST_RUNNER_CS_NEG2=<open chat id> \
  xcodebuild test -scheme Carpschool -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' -only-testing:CarpschoolUITests
```

Each run consumes the carpool (rider gets dropped off) and blocks the test driver from the rider account; unblock afterwards.
