# Windows ARM64 native assets

These archives are mirrored without changing their bytes. They are upstream
builds, not binaries rebuilt by this fork. SHA-256 values and file hashes live
in `assets.cmake` and `angle-files.cmake`.

- libmpv: zhongfly/mpv-winbuild release `2026-10-12-88eb9f2e73`,
  `mpv-dev-lgpl-aarch64-20261012-git-88eb9f2e73.7z`.
  Source: https://github.com/CKopoer/mpv/tree/88eb9f2e73945d8bc9c133a2f67babaa9af34680
  Build materials: https://github.com/CKopoer/mpv-winbuild
  Original archive: https://github.com/zhongfly/mpv-winbuild/releases/tag/2026-10-12-88eb9f2e73
  LGPL distribution, with the same standard OpenGL render API and public headers
  as the pinned x64 SDK. No DXGI render extension is introduced.
- ANGLE: revision `a96fca8d5ee2ca61e8de419e38cd577579281c9e`, BSD-3-Clause.
  Source: https://chromium.googlesource.com/angle/angle/+/a96fca8d5ee2ca61e8de419e38cd577579281c9e
  Build and packaging instructions: https://github.com/yorickreum/angle-libs/tree/485758dd4baf87570c2aac3cc47577a9514d3429
  Original archive: https://github.com/yorickreum/angle-libs/releases/tag/a96fca8
  This is the D3D11/OpenGL build without Vulkan. The original archive includes
  public headers, MSVC import libraries, DLLs, static libraries and LICENSE.
  Only the shared DLLs are linked and bundled; LICENSE and this source record
  accompany the application. Upstream third-party source licenses continue to
  apply; the media-kit MIT license does not replace them.

Windows 11 ARM64 is the application baseline. The mpv archive requires 7-Zip
23.01 or newer to decode its ARM64 BCJ filter; CMake's built-in libarchive cannot
extract this filter. Native loading and full application acceptance are separate
from compilation and archive integrity checks.
