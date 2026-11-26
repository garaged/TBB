# TBB-BKP-001 — Portable backup and restore

## Intent

People can export and recover budget data independently of a particular device or iCloud account. Restore must not silently overwrite a budget or modify a shared space.

## Scope and acceptance

- Export an explicitly selected budget space to a versioned portable file using the system document interface. Explain when the selected space contains household data shared by others.
- Default to password-encrypted export; allow unencrypted export only with a clear warning. A backup password is supplied explicitly at export and restore, may be the same as the local unlock password, and is never stored in the archive or logs. Losing it makes the encrypted archive unrecoverable.
- A backup contains the selected ledger's accounts, categories, transactions, budgets, base currency, and necessary version metadata. It does not include authentication material, CloudKit credentials, participant identities, share URLs, invitations, or share permissions.
- Restore validates the complete archive and presents a non-mutating preview before confirmation. Corrupt, truncated, wrong-password, unsupported-version, oversized, malformed, and invalid-ledger inputs fail closed without changing existing data.
- Restore creates a new independent private space with fresh space identity. It never writes into an existing private or shared space or recreates CloudKit sharing. A future replacement/merge operation requires its own design.
- The restore commit is transactional: failure leaves existing data unchanged, and incomplete restored spaces do not appear. Restoring an archive twice creates separate copies only after explicit confirmation each time.
- Encrypted exports use a vetted password KDF with random salt and versioned, bounded work parameters, and authenticated encryption with a fresh nonce. Authenticate envelope metadata; do not treat a plain checksum as authentication. Verify wrong passwords and modifications before parsing or persistence.
- Handle sensitive content without recording amounts, notes, passwords, keys, or archive content in logs. Use appropriate protected temporary storage if temporary files are unavoidable and remove them on completion or failure.
- Restore is available without network access. iCloud synchronization of the newly created private space remains subject to the app's normal synchronization behavior.
- Automated coverage includes archive round trips, version handling, independently reproducible crypto vectors, malformed inputs and size/work limits, cross-space isolation, transactional failure, and plaintext-data leak checks. Manual acceptance covers iPhone and iPad export, fresh-install restore, wrong passwords, cancellation, offline operation, and shared-space isolation.

## Archive format and compatibility

- A `.tbbbackup` file is UTF-8 JSON. The keys `version` (integer 2 for new writes), `encrypted` (boolean), and `data` (Base64 bytes) are required. Maximum file size is 16 MiB. The JSON payload (maximum 8 MiB) contains `name` and `ledger`. Financial values use integer minor units. Dates use the Foundation reference epoch, seconds since 2001-01-01T00:00:00Z.
- In encrypted mode, `salt` contains 16 fresh random bytes in Base64 and `iterations` must equal 600000. PBKDF2-HMAC-SHA256 uses the password's exact UTF-8 bytes (1–1024 bytes) and yields a 32-byte key. AES-256-GCM stores a fresh 12-byte nonce, ciphertext and 16-byte tag, concatenated in that order. The authenticated data is the ASCII string `TBB-backup-v2:encrypted:PBKDF2-HMAC-SHA256:600000:AES-256-GCM:` followed by the 16 raw salt bytes.
- In unencrypted mode, `data` is the payload and `checksum` is its Base64 SHA-256 digest for detecting accidental damage. An editor can recompute it. TBB labels the file unauthenticated during import as well as export. Encrypted and unencrypted headers are mutually exclusive. Unknown versions require a future explicit reader.
- The compatibility fixtures in `BackupArchiveTests.swift` were produced independently of TBB using Python PBKDF2 and AESGCM. File selection, preflight, cancellation and password retries cannot write into Core Data. Only confirmation creates a private budget.
- The reader also accepts the original v1 format. Its encrypted AAD is `TBB-backup-v1-PBKDF2-SHA256-AES-GCM` in ASCII. Its plaintext payload may have no checksum and receives the unencrypted-file warning before preview and confirmation. Writers produce v2.
- Backup encryption password is distinct from device authentication. Reusing a local password is a user choice, not an automatic retrieval of the app-lock secret.
- A digital signature cannot be assumed to establish archive authenticity without a trustworthy signing-key distribution and recovery design. Unencrypted backups must be labeled unauthenticated; encrypted backups receive password-based authenticity through AEAD.
- Owners and participants can export the locally readable contents of the selected budget. Removing a participant later cannot revoke an exported file. Restore imports the ledger snapshot and starts a fresh space and mutation history.
- M5 follow-up: scene cold-start invitation metadata and CloudKit acceptance errors require a separate correction before release; M6 must not claim they are resolved.

### Compatibility fixture inputs

The fixture in `readsIndependentV1Archive` uses this exact UTF-8 payload with no trailing newline.

```json
{"name":"Fixture","ledger":{"baseCurrencyCode":"MXN","accounts":[],"categories":[],"transactions":[],"budgets":[]}}
```

To reproduce both fixtures' `data` fields with Python and the `cryptography` package, assign the payload bytes above to `payload` and run the following. Fixed randomness is confined to this fixture.

```python
import base64
import hashlib
from cryptography.hazmat.primitives.ciphers.aead import AESGCM

salt = bytes(range(16))
nonce = bytes(range(12))
key = hashlib.pbkdf2_hmac("sha256", "fixture-ñ".encode("utf-8"), salt, 600_000, 32)
headers = (
    b"TBB-backup-v1-PBKDF2-SHA256-AES-GCM",
    b"TBB-backup-v2:encrypted:PBKDF2-HMAC-SHA256:600000:AES-256-GCM:" + salt,
)
for aad in headers:
    print(base64.b64encode(nonce + AESGCM(key).encrypt(nonce, payload, aad)).decode("ascii"))
```

### Validation limits

The reader supports up to 1,000 accounts, categories and budget plans each, 10,000 transactions, 4,096 UTF-8 bytes per note and 80 characters per space name. Dates must fit Foundation's `distantPast...distantFuture`. Validation checks references, currencies, unique identities, balance accumulation and aggregate arithmetic before preview. For ledgers with budget plans, total expense minor units must fit a thousandfold scale for progress. A recurring plan must fit one million allocations in signed 64-bit minor units. Exports over these limits fail with an error. TBB never truncates the selected ledger to fit.

## References

- Apple CryptoKit AES-GCM authenticated encryption: https://developer.apple.com/documentation/cryptokit/aes/gcm
- OWASP Cryptographic Storage Cheat Sheet: https://cheatsheetseries.owasp.org/cheatsheets/Cryptographic_Storage_Cheat_Sheet.html
