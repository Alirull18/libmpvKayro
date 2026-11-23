#!/bin/bash
# Decides whether the FFmpeg inside libmpv is LGPL, from the build tree rather than from strings that the
# linker may have dropped from the DLL. Every input it needs must exist: a missing log fails the check.
#
# Usage: check-licence.sh <build64 directory> <libmpv-2.dll> <output directory> <accept_lgplv3: true|false>
#
# Writes into the output directory:
#   ffmpeg-configure-command.txt   the configure command the toolchain ran, one argument per line
#   ffmpeg-license.txt             the "License:" line FFmpeg's configure printed
#   mpv-meson-options.txt          the options mpv was configured with
#   ffmpeg-configure-flags.txt     configure flags still present in the DLL (informational; may be empty)
#   licence-status.txt             "lgplv2.1", "lgplv3-accepted" or "lgplv3-not-accepted"
# Exits non-zero on GPL or non-free FFmpeg, or when the evidence is missing.
set -euo pipefail

build=${1:?build directory}
dll=${2:?libmpv dll}
out=${3:?output directory}
accept_v3=${4:?accept_lgplv3}
mkdir -p "$out"

fail() { echo "::error::$1" >&2; exit 1; }
one() { # exactly one file matching the find arguments, or fail
  local found
  found=$(find "$build" "$@" -print)
  [ "$(printf '%s\n' "$found" | grep -c .)" = 1 ] || fail "expected one match for: $* (found: ${found:-none})"
  printf '%s\n' "$found"
}

cmd_script=$(one -path '*/ffmpeg-stamp/*' -name 'ffmpeg-configure-*.cmake')
out_log=$(one -path '*/ffmpeg-stamp/*' -name 'ffmpeg-configure-out.log')
mpv_log=$(one -path '*/mpv-stamp/*' -name 'mpv-configure-out.log')

# ExternalProject stores the command as a CMake list (arguments separated by ';') in a set(command ...) call.
sed -n '/^set(command /,/")$/p' "$cmd_script" | sed 's/^set(command "//; s/")$//' | tr ';' '\n' \
  > "$out/ffmpeg-configure-command.txt"
grep -q -- '/configure$' "$out/ffmpeg-configure-command.txt" || fail "no FFmpeg configure command in $cmd_script"

grep -m1 '^License:' "$out_log" > "$out/ffmpeg-license.txt" || fail "FFmpeg configure printed no License line"
sed -n '/User defined options/,/^$/p' "$mpv_log" > "$out/mpv-meson-options.txt"
[ -s "$out/mpv-meson-options.txt" ] || fail "no mpv meson options in $mpv_log"

grep -a -o -- '--[a-z0-9_-]*\(=[^ ]*\)\?' "$dll" | sort -u > "$out/ffmpeg-configure-flags.txt" || true

# Searched in the script itself too, so an argument the extraction above mis-split cannot hide a flag.
for flag in --enable-gpl --enable-nonfree; do
  if grep -qE -- "(^|;|\")$flag(;|\"|$)" "$cmd_script" "$out/ffmpeg-configure-command.txt"; then
    fail "FFmpeg was configured with $flag"
  fi
done
license=$(cut -d: -f2- "$out/ffmpeg-license.txt" | xargs)
case "$license" in
  "LGPL version 2.1 or later") status=lgplv2.1 ;;
  "LGPL version 3 or later")
    if [ "$accept_v3" = true ]; then status=lgplv3-accepted; else status=lgplv3-not-accepted; fi ;;
  *) fail "FFmpeg licence is '$license', not LGPL" ;;
esac
echo "$status" > "$out/licence-status.txt"
echo "check-licence: FFmpeg '$license' -> $status"
