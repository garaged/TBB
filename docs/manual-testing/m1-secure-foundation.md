# M1 Manual Acceptance — Secure Foundation

Run this on a physical iPhone and an iPad after generating the Xcode project.

## Setup

```bash
brew install xcodegen
xcodegen generate
open TBB.xcodeproj
```

Set a development team in Xcode for the TBB target, select a physical device, then build and run.

## Acceptance

1. Confirm the overview loads on iPhone and iPad in portrait and landscape.
2. Confirm the eye button is always visible in the overview navigation bar.
3. Tap the eye button. Verify every displayed amount becomes `••••`, then tap again to reveal it.
4. Turn on VoiceOver. Verify the control announces “Hide monetary amounts” or “Show monetary amounts”, and the amount announces “Amounts hidden” when concealed.
5. In the Security flow, configure a password of at least eight characters. Confirm mismatch and leading/trailing-space errors do not enable lock.
6. Background TBB, then return. Confirm content is locked when a local password is configured.
7. Unlock using Face ID/Touch ID or device passcode. Disable device authentication or cancel it and confirm the local-password fallback remains available.
8. Reinstall or reset the app only after confirming that M1 has no financial records. Confirm the app does not claim password recovery is possible.
9. Confirm screenshots, system UI, or other apps are not represented as protected by Privacy Mode; Privacy Mode controls only TBB-owned presentation.

Record device model, iOS version, result, and any deviation in the PR before merge.
