#!/bin/bash

if [[ "${COPYLASSO_V021_RELEASE_PACKAGE_METADATA_LOADED:-}" == "1" ]]; then
    return 0
fi

readonly COPYLASSO_V021_RELEASE_PACKAGE_METADATA_LOADED=1
readonly COPYLASSO_RELEASE_VERSION="0.2.1"
readonly COPYLASSO_RELEASE_BUILD="4"
readonly COPYLASSO_RELEASE_DMG="CopyLasso-0.2.1.dmg"
readonly COPYLASSO_RELEASE_CHECKSUM="CopyLasso-0.2.1.dmg.sha256"
readonly COPYLASSO_RELEASE_DSYM="CopyLasso-0.2.1.dSYM.zip"
readonly COPYLASSO_RELEASE_VERIFICATION="CopyLasso-0.2.1-verification.zip"
readonly COPYLASSO_RELEASE_APPCAST="CopyLasso-0.2.1-appcast.xml"
