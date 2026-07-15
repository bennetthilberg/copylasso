# Developer ID Signing and Notarization

This document records CopyLasso's non-secret local signing setup. The Developer ID archive,
exported application, notarization records, and credentials are release inputs rather than source
artifacts and never belong in the repository.

## Required Account and Certificate

The Account Holder creates one **Developer ID Application** certificate through Xcode's Accounts
settings. The certificate and paired private key remain in the login Keychain. CopyLasso does not
use an installer package, so a Developer ID Installer certificate is unnecessary.

Confirm availability without printing certificate subjects, fingerprints, team identifiers, or
account details. A valid identity count of one or more is sufficient for ordinary setup readback.
Do not export the private key during this goal.

## Notarization Credential Profile

CopyLasso uses the local Keychain profile **copylasso-notary**. Create it interactively so the Apple
Account, configured team identifier, and app-specific password never appear in command history or
process arguments:

~~~sh
xcrun notarytool store-credentials copylasso-notary
~~~

Accept the default validation and do not enable Keychain synchronization. Do not print or commit
the Apple Account, team identifier, app-specific password, certificate fingerprint, private key,
or profile contents. Future protected CI credentials are a separate G28 concern.

## Archive and Export

Start from a clean, pushed, reviewed commit. Keep the archive outside the repository in a directory
whose final component is the full source commit. Use the shared scheme, Release configuration, and
generic macOS destination:

~~~sh
xcodebuild archive \
  -project CopyLasso.xcodeproj \
  -scheme CopyLasso \
  -configuration Release \
  -destination 'generic/platform=macOS' \
  -archivePath "$G26_OUTPUT/CopyLasso.xcarchive" \
  -allowProvisioningUpdates

xcodebuild -exportArchive \
  -archivePath "$G26_OUTPUT/CopyLasso.xcarchive" \
  -exportOptionsPlist Configuration/DeveloperIDExportOptions.plist \
  -exportPath "$G26_OUTPUT/export" \
  -allowProvisioningUpdates
~~~

Configuration/DeveloperIDExportOptions.plist selects Developer ID distribution while omitting the
team identifier and all credentials. Before submission, verify the exported application:

~~~sh
./scripts/verify-developer-id-app.sh --pre-notarization \
  "$G26_OUTPUT/export/CopyLasso.app"
~~~

## Submit, Staple, and Validate

The notary service accepts a ZIP container rather than a bare application bundle:

~~~sh
/usr/bin/ditto -c -k --keepParent \
  "$G26_OUTPUT/export/CopyLasso.app" \
  "$G26_OUTPUT/CopyLasso-notarization.zip"

xcrun notarytool submit "$G26_OUTPUT/CopyLasso-notarization.zip" \
  --keychain-profile copylasso-notary \
  --wait \
  --output-format json

xcrun stapler staple "$G26_OUTPUT/export/CopyLasso.app"
./scripts/verify-developer-id-app.sh --post-notarization \
  "$G26_OUTPUT/export/CopyLasso.app"
~~~

Store the submission result and diagnostic log beside the external archive. Evidence may record the
submission identifier and accepted status, but it must redact account and team details. Never print
the complete signing or notarization log into public CI output.

## Renewal and Failure Recovery

- If the Developer ID certificate is missing, expired, revoked, or lacks its private key, stop and
  repair the identity through the Account Holder. Never fall back to Apple Development or ad-hoc
  signing for a release export.
- If credential validation fails, replace only the **copylasso-notary** Keychain item after
  confirming the intended account and team. Do not delete unrelated Keychain items.
- If notarization is rejected, inspect the external log, fix the reported source or signing issue,
  create a new commit, and rebuild from the beginning. Never staple or promote a rejected artifact.
- Any tracked commit after archive creation invalidates the archive. Repeat archive, export,
  submission, stapling, and verification at the new exact head.

## G27 Handoff

Preserve the exact accepted and stapled CopyLasso.app, its archive, dSYM, source commit, and
notarization submission record outside the repository. G27 must build its DMG from this qualified
application without rebuilding or re-signing it.
