#!/bin/bash
# Copies the licence texts of every source tree into one folder, for the notices that ship with the DLL.
#
# Usage: collect-licenses.sh <src_packages directory> <output directory>
#
# Writes <output>/licenses/<tree>/<file> for COPYING*, LICENSE*, LICENCE*, NOTICE* and COPYRIGHT* files in
# each tree's top two levels, and <output>/licenses/MISSING.txt listing trees where none was found. A tree
# on that list needs a human to find its licence before a public release; the build does not guess.
set -euo pipefail

src=${1:?source directory}
out=${2:?output directory}/licenses
mkdir -p "$out"
: > "$out/MISSING.txt"

for d in "$src"/*/; do
  name=$(basename "$d")
  found=0
  while IFS= read -r -d '' f; do
    rel=${f#"$d"}
    mkdir -p "$out/$name/$(dirname "$rel")"
    cp "$f" "$out/$name/$rel"
    found=1
  done < <(find "$d" -maxdepth 2 -type f \( -iname 'COPYING*' -o -iname 'LICENSE*' -o -iname 'LICENCE*' \
      -o -iname 'NOTICE*' -o -iname 'COPYRIGHT*' \) -not -path '*/.git/*' -print0)
  [ "$found" = 1 ] || echo "$name" >> "$out/MISSING.txt"
done

echo "collect-licenses: $(find "$out" -mindepth 1 -maxdepth 1 -type d | wc -l) trees, $(wc -l < "$out/MISSING.txt") without a licence file"
