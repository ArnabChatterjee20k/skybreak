#!/bin/bash
# publish.sh <tag> <target sha> <name> <notes file> <asset>...
set -e

R=arnabchatterjee20k/skybreak
tag=$1; sha=$2; name=$3; notes=$4; shift 4
id=$(gh api repos/$R/releases/tags/$tag --jq .id 2>/dev/null | grep -E "^[0-9]+$" || true)
if [ -z "$id" ]; then
  id=$(jq -n --arg t "$tag" --arg c "$sha" --arg n "$name" --rawfile b "$notes" '{tag_name:$t,target_commitish:$c,name:$n,body:$b,prerelease:true}' | gh api -X POST repos/$R/releases --input - --jq .id)
else
  jq -n --rawfile b "$notes" '{body:$b}' | gh api -X PATCH repos/$R/releases/$id --input - --jq .id >/dev/null
fi
for f in "$@"; do
  n=$(basename "$f")
  old=$(gh api repos/$R/releases/$id/assets --paginate --jq ".[] | select(.name==\"$n\") | .id")
  [ -n "$old" ] && gh api -X DELETE repos/$R/releases/assets/$old
  for i in 1 2 3 4; do
    gh api -X POST "https://uploads.github.com/repos/$R/releases/$id/assets?name=$n" -H "Content-Type: application/octet-stream" --input "$f" --jq '.name + " " + (.size|tostring)' && break || sleep $((i*5))
  done
done
gh api repos/$R/releases/$id --jq .html_url
