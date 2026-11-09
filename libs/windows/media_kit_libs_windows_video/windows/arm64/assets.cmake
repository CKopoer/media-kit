# Byte-for-byte mirrors of the recorded upstream ARM64 archives.
set(MEDIA_KIT_MPV_ARCHIVE "mpv-dev-aarch64-20261031-git-41f6a64506.7z")
set(MEDIA_KIT_MPV_URL "https://github.com/CKopoer/media-kit/releases/download/native-windows-arm64-2026-11-07/${MEDIA_KIT_MPV_ARCHIVE}")
set(MEDIA_KIT_MPV_SHA256 "497841ee27697d816ff3aa14a0e1cce0ce639b593d28b53fb4e06e4410c37df6")
set(MEDIA_KIT_MPV_FILES
  libmpv-2.dll libmpv.dll.a include/mpv/client.h include/mpv/render.h include/mpv/render_gl.h include/mpv/stream_cb.h)
set(MEDIA_KIT_MPV_HASHES
  c7b5ab1cd0b98285ce56c96662f1e27bfa08264915554c681c12b16d6de70c11
  b98ef0f46299ad87526f6758db3e1d1e7d242aaad062b67c9ea9b74753e89002
  3c073236a09cb456c6e80587d5523c8771c32fb22ca014e0f99cc3d43905b75c
  192691941602052f00df0587f126246c48785a1cf21de68d22a92ea1908d1c55
  48662c0ed9872a14dd9e1684105c97f69f94a0414709c254c5d372adc41d2e69
  188e58b6d14383e15a5dffdc4ecebbdfbf2e412b9c099ff21b571f747a8ce32d)
set(MEDIA_KIT_ANGLE_ARCHIVE "angle-windows-arm64-a96fca8d5ee2ca61e8de419e38cd577579281c9e.tar.gz")
set(MEDIA_KIT_ANGLE_URL "https://github.com/CKopoer/media-kit/releases/download/native-windows-arm64-2026-11-07/${MEDIA_KIT_ANGLE_ARCHIVE}")
set(MEDIA_KIT_ANGLE_SHA256 "f7f122533644ec0dd1f52f0117b9fa57ceb3f69dff3359579028ff4008f74f69")
set(MEDIA_KIT_ANGLE_ROOT "angle-windows-arm64-a96fca8d5ee2ca61e8de419e38cd577579281c9e")
set(MEDIA_KIT_ANGLE_FILE_MANIFEST "${CMAKE_CURRENT_LIST_DIR}/angle-files.cmake")
set(MEDIA_KIT_ANGLE_IMPORT_LIBS libEGL.lib libGLESv2.lib)
set(MEDIA_KIT_ANGLE_RUNTIME_FILES libEGL.dll libGLESv2.dll)
