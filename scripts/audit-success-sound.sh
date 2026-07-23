#!/bin/bash

set -euo pipefail

readonly repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && /bin/pwd -P)"
readonly asset="$repository_root/CopyLasso/Resources/CopyLassoSuccess.wav"
readonly generator="$repository_root/scripts/generate-success-sound.swift"
readonly service="$repository_root/CopyLasso/Services/SuccessSoundService.swift"
readonly settings_store="$repository_root/CopyLasso/Settings/AppSettingsStore.swift"
readonly settings_view="$repository_root/CopyLasso/SharedUI/SettingsView.swift"
readonly workflow="$repository_root/CopyLasso/CaptureWorkflow/CaptureCommand.swift"
readonly app_root="$repository_root/CopyLasso/App/CopyLassoApp.swift"
readonly expected_digest='32a817dc86c838b94b3803bf8ea16e469450a51a2fb63444e35d850798cae2a5'

fail() {
    echo "$1" >&2
    exit 1
}

for required_file in \
    "$asset" \
    "$generator" \
    "$service" \
    "$settings_store" \
    "$settings_view" \
    "$repository_root/CopyLassoTests/Services/SuccessSoundServiceTests.swift"; do
    [[ -f "$required_file" ]] || fail "Required success-sound file is missing: $required_file"
done

sound_assets="$({
    /usr/bin/find "$repository_root/CopyLasso" -type f \
        \( -iname '*.wav' -o -iname '*.aif' -o -iname '*.aiff' -o -iname '*.mp3' \
        -o -iname '*.m4a' \) -print
})"
if [[ "$sound_assets" != "$asset" ]]; then
    fail "CopyLasso must ship exactly the reviewed original success-sound asset."
fi

actual_digest="$(/usr/bin/shasum -a 256 "$asset" | /usr/bin/awk '{print $1}')"
if [[ "$actual_digest" != "$expected_digest" ]]; then
    fail "The success-sound asset does not match its reviewed digest."
fi

temporary_directory="$(/usr/bin/mktemp -d \
    "${TMPDIR:-/tmp}/copylasso-success-sound.XXXXXX")"
trap 'rm -rf "$temporary_directory"' EXIT
generated_asset="$temporary_directory/CopyLassoSuccess.wav"
xcrun swift "$generator" "$generated_asset"
if ! /usr/bin/cmp -s "$asset" "$generated_asset"; then
    fail "The checked-in success sound is not reproducible from its generator."
fi

audio_info="$(/usr/bin/afinfo "$asset")"
for expected_audio_property in \
    'File type ID:   WAVE' \
    'Data format:     1 ch,  44100 Hz, Int16' \
    'estimated duration: 0.180000 sec' \
    'audio packets: 7938' \
    'audio data file offset: 44'; do
    /usr/bin/grep -Fq "$expected_audio_property" <<< "$audio_info" || \
        fail "The success sound has an unexpected format: $expected_audio_property"
done

nssound_files="$({
    /usr/bin/grep -R -lE '^[[:space:]]*import[[:space:]]+AppKit|NSSound' \
        "$repository_root/CopyLasso/Services/SuccessSoundService.swift" || true
})"
[[ "$nssound_files" == "$service" ]] || \
    fail "AppKit sound playback must remain confined to SuccessSoundService.swift."

all_nssound_files="$({
    /usr/bin/grep -R -l 'NSSound' "$repository_root/CopyLasso" || true
})"
[[ "$all_nssound_files" == "$service" ]] || \
    fail "NSSound must remain confined to the success-sound service."

if /usr/bin/grep -R -nE \
    'AVAudioSession|AVAudioEngine|AudioServicesPlaySystemSound|requestRecordPermission|NSMicrophoneUsageDescription|UserNotifications|UNUserNotification' \
    "$repository_root/CopyLasso" "$repository_root/Configuration"; then
    fail "Success feedback must not add recording, notification, or unrelated audio APIs."
fi

for required_source_contract in \
    "$settings_store:currentSuccessSoundPreferenceVersion = 1" \
    "$settings_store:feedback.successSoundEnabled" \
    "$settings_view:Play Sound After Copying" \
    "$settings_view:copylasso.settings.success-sound" \
    "$workflow:successSoundPlayer.play()" \
    "$app_root:successSoundPlayer: successSoundPlayer" \
    "$app_root:SystemSuccessSoundPlayer(preferences: settingsStore)" \
    "$service:NSSound(contentsOf: \$0, byReference: false)"; do
    contract_file="${required_source_contract%%:*}"
    required_text="${required_source_contract#*:}"
    /usr/bin/grep -Fq "$required_text" "$contract_file" || \
        fail "The success-sound source contract is missing: $required_text"
done

for required_documentation in \
    "$repository_root/docs/brand-assets.md:CopyLassoSuccess.wav" \
    "$repository_root/docs/brand-assets.md:32a817dc86c838b94b3803bf8ea16e469450a51a2fb63444e35d850798cae2a5" \
    "$repository_root/PRIVACY.md:Success sound playback receives no captured pixels, recognized content, or clipboard text." \
    "$repository_root/docs/testing.md:## G37 Configurable Success Sound"; do
    documentation_file="${required_documentation%%:*}"
    required_text="${required_documentation#*:}"
    /usr/bin/grep -Fq "$required_text" "$documentation_file" || \
        fail "The success-sound documentation is missing: $required_text"
done

debug_app="${COPYLASSO_SUCCESS_SOUND_DEBUG_APP:-}"
release_app="${COPYLASSO_SUCCESS_SOUND_RELEASE_APP:-}"
if [[ -n "$debug_app" || -n "$release_app" ]]; then
    [[ -n "$debug_app" && -n "$release_app" ]] || \
        fail "Built success-sound auditing requires both Debug and Release applications."
    for application in "$debug_app" "$release_app"; do
        [[ -d "$application" ]] || fail "Built application is missing: $application"
        bundled_asset="$application/Contents/Resources/CopyLassoSuccess.wav"
        [[ -f "$bundled_asset" ]] || \
            fail "Built application is missing the success-sound resource: $application"
        /usr/bin/cmp -s "$asset" "$bundled_asset" || \
            fail "Built application contains a modified success-sound resource: $application"
    done
fi

echo "CopyLasso configurable success-sound audit passed."
