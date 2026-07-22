#!/bin/bash

readonly COPYLASSO_LSREGISTER_DEFAULT="/System/Library/Frameworks/CoreServices.framework/Versions/Current/Frameworks/LaunchServices.framework/Versions/Current/Support/lsregister"

copylasso_launch_services_cleanup_fail() {
    echo "$1" >&2
    return 1
}

copylasso_canonical_generated_product() {
    local application="$1"
    local approved_build_root="$2"
    local canonical_root
    local canonical_application
    local relative_application
    local bundle_identifier

    case "$application" in
        /Applications/*)
            copylasso_launch_services_cleanup_fail \
                "Installed applications are never eligible for generated-product cleanup."
            return 1
            ;;
    esac

    if [[ ! -d "$approved_build_root" ]] || [[ -L "$approved_build_root" ]]; then
        copylasso_launch_services_cleanup_fail \
            "The approved build root must be a real existing directory."
        return 1
    fi
    canonical_root="$(cd "$approved_build_root" && /bin/pwd -P)"
    case "$canonical_root" in
        / | /Applications | /Applications/*)
            copylasso_launch_services_cleanup_fail \
                "Installed applications are never eligible for generated-product cleanup."
            return 1
            ;;
    esac

    if [[ ! -d "$application" ]]; then
        copylasso_launch_services_cleanup_fail \
            "The generated CopyLasso product is missing."
        return 1
    fi
    if [[ -L "$application" ]]; then
        copylasso_launch_services_cleanup_fail \
            "Generated-product symbolic links are not eligible for cleanup."
        return 1
    fi
    canonical_application="$(
        cd "$(/usr/bin/dirname "$application")" && \
            /usr/bin/printf '%s/%s\n' "$(/bin/pwd -P)" "$(/usr/bin/basename "$application")"
    )"

    case "$canonical_application" in
        /Applications/*)
            copylasso_launch_services_cleanup_fail \
                "Installed applications are never eligible for generated-product cleanup."
            return 1
            ;;
        "$canonical_root"/*) ;;
        *)
            copylasso_launch_services_cleanup_fail \
                "The generated product must remain under the approved build root."
            return 1
            ;;
    esac

    relative_application="${canonical_application#"$canonical_root"/}"
    if [[ ! "$relative_application" =~ ^Build/Products/[^/]+/CopyLasso\.app$ ]]; then
        copylasso_launch_services_cleanup_fail \
            "The generated product must be a direct Xcode build product."
        return 1
    fi

    if [[ ! -f "$canonical_application/Contents/Info.plist" ]]; then
        copylasso_launch_services_cleanup_fail \
            "The generated product Info.plist is missing."
        return 1
    fi
    bundle_identifier="$(
        /usr/bin/plutil -extract CFBundleIdentifier raw -o - \
            "$canonical_application/Contents/Info.plist" 2>/dev/null || true
    )"
    if [[ "$bundle_identifier" != "io.github.bennetthilberg.copylasso" ]]; then
        copylasso_launch_services_cleanup_fail \
            "Only a generated product with the production bundle identifier is eligible for cleanup."
        return 1
    fi

    /usr/bin/printf '%s\n' "$canonical_application"
}

assert_generated_copylasso_product() {
    copylasso_canonical_generated_product "$1" "$2" >/dev/null
}

unregister_generated_copylasso_product() {
    local application="$1"
    local approved_build_root="$2"
    local lsregister_path="${COPYLASSO_LSREGISTER_PATH:-$COPYLASSO_LSREGISTER_DEFAULT}"
    local canonical_application

    if [[ ! -e "$application" ]] && [[ ! -L "$application" ]]; then
        return 0
    fi
    canonical_application="$(
        copylasso_canonical_generated_product "$application" "$approved_build_root"
    )" || return 1

    if [[ "$lsregister_path" != /* ]] || [[ ! -x "$lsregister_path" ]] || \
        [[ -d "$lsregister_path" ]] || [[ -L "$lsregister_path" ]]; then
        copylasso_launch_services_cleanup_fail \
            "The Launch Services registration tool must be an absolute executable file."
        return 1
    fi

    "$lsregister_path" -u "$canonical_application"
}
