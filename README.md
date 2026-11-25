# libmpv (LGPL) build for KayroTv

Builds `libmpv-2.dll` for 64-bit Windows with GitHub Actions, for use by KayroTv. The goal is a player library whose licence and source are documented, and that we can rebuild ourselves instead of depending on someone else's releases.

## What it does

`.github/workflows/libmpv-lgpl.yml` (manual run only):

1. Checks out [shinchiro/mpv-winbuild-cmake](https://github.com/shinchiro/mpv-winbuild-cmake), the build system for mpv and its libraries, at the commit you give (blank = latest).
2. Applies `patch/*.patch`, then `compile-lgpl-libmpv.patch`, which disables the GPL-only and non-free parts of FFmpeg and mpv, then `patch-after-lgpl/*.patch` (local fixes and the slim build, see below).
3. Pins every source tree (`scripts/pin-sources.sh`): the commit named in `sources.lock` if that file exists, otherwise the last commit at or before the *sources_cutoff* date, which defaults to the toolchain commit's date so the toolchain's own patches apply. `build.sh` no longer runs `ninja update`, which moved every library to its newest commit.
4. Builds with `build.sh` (GCC toolchain, x86_64, libmpv only). The whole job output is kept as `build-full.log` in the `build-logs` artifact, next to every package log.
5. **Checks the licence from the build tree** (`scripts/check-licence.sh`): FFmpeg's configure command and the `License:` line its configure printed. It fails on `--enable-gpl`, `--enable-nonfree` or a non-LGPL licence, and it fails when that evidence is missing, so it cannot pass by finding nothing. An LGPLv3 FFmpeg is recorded as `lgplv3-not-accepted` unless *accept_lgplv3* is ticked.
6. Writes `BUILD-INFO.txt` (pinned refs, cutoff, toolchain and compiler versions, hashes, link to the run), the FFmpeg configure command and licence, the mpv meson options, `PACKAGE-CONTENTS.sha256`, `host-packages.txt`, `SOURCES.txt` plus `kayro-libmpv-sources.tar.xz.part-NN` (the source of every tree), and `licenses/` (each tree's licence files, with `MISSING.txt` for trees that have none).
7. Optionally publishes all of that as a GitHub release, refused while the licence status is `lgplv3-not-accepted`. Each run gets its own tag; releases are never replaced or deleted.

## How to run it

Actions tab, **libmpv-lgpl**, **Run workflow**. Leave *sources_cutoff* blank unless you change *toolchain_ref*. Tick *accept_lgplv3* only once the owner has accepted an LGPLv3 FFmpeg, and *publish* to create a release. A cold build downloads and compiles the GCC toolchain and about sixty libraries, so expect it to take hours; the job limit is six hours.

## Slim build for KayroTV

`patch-after-lgpl/0004-slim-libmpv-for-kayrotv.patch` trims the DLL to what KayroTV uses (`MpvHost.cs` embeds mpv with `wid`, default `gpu-next` on d3d11, `config=no`, `load-scripts=no`, `ytdl=no`, `osc=no`). The job log, the step summary and `BUILD-INFO.txt` report the size of `libmpv-2.dll`.

- **Removed:** the AV1 encoders (aom, SVT-AV1; dav1d still decodes), lame, libwebp, libvpx, opus, vorbis and speex (FFmpeg decodes VP8/VP9/Opus/Vorbis natively; speex is obsolete), vapoursynth, libjxl, libopenmpt, libmodplug, libaribcaption, libmysofa, libbs2b, libbluray, uavs3d, OpenAL, lcms2 in FFmpeg and mpv, OpenSSL and libssh. In mpv: Lua and JavaScript (luajit, mujs), SDL2 gamepad, libarchive, uchardet, vapoursynth. FFmpeg encoders are limited to `png` and `mjpeg` (screenshots), and muxers, devices and programs are disabled.
- **Kept:** every FFmpeg decoder, demuxer, parser, bitstream filter, filter and protocol (restricting them is too risky), libplacebo/shaderc/spirv-cross/Vulkan headers, d3d11va, dxva2, NVDEC and AMF headers, dav1d, libass with freetype, fribidi, harfbuzz and fontconfig, libxml2 (DASH), zimg, libsoxr, libpng and libjpeg and libcurl.
- **TLS uses Windows SChannel**, in FFmpeg (`--enable-schannel`) and in curl, so OpenSSL is no longer built or linked. FFmpeg's `tls-ca-file` option no longer has any effect; the system certificate store is used. KayroTV sets `tls-ca-file` only in debug builds.

`patch-after-lgpl/0005-drop-more-unused-parts-for-kayrotv.patch` makes a few more conservative cuts, all unused by `MpvHost.cs` (default vo, `hwdec` auto, d3d11va or no):

- **Removed in 0005:** mpv sixel output (`-Dsixel=disabled`, libsixel) and subrandr (`-Dsubrandr=disabled`; libass still renders SRT, ASS and WebVTT); FFmpeg's libplacebo filter (`--enable-libplacebo`; mpv keeps its own libplacebo); FFmpeg CUDA filters (`--enable-cuda-llvm`) and the separate `*_cuvid` decoders (`--enable-cuvid`; NVDEC stays); FFmpeg VA-API (`--enable-vaapi`) and libva (Windows only).
- **Still kept:** Vulkan, libplacebo in mpv, shaderc, spirv-cross, lcms2 (libplacebo), zimg, soxr, libxml2, libass and the fonts stack, dav1d, curl, and every FFmpeg decoder, demuxer, parser, filter and protocol.

The full capability list every platform must keep (macOS, Linux, iPhone included) is in [docs/KAYROTV-MEDIA-PROFILE.md](docs/KAYROTV-MEDIA-PROFILE.md).

After every build, test the channels before shipping: HLS, DASH (including ClearKey), MPEG-TS, HTTPS (several CDNs, TLS 1.2 and 1.3), RTMP, subtitles (SRT, ASS, WebVTT), screenshots, and the audio filters (acompressor, equalizer, dynaudnorm, bass, treble) and `deinterlace=auto`.

## Licence position (read this before shipping)

- The build scripts here are MIT (see `LICENSE`, from [zhongfly/mpv-winbuild](https://github.com/zhongfly/mpv-winbuild), commit `37b83557ec1cb08a241defc77f60cb151f7b314c`).
- The output is meant to be an **LGPL** libmpv with a statically linked LGPL FFmpeg (the upstream project describes its `mpv-dev-lgpl` package as LGPLv2.1+ for libmpv and LGPLv3 for the FFmpeg inside it). The upstream author adds: "I'm not a lawyer and can't guarantee that I've disabled all LGPL-incompatible packages, use at your own risk." The same applies here.
- The flag check in step 4 catches FFmpeg's own switches only. It does not prove that every other bundled library is LGPL-compatible. Someone responsible for the licence must read `SOURCES.txt` and the licence files in the source archive before a public release.
- Ship `libmpv-2.dll` as a separate file next to the application so that users can replace it, and include the LGPL notices and a link to the matching release in the application.

## Reproducing a build

Sources are pinned by date, so running again with the same *toolchain_ref* and *sources_cutoff* builds the same commits, unless an upstream rewrites its history. To pin exactly, copy a release's `SOURCES.txt` to `sources.lock` and commit it. Not pinned: the Arch container image and its packages (versions recorded in `host-packages.txt`) and the Rust toolchain from rustup (version in `BUILD-INFO.txt`), so binaries are not expected to be byte-identical.

## Credits

Build system: shinchiro/mpv-winbuild-cmake. LGPL patch and workflow design: zhongfly/mpv-winbuild (MIT).
