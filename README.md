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