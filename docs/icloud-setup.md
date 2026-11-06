# iCloud and CloudKit setup

TBB M5 uses Apple CloudKit for private and invite-only shared household spaces. It does not use a TBB-operated server, public financial-data database, or TBB account.

## Provisioning values

| Setting | Value |
|---|---|
| Apple Developer Team ID | `T3CCJTUTJ5` |
| App bundle ID | `org.garaged.TBB` |
| CloudKit container | `iCloud.org.garaged.TBB` |
| App capability | iCloud with CloudKit |

## One-time Apple Developer setup

1. Sign in at [Apple Developer Certificates, Identifiers & Profiles](https://developer.apple.com/account/resources/identifiers/list).
2. Create or edit the App ID `org.garaged.TBB` under Team `T3CCJTUTJ5`.
3. Enable **iCloud**, select **CloudKit**, and attach the `iCloud.org.garaged.TBB` container. Create that container if it does not exist.
4. In the [CloudKit Dashboard](https://icloud.developer.apple.com/dashboard/), select the container and create the development schema when Xcode first prompts. Do not deploy a production schema until the M5 two-Apple-Account acceptance passes.
5. In Xcode, choose Team `T3CCJTUTJ5` with automatic signing. Regenerate provisioning profiles after enabling the capability.

The checked-in `TBB.entitlements` is source-controlled configuration, not a credential. Certificates, profiles, Apple IDs, and private keys must never be committed.

## Validation boundary

A simulator can compile and exercise local behavior but cannot replace the required two-real-device acceptance using two separate Apple Accounts. See [M5 manual acceptance](manual-testing/m5-icloud-sharing.md).
