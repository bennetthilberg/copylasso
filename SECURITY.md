# Security Policy

## Supported Versions

CopyLasso 0.2.x is the currently supported public release line.
CopyLasso 0.2.2 is the latest public release. It ships the user-controlled
secure updater, configurable success sound, focus-preserving native selector, and
unified on-screen text and code recognition. Security reports about the
released application, updater, audio or code-recognition trust boundaries,
source, build process, protected release workflow, or repository configuration
are welcome.

Version `0.2.2 (5)` updates the shipping Sparkle framework to 2.9.5 for the
upstream `GHSA-gmj2-gq3j-vqmj` fix while retaining authenticated
full-package-only updates and the existing security boundary.

The release-qualified v0.3 source tree adds local OCR language preferences backed only by
the current Apple Vision runtime catalog. It adds no model, dependency,
entitlement, content egress, or new permission. Reports about preference
validation, catalog fallback, or per-capture language snapshotting are welcome.

The same release-qualified v0.3 source line adds **Save Capture History**, off by default.
It stores only successful text and inert code output in one AES-256-GCM archive
for seven days, capped at 100 entries and 256 KiB per entry. The random key uses
the bundle-scoped, nonsynchronizing Keychain account `archive-key-v1`.
Screenshots remain memory-only. Reports about consent, authentication failure,
retention, Keychain scope, deletion, plaintext exposure, or recursive recording
are welcome. CopyLasso 0.2.2 remains the latest public release and has no history
feature.

| Version | Supported |
| --- | --- |
| 0.2.x | Yes |
| 0.1.x | No |

## Report a Vulnerability Privately

Use [GitHub Private Vulnerability Reporting](https://github.com/bennetthilberg/copylasso/security/advisories/new) to report a suspected vulnerability. Please do not disclose the issue in a public GitHub issue, discussion, pull request, or social post before a fix and coordinated disclosure are ready.

Include enough information to reproduce and assess the report when possible:

- the affected revision, version, or component;
- reproduction steps or a minimal proof of concept;
- the security impact and required conditions; and
- suggested mitigations, if known.

Remove passwords, tokens, signing credentials, private keys, personal screen captures, recognized private text, and unrelated personal data before submitting a report. The maintainer will use the private advisory to clarify the report and coordinate remediation and disclosure.

General defects without a security impact may be reported through the repository's public issue tracker.

For updater reports, include whether the issue affects feed or enclosure authentication, version/replay ordering, download-size enforcement, staging, installer services, consent or deferral, relaunch, private release metadata, or the fixed feed/enclosure URL policy. Do not attach a private signing seed, protected appcast, Developer ID credential, notarization credential, or private release artifact to a public issue. Use the private advisory route above.

For code-recognition reports, include the affected symbology and whether the issue concerns result precedence, payload ordering, duplicate removal, clipboard preservation, automatic payload actions, content retention, logging, or unexpected network or file access. CopyLasso never opens or acts on a recognized code payload.
