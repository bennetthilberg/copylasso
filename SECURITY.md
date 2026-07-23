# Security Policy

## Supported Versions

CopyLasso 0.1.x is the currently supported public release line. Current source also contains the user-controlled secure updater and configurable success sound planned for the first v0.2 release; no public updater feed or updater-enabled release exists yet. Security reports about the released application, updater or audio trust boundaries, source, build process, protected release workflow, or repository configuration are welcome.

| Version | Supported |
| --- | --- |
| 0.1.x | Yes |

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
