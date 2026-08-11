# Capture History Architecture

G52 adds an unreleased, opt-in persistence boundary to the v0.3 source tree.
CopyLasso 0.2.2 remains the latest public release and contains no capture
history.

## Data boundary

`CaptureCommand` sends the history recorder only the exact plain-text output
and its Text or Code type after the clipboard write and optional success sound.
No image, Vision observation, display identifier, selection geometry, source
application, previous clipboard value, or HUD model crosses this boundary.
Failed, cancelled, ambiguous, no-result, and clipboard-failed operations never
call it. Copying from History writes directly to the clipboard and cannot
re-enter the recorder.

History is off by default. The disabled path creates neither an archive nor a
Keychain item. When enabled, repeated identical captures remain distinct events.
The pure policy retains entries newest-first for exactly seven days, caps the
archive at 100 events, and rejects any one UTF-8 payload over 256 KiB.

## Encryption and storage

`EncryptedCaptureHistoryStore` encodes a versioned property-list payload and
seals it with AES-256-GCM. The fixed version header is authenticated as
additional data. Entry content, identifiers, timestamps, and types exist only
inside the ciphertext. The one archive is atomically replaced at:

```text
Library/Application Support/<bundle identifier>/CaptureHistory.clh
```

The sandbox maps that path into the app container. The archive receives `0600`
permissions and the backup-exclusion resource value. A 32-byte random key lives
in a generic-password Keychain item with service
`<bundle identifier>.capture-history`, account `archive-key-v1`, synchronization
disabled, and `AfterFirstUnlockThisDeviceOnly` accessibility. Production and
Debug therefore have independent keys and archives.

Missing keys, wrong keys, authentication failure, truncation, unknown versions,
oversized archives, and failed writes expose no entry. The store never replaces
unreadable bytes silently. A confirmed destructive recovery removes the active
archive and app-owned key. App-driven deletion cannot guarantee forensic erasure
from APFS snapshots or external system backups.

## Ownership and lifetime

The main-actor `CaptureHistoryController` owns user consent, decrypted window
state, copy/delete actions, and expiry scheduling. It prunes on launch, read,
write, and the next in-process expiry. If CopyLasso is not running at expiry,
expired content remains encrypted and hidden until the next launch removes it.

Closing History clears its decrypted entries. Sleep, screen sleep, session
resign, and termination route through the lifecycle controller and clear them
again; an open window requires an explicit reload after unlock. Clear All
deletes both active storage objects, creates a new key, and leaves history
enabled. Disabling empty history is immediate, while existing or unreadable
data requires confirmation.

A history-store failure happens after clipboard success. It cannot roll back
the copy or suppress sound; the bounded **Copied, History Not Saved** HUD replaces
ordinary success feedback. No storage error includes content or raw platform
details.

## Security invariants

- No screenshots or recognition observations are encoded or persisted.
- The history adapter adds no networking, logging, entitlement, account,
  synchronization, analytics, dependency, or permission.
- The existing persistence guard allows file APIs only in the reviewed encrypted
  adapter while continuing to reject captured-image persistence everywhere.
- Keychain and AES-GCM APIs are confined to the adapter.
- UI fixtures are Debug-only and never enter a Release build.
