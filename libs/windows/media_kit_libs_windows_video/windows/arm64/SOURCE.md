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
  public headers, DLLs, a static library and LICENSE, but no MSVC import libraries.
  `libEGL.def` and `libGLESv2.def` record all named exports from the exact verified
  DLLs (`dumpbin /nologo /exports`). Configuration uses MSVC `lib /machine:arm64
  /def:<name>.def /out:<name>.lib` to generate import libraries. The static ANGLE
  library is not linked. Only the shared DLLs are bundled; LICENSE and this source record
  accompany the application. Upstream third-party source licenses continue to
  apply; the media-kit MIT license does not replace them.
- Vulkan Loader: Khronos `v1.4.357.0`, Apache-2.0, as distributed by MSYS2
  `mingw-w64-clang-aarch64-vulkan-loader-1~1.4.357.0-1-any.pkg.tar.zst`.
  Package SHA-256: `1a5e4c82fc568b83b2e2cbb1e9145d61bda15ed6e2d9f6fdfb96e674aaed49b9`.
  Source: https://github.com/KhronosGroup/Vulkan-Loader/tree/v1.4.357.0
  Build materials and original package: https://packages.msys2.org/packages/mingw-w64-clang-aarch64-vulkan-loader
  GitHub normalizes `~` to `.` in the mirrored asset filename; its bytes and
  complete SHA-256 remain unchanged.
  The original `.BUILDINFO`, `.PKGINFO` and license remain in the mirrored package.
  The loader DLL and Apache license are bundled because libmpv has a hard import
  of `vulkan-1.dll`, independently of the ANGLE/OpenGL renderer. This does not
  install a Vulkan graphics driver or claim Vulkan rendering support.

Windows 11 ARM64 is the application baseline. The mpv archive requires 7-Zip
23.01 or newer to decode its ARM64 BCJ filter; CMake's built-in libarchive cannot
extract this filter. Native loading and full application acceptance are separate
from compilation and archive integrity checks.
