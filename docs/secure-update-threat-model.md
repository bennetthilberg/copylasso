# Secure Update Threat Model

This document defines the G35 trust boundary selected for CopyLasso 0.2. It is a
design and local proof, not evidence that an updater or public feed ships today.

## Assets and Trust Boundaries

Protected assets are the installed application, the user's decision to update,
the release-signing private key, the authenticated version history, and the
temporary downloaded package. The trusted inputs are the public key compiled
into CopyLasso, an Ed25519-signed appcast, an Ed25519-signed enclosure, and the
Developer ID/notarization checks already enforced by the release workflow.

The update server, GitHub hosting, DNS, TLS, caches, and network path are useful
transport but are not trusted to authorize installation. The application must
fail closed before replacing any installed bytes.

## Threats and Controls

| Threat | Required control | Failure result or residual risk |
| --- | --- | --- |
| Feed or CDN compromise | Require signed appcast; reject malformed XML, unknown fields that weaken policy, and unsigned or invalid data | No update; current app remains usable |
| GitHub release compromise or artifact substitution | Verify enclosure Ed25519 signature, exact length, immutable release URL, Developer ID identity, notarization, version, and architecture | No install; compromised release account can cause denial of service but not authorize unsigned bytes |
| DNS, TLS interception, redirect, or alternate host | Fixed HTTPS feed, strict enclosure host/path policy, no credentials, signature checks independent of transport | Network failure or rejected candidate |
| Replay or downgrade | Compare numeric `CFBundleVersion` with installed and highest authenticated build; preserve the authenticated high-water mark | Older authenticated release is rejected; local preference deletion can remove the extra high-water defense, but never the installed-build defense |
| Version or archive metadata mismatch | Feed build/display version must equal verified archive metadata | Candidate rejected before install |
| Oversized, empty, truncated, or length-mismatched archive | Signed declared length, actual-length equality, 256 MiB cap, bounded temporary staging | Candidate rejected and staging removed |
| Key theft | Protected release environment, nonsynchronized Keychain use, encrypted offline recovery copy, least-access workflow, and documented revocation | A stolen active key can authorize malicious feeds and archives; Developer ID/notarization and rapid revocation are independent defenses |
| Key loss | Encrypted recovery copy and tested rotation procedure | Release publication pauses; installed apps continue operating |
| Key rotation or revocation error | One active transition at a time, appcast signed by the trusted old key, release with replacement public key, explicit readback and rollback plan | 0.1.x and any build lacking the replacement key require manual bootstrap if trust continuity is broken |
| Release workflow compromise | Protected GitHub environment, immutable tags, exact-head CI, separate Developer ID and Ed25519 secrets, artifact readback | Publication stops on mismatch; never replace bytes under an existing tag |
| Bad or revoked release | Remove the candidate from the signed feed, preserve immutable release evidence, retain the authenticated high-water mark, and use a separately reviewed incident release | Installed copies are not silently downgraded; remediation requires a newer authenticated build |
| Offline, timeout, server outage, malformed response | Bounded request, cancel path, user-safe error, no destructive action before verification | No update; app and clipboard remain unchanged |
| Cancellation, interruption, crash, or disk exhaustion | Temporary transaction directory, atomic installer boundary, cleanup on failure and next launch | Installed app remains unchanged; stale temporary bytes are deleted |
| User tricked into an update | Show authenticated version, notes, size, source, and consequences; require explicit download and install/relaunch choices | User can still approve a legitimately signed but unwanted release; transparent notes and deferral reduce this risk |
| Privacy leakage | No system profiling, stable identifier, cookies, custom headers, content, clipboard, or screen data; fixed daily feed request only | Server sees ordinary IP/time and Sparkle's product/version user agent, as inherent in an HTTPS request |

## Security Invariants

No invalid, downgraded, replayed, mismatched, malformed, oversized, interrupted,
or unconfirmed update reaches installation. Every rejected or failed path leaves
the current application runnable and removes transient update bytes. A feed
outage can never disable capture. Update failures never inspect, log, persist, or
transmit screenshots, recognized text, clipboard text, or HUD previews.

The app does not accept arbitrary feed overrides, enclosure domains, redirects
to unapproved locations, or release-channel identifiers. G35 contains no
production public key, private key, public feed, published update artifact, or
shipping network entitlement.
