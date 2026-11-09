# Windows ARM64 native assets

These archives are mirrored without changing their bytes. They are upstream
builds, not binaries rebuilt by this fork. SHA-256 values and file hashes live
in `assets.cmake` and `angle-files.cmake`.

- libmpv: Carapacik/libmpv-win32-video-cmake release `20261031`,
  `mpv-dev-aarch64-20261031-git-41f6a64506.7z`, mirrored byte-for-byte.
  Archive SHA-256: `497841ee27697d816ff3aa14a0e1cce0ce639b593d28b53fb4e06e4410c37df6`.
  Source: https://github.com/CKopoer/mpv/tree/41f6a645068483470267271e1d09966ca3b9f413
  Exact build materials and patches: https://github.com/Carapacik/libmpv-win32-video-cmake/tree/6b921819019b11a84554e4c65c280d2676a15dd8
  Original archive: https://github.com/Carapacik/libmpv-win32-video-cmake/releases/tag/20261031
  Build: https://github.com/Carapacik/libmpv-win32-video-cmake/actions/runs/41145159656
  The DLL embeds `-Dgl=enabled -Degl-angle=enabled -Dgpl=false` and uses the
  standard OpenGL render API. FFmpeg n9.0.2 is built with `--disable-gpl`,
  `--disable-nonfree`, and `--enable-version3`. mpv remains LGPL-2.1-or-later;
  the combined binary requires LGPL-3.0-or-later for FFmpeg and separate
  dependency licenses. Standard license texts in `licenses/` ship with the app.
  Lua, JavaScript, Vulkan, Blu-ray/DVD, VapourSynth, Rubber Band and Sixel are
  disabled in this ARM64 SDK; application playback does not use these features.
  The build targets Cortex-A76; real SQ1/8cx device playback and older CPU
  compatibility remain unverified.
  This replaces the previous `88eb9f2e73` ARM64 SDK, which disabled OpenGL and
  ANGLE despite the video plugin requiring them (BiliSail issue #100).
- ANGLE: revision `a96fca8d5ee2ca61e8de419e38cd577579281c9e`, BSD-3-Clause.
  Source: https://chromium.googlesource.com/angle/angle/+/a96fca8d5ee2ca61e8de419e38cd577579281c9e
  Build and packaging instructions: https://github.com/yorickreum/angle-libs/tree/485758dd4baf87570c2aac3cc47577a9514d3429
  Original archive: https://github.com/yorickreum/angle-libs/releases/tag/a96fca8
  This is the D3D11/OpenGL build without Vulkan. The original archive includes
  public headers, DLLs, a static library and LICENSE, but no MSVC import libraries.
  `libEGL.def` and `libGLESv2.def` record all named exports from the exact verified
  DLLs (`dumpbin /nologo /exports`). Configuration uses MSVC `lib /machine:arm64
  /def:<name>.def /out:<name>.lib` to generate import libraries. The static ANGLE
  library is not linked. Only the shared DLLs are bundled; LICENSE and this source record
  accompany the application. Upstream third-party source licenses continue to
  apply; the media-kit MIT license does not replace them.
- Vulkan Loader: no longer required or bundled for ARM64. The replacement
  libmpv DLL has no `vulkan-1.dll` import; ANGLE remains the non-Vulkan build.

Windows 11 ARM64 is the application baseline. The SDK is extracted with 7-Zip.
Both SDK extraction and application configuration require embedded `gl` and
`egl-angle` capabilities, independently of checksums and PE architecture.
Native loading and full application acceptance are separate from compilation
and archive integrity checks. No application build or ARM64 device test was
performed for the 2026-11-09 change.
