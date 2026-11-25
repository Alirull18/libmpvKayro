# KayroTV media profile for libmpv builds

Single source of truth for what any KayroTV libmpv build (Windows, macOS, Linux, iPhone/iPad) must contain. Sources: `apps/windows/KayroTv/Playback/MpvHost.cs`, `docs/KAYROTV.md` section 11 (FS2 transports), `docs/PLAN_ASTRO_MAINLINE_2026-11-19.md` (DASH + CENC ClearKey + strict User-Agent) and `docs/LIBMPV_PROVENANCE.md`, all in the KayroTV repository. Anything not confirmed is marked "to verify". No channel URLs or keys belong in this file.

Rule: when in doubt, keep it. A smaller binary is never worth a channel that stops playing.

## 1. Required on every platform

| Capability | Why / where KayroTV uses it |
| --- | --- |
| Protocols: http, https, tcp, tls, crypto | Playlist and stream fetching; HLS segment decryption (AES-128 proof is pending per KAYROTV.md FS3-FS5) |
| Protocols: hls, dash (applehttp / dash demuxers) | T1 live TV (HLS, HTTP-TS) and the Astro DASH tier |
| Protocols: rtmp, rtmps, rtsp, rtsps, rtp, udp, mms, mmsh, mmst | FS2 transports; `MpvHost` handles these schemes. rtmps/rtsp(s)/rtp/mms* are compiled in but unplayed (to verify) |
| SRT, RIST | Not present in the current Windows build (measured absent in FS0). `MpvHost.TryValidateSource` returns a "built without SRT" message. Optional addition, not required for parity |
| Demuxers: hls, dash, mpegts, mov (with CENC ClearKey via `-cenc_decryption_key`), matroska/webm, avi, flv, aac, ac3, eac3, mp3, webvtt, srt, ass | HTTP-TS and HLS live, DASH + ClearKey (86 of 86 keyed channels decrypted with ffmpeg, measured 2026-11-22), VOD containers, external and embedded subtitles. Today all FFmpeg demuxers are kept |
| Decoders: h264, hevc, mpeg2video, av1 (dav1d), vp9, vp8, aac, ac3, eac3, mp2, mp3, opus, vorbis, flac, dts, plus subtitle decoders | IPTV commonly carries MPEG-2 and MP2/AC-3/E-AC-3. Today all FFmpeg decoders are kept |
| Audio filters: acompressor, equalizer, dynaudnorm, bass, treble | Set through the `af` property by the audio controls |
| `deinterlace=auto` | Set by `MpvHost` (measured: interlaced content deinterlaced, progressive untouched) |
| Subtitles: libass (with freetype, fribidi, harfbuzz, a font provider) and the `sub-add` command | SRT, ASS, WebVTT; `sub-delay`, `sub-scale`, `sid`, `slang` |
| Screenshots: png and mjpeg encoders | `screenshot-to-file` |
| mpv API and options in use | property get/set/observe and command API, `keybind`, `script-message`, `audio-device-list` / `audio-device`, demuxer cache (`cache`, `demuxer-max-bytes`, `demuxer-max-back-bytes`, `demuxer-readahead-secs`, `stream-buffer-size`), `stream-lavf-o` / `demuxer-lavf-o`, `cookies` / `cookies-file`, `http-header-fields`, `user-agent`, `referrer`, `tls-verify`, `network-timeout`, `hwdec`, `deinterlace`, `wid` embedding, `config=no`, `load-scripts=no`, `ytdl=no`, `osc=no` |
| Strict User-Agent and per-channel headers | DASH tier needs the exact UA; headers pass through `http-header-fields`, `user-agent`, `referrer` |
| Licence | libmpv must be LGPL: `gpl=false` in mpv, no `--enable-gpl` and no `--enable-nonfree` in FFmpeg, shipped as a replaceable library, with licence texts and corresponding source (see `docs/LIBMPV_PROVENANCE.md`) |

## 2. Per-platform differences

| Platform | Status | TLS | Hardware decode | Rendering | Notes |
| --- | --- | --- | --- | --- | --- |
| Windows | Done: this repository | SChannel (FFmpeg `--enable-schannel`, curl) | d3d11va, dxva2, nvdec, amf (`hwdec` auto, d3d11va, no) | D3D11 via gpu-next / libplacebo with shaderc and spirv-cross; Vulkan kept as fallback if D3D11 init fails | `tls-ca-file` has no effect; system store is used |
| macOS | Not started | Secure Transport is deprecated; use OpenSSL (or another maintained option) for FFmpeg and curl, and verify it passes the HTTPS checklist. To verify | videotoolbox | libplacebo on Vulkan through MoltenVK, or the libmpv render API with OpenGL (deprecated on macOS). To verify which works with `wid`-style embedding | Suggested starting point: an existing LGPL-capable Apple build such as the MPVKit project, to be evaluated, not assumed |
| Linux | Not started | OpenSSL or GnuTLS | vaapi, vdpau, nvdec; keep libva and Vulkan here | Vulkan / OpenGL via libplacebo, embedding through `wid` (X11) or the render API (Wayland). To verify | A distro libmpv may be built GPL: ship our own LGPL build or use a Flatpak |
| iPhone / iPadOS | Not started | Platform-appropriate (OpenSSL or similar). To verify | videotoolbox | MoltenVK / Vulkan, or OpenGL ES (deprecated). To verify | Static or embedded-framework linking. App Store distribution and LGPL relinking obligations are a known legal grey area: an owner/lawyer decision is needed before shipping. AVPlayer cannot play DASH + ClearKey or raw MPEG-TS, RTMP or RTSP, so libmpv is still needed for parity |
| Android | Out of scope for libmpv | Media3 | MediaCodec | Media3 | KAYROTV.md: Android uses Media3, not libmpv (plays http(s) only today) |

## 3. Windows-only removals

Patch 0004 (`patch-after-lgpl/0004-slim-libmpv-for-kayrotv.patch`) and 0005 (`0005-drop-more-unused-parts-for-kayrotv.patch`) drop these. Re-evaluate each on other platforms instead of copying the list.

| Dropped | Windows reason | Other platforms |
| --- | --- | --- |
| OpenSSL, libssh (TLS via SChannel) | SChannel is built in and uses the system certificate store | SChannel does not exist elsewhere; each platform needs its own TLS |
| libva and FFmpeg `--enable-vaapi` (0005) | On Windows VA-API only works with a D3D12 VA driver that is not installed by default; mpv auto prefers d3d11va | Required on Linux |
| FFmpeg `--enable-cuvid`, `--enable-cuda-llvm` (0005) | nvdec covers NVIDIA decode; CUDA filters unused | CUDA is not relevant on macOS or iOS; on Linux nvdec is kept, cuvid optional |
| FFmpeg `--enable-libplacebo` (0005) | vf_libplacebo filter unused; mpv keeps its own libplacebo | Same |
| mpv sixel and subrandr (0005) | Terminal output and a second subtitle renderer; libass is the classic path | Same, unless a platform needs them (none planned) |
| lcms2, vapoursynth, libarchive, uchardet, Lua, JavaScript, SDL2 gamepad, OpenAL | Not used by the embedded player (`config=no`, `load-scripts=no`) | lcms2 is used by libplacebo for ICC profiles; keep it in mind if colour management is added |
| AV1 encoders, lame, libwebp, libvpx, opus, vorbis, speex, libjxl, libopenmpt, libmodplug, libaribcaption, libmysofa, libbs2b, libbluray, uavs3d | Only FFmpeg native decoders are needed; encoders are limited to png and mjpeg | Same |
| FFmpeg muxers, devices, programs, non-png/mjpeg encoders | Playback only | Same |

## 4. Never remove without testing

- Vulkan, libplacebo (in mpv), shaderc, spirv-cross: gpu-next rendering and the Vulkan fallback; needed by macOS, iOS and Linux builds.
- lcms2 (as used by libplacebo), zimg, libsoxr (resampling), libxml2 (DASH), libass with the fonts stack (freetype, fribidi, harfbuzz, fontconfig), dav1d, curl and mpv's libcurl, angle-headers, the png and mjpeg encoders.
- Hardware decode paths: d3d11va, dxva2, nvdec, nvcodec-headers, amf.
- Every FFmpeg decoder, demuxer, parser, bitstream filter, filter and protocol.
- A codec/format allow-list in FFmpeg: explicitly deferred. It would save size but may break unusual channels. Do it only with a corpus of real channels per transport and codec.

## 5. Test checklist for any new build on any platform

1. Licence: configure line shows no `--enable-gpl` / `--enable-nonfree`; mpv built with `gpl=false`; licence texts and source shipped.
2. HLS (live and VOD), HTTP-TS / MPEG-TS, HTTPS on several CDNs with TLS 1.2 and 1.3, redirects.
3. DASH with CENC ClearKey and a strict User-Agent (use a local key set; never commit keys).
4. RTMP, RTSP, UDP unicast and multicast, RTP, MMS (and rtmps / rtsps if available).
5. Codecs: H.264, HEVC, MPEG-2, AV1, VP9; audio AAC, AC-3, E-AC-3, MP2, MP3, Opus.
6. Interlaced content with `deinterlace=auto`.
7. Subtitles: SRT, ASS, WebVTT, `sub-add`, delay and scale.
8. Screenshot to file (png and jpeg).
9. Audio filters: acompressor, equalizer, dynaudnorm, bass, treble; audio device list and switching.
10. Hardware decode on the platform's path (`hwdec-current`), plus `hwdec=no` fallback.
11. Rendering path and fallback; embedding in the app window.
12. Cache and stall behaviour: `demuxer-cache-duration`, `paused-for-cache`, app stall detector and reconnect.
13. Record DLL/dylib size, SHA-256, FFmpeg configure line and `SOURCES.txt` in `docs/LIBMPV_PROVENANCE.md` terms.
