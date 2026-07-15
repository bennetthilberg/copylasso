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

CopyLasso uses a **Team API key** with the **Developer role** and stores its credentials in the local
Keychain profile **copylasso-notary**. An Individual API key cannot authenticate `notarytool`. Create
and download the Team key once in App Store Connect, keep the downloaded private key outside the
repository, and restrict the file before importing it. In a local Bash session, read the key and
issuer identifiers without adding them to command history:

~~~sh
read -r -p 'Downloaded private-key path: ' COPYLASSO_NOTARY_KEY
chmod 600 "$COPYLASSO_NOTARY_KEY"
read -r -s -p 'App Store Connect key ID: ' COPYLASSO_NOTARY_KEY_ID; echo
read -r -s -p 'App Store Connect issuer ID: ' COPYLASSO_NOTARY_ISSUER_ID; echo

xcrun notarytool store-credentials copylasso-notary \
  --key "$COPYLASSO_NOTARY_KEY" \
  --key-id "$COPYLASSO_NOTARY_KEY_ID" \
  --issuer "$COPYLASSO_NOTARY_ISSUER_ID" \
  --keychain "$HOME/Library/Keychains/login.keychain-db"

xcrun notarytool history \
  --keychain-profile copylasso-notary \
  --keychain "$HOME/Library/Keychains/login.keychain-db"

/bin/rm -f "$COPYLASSO_NOTARY_KEY"
unset COPYLASSO_NOTARY_KEY COPYLASSO_NOTARY_KEY_ID COPYLASSO_NOTARY_ISSUER_ID
~~~

The profile must validate before use. Once validation succeeds, remove the downloaded private-key
file; the credentials remain in the nonsynchronized login Keychain profile. Do not print or commit
the account, key identifier, issuer identifier, certificate fingerprint, private key, or profile
contents. Future protected CI credentials are a separate G28 concern.

## Archive and Export

Start from a clean, pushed, reviewed commit. Keep the archive outside the repository in a directory
whose final component is the full source commit. Use the shared scheme, Release configuration, and
generic macOS destination. In the same local Bash session, read the expected release team without
printing or recording the identifier, and keep it only in the process environment for artifact
verification:

~~~sh
read -r -s -p 'Expected release Team ID: ' COPYLASSO_EXPECTED_TEAM_ID; echo
export COPYLASSO_EXPECTED_TEAM_ID

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
  --keychain "$HOME/Library/Keychains/login.keychain-db" \
  --wait \
  --output-format json

xcrun stapler staple "$G26_OUTPUT/export/CopyLasso.app"
./scripts/verify-developer-id-app.sh --post-notarization \
  "$G26_OUTPUT/export/CopyLasso.app"

unset COPYLASSO_EXPECTED_TEAM_ID
~~~

Store the submission result and diagnostic log beside the external archive. Evidence may record the
submission identifier and accepted status, but it must redact account and team details. Never print
the complete signing or notarization log into public CI output. The verifier fails unless every
signature slice matches `COPYLASSO_EXPECTED_TEAM_ID`; it never records that value.

## Renewal and Failure Recovery

- If the Developer ID certificate is missing, expired, revoked, or lacks its private key, stop and
  repair the identity through the Account Holder. Never fall back to Apple Development or ad-hoc
  signing for a release export.
- If credential validation fails, confirm that the Team API key remains active and has the intended
  access. Replace only the **copylasso-notary** Keychain item; revoke and regenerate the API key only
  if it is compromised or no longer usable. Do not delete unrelated Keychain items.
- If notarization is rejected, inspect the external log, fix the reported source or signing issue,
  create a new commit, and rebuild from the beginning. Never staple or promote a rejected artifact.
- Any tracked commit after archive creation invalidates the archive. Repeat archive, export,
  submission, stapling, and verification at the new exact head.

## G27 Handoff

Preserve the exact accepted and stapled CopyLasso.app, its archive, dSYM, source commit, and
notarization submission record outside the repository. G27 must build its DMG from this qualified
application without rebuilding or re-signing it.
