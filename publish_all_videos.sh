#!/bin/bash
# Run on the owner's PC (gh logged in) to turn this branch into the lookdev-all-videos pre-release.
set -e
R=arnabchatterjee20k/skybreak
git archive --format=zip --prefix=skybreak_lookdev_videos/ HEAD characters zones README.txt -o skybreak_lookdev_videos.zip
gh release create lookdev-all-videos skybreak_lookdev_videos.zip -R $R --prerelease --target "$(git rev-parse HEAD)" \
  --title "Look-dev: all videos (characters + zones)" --notes "All look-dev videos, latest version of each character and zone. See README.txt in the zip."
