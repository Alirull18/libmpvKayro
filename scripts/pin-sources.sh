#!/bin/bash
# Pins every git source tree the toolchain downloaded, so a build does not silently follow upstream heads.
#
# Usage: pin-sources.sh <src_packages directory> <cutoff date> [lock file]
#
# For each tree that tracks an upstream branch, the commit is taken from the lock file when it names the
# tree, otherwise it is the last first-parent commit on that branch at or before the cutoff date (default:
# the toolchain commit's date, so upstream sources match the toolchain's own patches). A tree pinned by
# the toolchain to a fixed commit has no upstream branch and is left as it is.
#
# The toolchain's clean steps hard-reset each tree to its upstream ref (@{u}), so the pin moves that
# remote-tracking ref as well as HEAD; a later fullclean then lands on the pin, not on the newest commit.
# Nothing may run `git fetch` in these trees afterwards (build.sh no longer runs `ninja update`).
#
# The lock file uses the SOURCES.txt format a previous run wrote ("name | remote | commit"); copying a
# release's SOURCES.txt to sources.lock rebuilds exactly those sources.
set -euo pipefail

src=${1:?source directory}
cutoff=${2:?cutoff date}
lock=${3:-}

declare -A locked=()
if [ -n "$lock" ] && [ -f "$lock" ]; then
  while IFS='|' read -r name _ sha; do
    name=$(echo "$name" | xargs); sha=$(echo "$sha" | xargs)
    [[ -z "$name" || "$name" == \#* || ! "$sha" =~ ^[0-9a-f]{40}$ ]] && continue
    locked[$name]=$sha
  done < "$lock"
  echo "pin-sources: ${#locked[@]} trees named in $lock"
fi

pinned=0; skipped=0
for d in "$src"/*/; do
  name=$(basename "$d")
  [ -e "$d/.git" ] || continue
  upstream=$(git -C "$d" rev-parse --symbolic-full-name '@{u}' 2>/dev/null || true)
  if [ -z "$upstream" ]; then
    echo "pin-sources: $name has no upstream branch (fixed by the toolchain), left at $(git -C "$d" rev-parse HEAD)"
    skipped=$((skipped + 1))
    continue
  fi
  if [ "$(git -C "$d" rev-parse --is-shallow-repository)" = true ]; then
    git -C "$d" fetch --unshallow --filter=tree:0 --no-recurse-submodules
  fi
  if [ -n "${locked[$name]:-}" ]; then
    target=${locked[$name]}
    git -C "$d" cat-file -e "$target^{commit}" 2>/dev/null || git -C "$d" fetch --filter=tree:0 origin "$target"
  else
    target=$(git -C "$d" rev-list -1 --first-parent --before="$cutoff" "$upstream")
  fi
  if [ -z "$target" ]; then
    echo "::error::pin-sources: $name has no commit at or before $cutoff"
    exit 1
  fi
  git -C "$d" am --abort 2>/dev/null || true
  git -C "$d" update-ref "$upstream" "$target"
  git -C "$d" reset --hard -q "$target"
  if [ -f "$d/.gitmodules" ] && [ -n "$(git -C "$d" submodule status --recursive 2>/dev/null)" ]; then
    git -C "$d" submodule update --init --recursive --force
  fi
  echo "pin-sources: $name -> $target"
  pinned=$((pinned + 1))
done
echo "pin-sources: pinned $pinned trees, $skipped fixed by the toolchain, cutoff $cutoff"
