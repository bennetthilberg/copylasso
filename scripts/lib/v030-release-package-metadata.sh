#!/bin/bash

if [[ "${COPYLASSO_V030_RELEASE_PACKAGE_METADATA_LOADED:-}" == "1" ]]; then
    return 0
fi

readonly COPYLASSO_V030_RELEASE_PACKAGE_METADATA_LOADED=1
readonly COPYLASSO_RELEASE_VERSION="0.3.0"
readonly COPYLASSO_RELEASE_BUILD="6"
readonly COPYLASSO_RELEASE_DMG="CopyLasso-0.3.0.dmg"
readonly COPYLASSO_RELEASE_CHECKSUM="CopyLasso-0.3.0.dmg.sha256"
readonly COPYLASSO_RELEASE_DSYM="CopyLasso-0.3.0.dSYM.zip"
readonly COPYLASSO_RELEASE_VERIFICATION="CopyLasso-0.3.0-verification.zip"
readonly COPYLASSO_RELEASE_APPCAST="CopyLasso-0.3.0-appcast.xml"
