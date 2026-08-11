#!/bin/bash

set -euo pipefail

readonly repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && /bin/pwd -P)"
cd "$repository_root"

fail() {
    echo "$1" >&2
    exit 1
}

readonly model='CopyLasso/Models/CaptureHistory.swift'
readonly store='CopyLasso/Services/CaptureHistoryStore.swift'
readonly controller='CopyLasso/Settings/CaptureHistoryController.swift'
readonly workflow='CopyLasso/CaptureWorkflow/CaptureCommand.swift'
readonly settings_store='CopyLasso/Settings/AppSettingsStore.swift'
readonly settings_view='CopyLasso/SharedUI/SettingsView.swift'
readonly history_view='CopyLasso/SharedUI/CaptureHistoryView.swift'
readonly app='CopyLasso/App/CopyLassoApp.swift'
readonly contract='docs/v0.3-product-contract.md'
readonly architecture='docs/architecture/capture-history.md'

for required_file in \
    "$model" "$store" "$controller" "$workflow" "$settings_store" \
    "$settings_view" "$history_view" "$app" "$contract" "$architecture" \
    CopyLassoTests/Models/CaptureHistoryPolicyTests.swift \
    CopyLassoTests/Services/CaptureHistoryStoreTests.swift \
    CopyLassoTests/Settings/CaptureHistoryControllerTests.swift; do
    [[ -f "$required_file" ]] || fail "Missing capture-history source: $required_file"
done

for policy_contract in \
    'retentionInterval: TimeInterval = 7 * 24 * 60 * 60' \
    'maximumEntryCount = 100' \
    'maximumContentByteCount = 256 * 1_024' \
    '$0.capturedAt > cutoff'; do
    /usr/bin/grep -Fq "$policy_contract" "$model" || \
        fail "Capture-history policy is missing: $policy_contract"
done

for encryption_contract in \
    'AES.GCM.seal' \
    'AES.GCM.open' \
    'authenticating: Self.archiveHeader' \
    'kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly' \
    'kSecAttrSynchronizable as String] = false' \
    '"\(bundleIdentifier).capture-history"' \
    'archive-key-v1' \
    '.applicationSupportDirectory' \
    'permissions: 0o600' \
    'excludeFromBackup: true'; do
    if ! /usr/bin/grep -Fq "$encryption_contract" "$store" "$app"; then
        fail "Encrypted history boundary is missing: $encryption_contract"
    fi
done

crypto_files="$({ /usr/bin/grep -R -lE 'AES\.GCM|kSecAttrSynchronizable|SecItem(Add|Delete|CopyMatching)' CopyLasso || true; })"
[[ "$crypto_files" == "$store" ]] || \
    fail "Capture-history encryption and Keychain APIs must remain confined to the reviewed store."

for default_off_contract in \
    'privacy.captureHistoryEnabled' \
    'userDefaults.bool(forKey: Key.captureHistoryEnabled)' \
    'var isCaptureHistoryEnabled = false'; do
    if ! /usr/bin/grep -R -Fq "$default_off_contract" \
        "$settings_store" CopyLassoTests/TestSupport/SettingsDoubles.swift; then
        fail "Capture history must remain default off: $default_off_contract"
    fi
done

for workflow_contract in \
    'try clipboardService.writePlainText(content)' \
    'successSoundPlayer.play()' \
    'historyRecorder.record(content: content, kind: historyKind)' \
    'return .historySaveFailed'; do
    /usr/bin/grep -Fq "$workflow_contract" "$workflow" || \
        fail "Successful captures are missing their reviewed history ordering: $workflow_contract"
done

for lifecycle_contract in \
    'catch CaptureHistoryStoreError.contentTooLarge' \
    'await waitForActiveRecordings()' \
    'presentationState = isLocked ? .locked : .ready' \
    'removeAbandonedTemporaryFiles()'; do
    /usr/bin/grep -Fq "$lifecycle_contract" "$controller" "$store" || \
        fail "Capture-history lifecycle protection is missing: $lifecycle_contract"
done

clipboard_line="$(/usr/bin/grep -nF 'try clipboardService.writePlainText(content)' "$workflow" | /usr/bin/cut -d: -f1)"
sound_line="$(/usr/bin/grep -nF 'successSoundPlayer.play()' "$workflow" | /usr/bin/tail -n 1 | /usr/bin/cut -d: -f1)"
history_line="$(/usr/bin/grep -nF 'historyRecorder.record(content: content, kind: historyKind)' "$workflow" | /usr/bin/cut -d: -f1)"
if (( clipboard_line >= sound_line || sound_line >= history_line )); then
    fail "Capture history must run only after clipboard output and success sound."
fi

for ui_contract in \
    'Button("History…")' \
    'Section("Privacy")' \
    'Save Capture History' \
    'Capture History Is Off' \
    'History Is Unavailable' \
    'Clear Capture History?' \
    'Complete saved content' \
    'Delete History and Turn Off'; do
    if ! /usr/bin/grep -Fq "$ui_contract" \
        "$settings_view" "$history_view" CopyLasso/SharedUI/MenuBarMenuView.swift; then
        fail "Capture-history UI is missing: $ui_contract"
    fi
done

if /usr/bin/grep -nE \
    'URLSession|NSURLConnection|NWConnection|NWListener|^[[:space:]]*import[[:space:]]+Network|print\(|debugPrint\(|NSLog\(|os_log|Logger\(' \
    "$model" "$store" "$controller" "$history_view"; then
    fail "Capture-history code must not add networking or logging."
fi

if /usr/bin/grep -nE \
    'CGImage|NSImage|NSBitmapImageRep|pngRepresentation|jpegRepresentation|ScreenCaptureKit|Vision' \
    "$model" "$store" "$controller" "$history_view"; then
    fail "Capture history must never receive or persist screenshots or recognition observations."
fi

entitlements_json="$(/usr/bin/plutil -convert json -o - CopyLasso/CopyLasso.entitlements)" || \
    fail "CopyLasso entitlements are invalid."
if ! /usr/bin/jq -e '
    (keys | sort) == [
        "com.apple.security.app-sandbox",
        "com.apple.security.network.client",
        "com.apple.security.temporary-exception.mach-lookup.global-name"
    ]
    ' <<< "$entitlements_json" >/dev/null; then
    fail "Capture history must not widen entitlements."
fi

for test_contract in \
    'testAppendEncryptsAllEntryFieldsAndRoundTripsExactly' \
    'testWrongKeyTamperTruncationAndUnknownVersionFailClosed' \
    'testMissingKeyDoesNotOverwriteExistingArchive' \
    'testSystemFileStoreAtomicallyReplacesWithRestrictivePermissionsAndBackupExclusion' \
    'testSystemFileStoreRemovesAbandonedTemporaryArchivesOnReadWriteAndDelete' \
    'testSuccessfulTextAndCodeWriteThenPlaySoundThenRecordExactHistoryPayload' \
    'testHistoryFailureKeepsSuccessfulCopyAndSoundButReplacesSuccessFeedback' \
    'testHistoryPolicySkipKeepsOrdinarySuccessfulCopyFeedback' \
    'testUnreadableHistoryAlsoRequiresDestructiveConfirmation' \
    'testConfirmedDisableWaitsForAnAcceptedRecordThenDeletesIt' \
    'testFailedConfirmedDisableRestoresConsentAndAcceptsLaterRecords' \
    'testScheduledExpirationPreservesLockedPresentationUntilExplicitReload' \
    'testCopyWritesExactlyOncePlaysSoundShowsTypedFeedbackAndDoesNotRecord' \
    'testOpeningHistoryInvalidatesAnOlderLaunchLoad' \
    'testHistoryEmptyState' \
    'testHistoryUnreadableStateFailsClosed' \
    'testHistoryCopyAndDeleteRemainNonrecursive' \
    'testHistoryConfirmedClearLeavesHistoryEnabledAndEmpty' \
    'testSystemHistoryStorePersistsSyntheticCodeAcrossRelaunch'; do
    /usr/bin/grep -R -Fq "$test_contract" CopyLassoTests CopyLassoUITests || \
        fail "Capture-history coverage is missing: $test_contract"
done

for documentation_contract in \
    '0.2.2 remains the latest public release' \
    'Save Capture History' \
    'seven days' \
    '100 entries' \
    '256 KiB' \
    'APFS snapshots' \
    'archive-key-v1'; do
    if ! /usr/bin/grep -R -Fq "$documentation_contract" \
        README.md PRIVACY.md SECURITY.md CHANGELOG.md CONTRIBUTING.md \
        "$contract" "$architecture" docs/security-and-privacy-review.md docs/testing.md; then
        fail "Capture-history documentation is missing: $documentation_contract"
    fi
done

for coverage_contract in \
    'CaptureHistory.swift|8000' \
    'CaptureHistoryController.swift|7500' \
    'CaptureHistoryStore.swift|6500'; do
    /usr/bin/grep -Fq "$coverage_contract" scripts/audit-coverage.sh || \
        fail "Capture-history behavioral coverage floor is missing: $coverage_contract"
done

if ! /usr/bin/grep -Fq 'COPYLASSO_RELEASE_VERSION = 0.2.2' Configuration/ReleaseMetadata.xcconfig || \
    ! /usr/bin/grep -Fq 'COPYLASSO_RELEASE_BUILD = 5' Configuration/ReleaseMetadata.xcconfig; then
    fail "G52 must not change version 0.2.2 (5)."
fi

echo "Capture-history privacy and security audit passed."
