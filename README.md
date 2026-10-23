# LegacyDisplay

Native Swift and UIKit iOS Application.

## Architecture & Requirements
- **Platform**: iOS 15.0+
- **Technology Stack**: Swift 5.0, UIKit, Auto Layout (Programmatic + Storyboard Launch)
- **IDE**: Xcode 15+ compatible
- **Testing**: Native XCTest unit test suite

## Project Structure
```
LegacyDisplay/
├── LegacyDisplay.xcodeproj/          # Xcode project configuration
│   └── xcshareddata/xcschemes/       # Shared build & test schemes
├── LegacyDisplay/                   # Primary application source
│   ├── AppDelegate.swift            # Application lifecycle
│   ├── SceneDelegate.swift          # Window & scene management
│   ├── ViewController.swift         # UIKit root view controller
│   ├── Info.plist                   # App bundle manifest
│   ├── Assets.xcassets/             # Assets and color sets
│   └── Base.lproj/LaunchScreen.storyboard
├── LegacyDisplayTests/              # Unit test suite
│   ├── LegacyDisplayTests.swift     # XCTest test cases
│   └── Info.plist
└── .github/workflows/ios-ci.yml     # Automated iOS CI pipeline (macOS-14 runner)
```

## Development & Git Workflow

### Branch Protection & Policy
- **Direct commits to `main` are prohibited** during ordinary feature development.
- All changes must follow the standard pull request cycle:
  1. Branch off `main` with a descriptive name: `feature/<feature-name>` or `fix/<fix-name>`.
  2. Implement changes, add unit tests, and commit cleanly.
  3. Push to `origin <feature-branch>`.
  4. Open a Pull Request targeting `main`.
  5. Verify that the **iOS CI** GitHub Actions check succeeds.
  6. Review and merge via GitHub PR (Squash or Rebase merge).
