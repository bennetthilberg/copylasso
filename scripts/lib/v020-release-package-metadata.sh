#!/bin/bash

if [[ "${COPYLASSO_V020_RELEASE_PACKAGE_METADATA_LOADED:-}" == "1" ]]; then
    return 0
fi

readonly COPYLASSO_V020_RELEASE_PACKAGE_METADATA_LOADED=1
readonly COPYLASSO_RELEASE_VERSION="0.2.0"
readonly COPYLASSO_RELEASE_BUILD="3"
readonly COPYLASSO_RELEASE_DMG="CopyLasso-0.2.0.dmg"
readonly COPYLASSO_RELEASE_CHECKSUM="CopyLasso-0.2.0.dmg.sha256"
readonly COPYLASSO_RELEASE_DSYM="CopyLasso-0.2.0.dSYM.zip"
readonly COPYLASSO_RELEASE_VERIFICATION="CopyLasso-0.2.0-verification.zip"
readonly COPYLASSO_RELEASE_APPCAST="CopyLasso-0.2.0-appcast.xml"
