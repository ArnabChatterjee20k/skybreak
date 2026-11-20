#!/bin/bash
# Creates both look-dev pre-releases from this branch's files (needs a token allowed to create releases).
set -e
cd "$(dirname "$0")"
(cd lyra-v2 && ../publish_release.sh lookdev-lyra-v2 2bb7ae50ec3dd9a6d13ba4465a540ffb73746943 "Look-dev: Lyra voxel v2" RELEASE_NOTES.md $(ls | grep -v RELEASE_NOTES.md))
(cd weapons-v1 && ../publish_release.sh lookdev-weapons-v1 fa393ce2a08cd25b9452e2abe4c0df4b3d1b86fe "Look-dev: voxel weapons v1 (turntables)" RELEASE_NOTES.md $(ls | grep -v RELEASE_NOTES.md))
