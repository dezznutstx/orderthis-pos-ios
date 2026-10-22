# OrderThis POS for iOS — first native port

This is a new SwiftUI iOS project based on the supplied Android POS 7.8.1 source. It targets iOS 16+ on iPhone and iPad, and includes a GitHub Actions workflow that compiles it on a hosted macOS runner.

## Included in this first port

- Device pairing with the OrderThis pairing endpoint
- Staff PIN login
- Restaurant menu and open tabs
- Category filtering, cart quantity controls, and opening a tab
- Saving the tab and sending a new order to the kitchen
- OrderThis logo assets
- Hosted iOS Simulator build workflow

## Still to port

The supplied project is Android-only. Square Reader payments, Star printer support, clock in/out, KDS, modifiers, discounts, receipts, and manager actions need iOS implementations and testing. Poynt integration is intentionally excluded. This first port does not collect payments.

## Build without owning a Mac

1. Create a GitHub repository and put the **contents of this folder** in the repository root, including `.github/workflows`.
2. In GitHub, open **Actions** and run **Build iOS Simulator App**.
3. Download the simulator app archive from the workflow artifacts.
4. To distribute through TestFlight or the App Store, add Apple signing credentials and configure a distribution workflow. The included workflow builds an unsigned simulator app only.

The workflow installs XcodeGen and generates the Xcode project on the hosted macOS runner.
