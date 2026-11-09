# One manifest for preparation, compilation and bundling. Standard OpenGL render
# API only: never combine this SDK with a DXGI render extension/header.
set(MEDIA_KIT_MPV_ARCHIVE "bilisail-libmpv-windows-x64-afd6da8843.zip")
set(MEDIA_KIT_MPV_URL "https://github.com/CKopoer/media-kit/releases/download/native-windows-hwdec-edges-2026-11-07/bilisail-libmpv-windows-x64-afd6da8843.zip")
set(MEDIA_KIT_MPV_SHA256 "6739acd7529400cc877ea84e417714bf043769ef088cd1b248d3de2467417ced")
set(MEDIA_KIT_MPV_FILES
  "libmpv-2.dll"
  "libmpv.dll.a"
  "include/mpv/client.h"
  "include/mpv/render.h"
  "include/mpv/render_gl.h"
  "include/mpv/stream_cb.h"
  "LICENSE.LGPL"
  "provenance/COPYING.GPLv3"
  "provenance/COPYING.LGPLv3"
  "provenance/Copyright"
  "provenance/LICENSE.LGPL"
  "provenance/LuaJIT.commit"
  "provenance/bilisail-windows.yml"
  "provenance/build-common.sh"
  "provenance/build-mingw64-full.sh"
  "provenance/container.txt"
  "provenance/ffmpeg-config.log"
  "provenance/ffmpeg.commit"
  "provenance/intro-buildoptions.json"
  "provenance/intro-dependencies.json"
  "provenance/libsixel.commit"
  "provenance/licenses/doc/aribb24/COPYING"
  "provenance/licenses/doc/kvazaar/LICENSE"
  "provenance/licenses/doc/kvazaar/LICENSE.EXT.greatest"
  "provenance/licenses/doc/libsamplerate/license.md"
  "provenance/licenses/doc/pcre2/AUTHORS.md"
  "provenance/licenses/doc/twolame/AUTHORS"
  "provenance/licenses/doc/twolame/COPYING"
  "provenance/licenses/doc/xz/AUTHORS"
  "provenance/licenses/doc/xz/COPYING"
  "provenance/licenses/doc/xz/COPYING.0BSD"
  "provenance/licenses/doc/xz/COPYING.GPLv2"
  "provenance/licenses/doc/zimg/COPYING"
  "provenance/licenses/licenses/SDL2/LICENSE.txt"
  "provenance/licenses/pinned-sources/SOURCE.md"
  "provenance/licenses/pinned-sources/libsixel/LICENSE"
  "provenance/licenses/pinned-sources/libsixel/LICENSE.images"
  "provenance/licenses/pinned-sources/libsixel/LICENSE.mesa"
  "provenance/licenses/pinned-sources/libsixel/LICENSE.pngsuite"
  "provenance/licenses/pinned-sources/libsixel/LICENSE.pnmcolormap"
  "provenance/licenses/pinned-sources/libsixel/LICENSE.sdump"
  "provenance/licenses/pinned-sources/libsixel/LICENSE.sixel"
  "provenance/licenses/pinned-sources/libsixel/LICENSE.stb"
  "provenance/licenses/pinned-sources/luajit/COPYRIGHT"
  "provenance/licenses/pinned-sources/subrandr/LICENSE"
  "provenance/licenses/zmq/AUTHORS.txt"
  "provenance/licenses/zmq/LICENSE.txt"
  "provenance/mpv.commit"
  "provenance/repack.json"
  "provenance/subrandr.commit"
  "provenance/toolchain-share-files.txt")
set(MEDIA_KIT_MPV_HASHES
  8fa6af29a94623d7d1e16bc6db48668f321e3fc9f1eaa86a8df8d61ec57f00e3
  11aa9e8f49bfc0983b331c71c622487175caf4c164eb4fac76ba3c398d40eba0
  1acf99ee77c8c2a6f1d1993bd81bbc8a91d27fb5924e80171670e6139a4bd353
  192691941602052f00df0587f126246c48785a1cf21de68d22a92ea1908d1c55
  48662c0ed9872a14dd9e1684105c97f69f94a0414709c254c5d372adc41d2e69
  188e58b6d14383e15a5dffdc4ecebbdfbf2e412b9c099ff21b571f747a8ce32d
  72b672113d642cbb8ef5dcc76938db801983c56e50b1400ab930f1a64d6dc8d9
  8ceb4b9ee5adedde47b31e975c1d90c73ad27b6b165a1dcd80c7c545eb65b903
  da7eabb7bafdf7d3ae5e9f223aa5bdc1eece45ac569dc21b3b037520b4464768
  bfe9ee4cceabcb8ecbfadf208d04156f73d801e6a57369a5606bb8341e204a23
  72b672113d642cbb8ef5dcc76938db801983c56e50b1400ab930f1a64d6dc8d9
  18c38305f60053754a41c34d8119e19cd013d69f5ee06f7ea851b9f470acacdf
  28d3086ba03a113cb4a3bbf46728c9795d565e6affb29259cbc379bb9eeb02c8
  22391a60480d3f5c22d2b2d3a1beb9693fc2af9d778a0964f8f9b07b46b2ca17
  6af9f760b7f242784a94420c21aa80ab84847c37e4a08c27dd723693329d29a3
  7b9ce6d0462b02e15cb835a663f2ffa780c628fac1c9e03e4f01019933e57da3
  9768ddf31efcb74cb3a1d619bcea1bbac3849443690a7533097a5dadee13d2dc
  fc01bd42448f752c3da86d2300f9d11da1c580e5d42efebb47b76a08fb804e4a
  038e35c91ba324b7120e3602d2a9c17ea0e2d7f535118ad50bd9970c28f17941
  9e28a7fe7a8e52b87afad578df877589359f739bd092afd7dd75a754b2be0e5c
  c650c61e7a9d4e6d4c6345daedc964b23d394e6820938b0cdc050adadca9ad8f
  da7eabb7bafdf7d3ae5e9f223aa5bdc1eece45ac569dc21b3b037520b4464768
  3c1dc3d7f8a3d08c14f4fbe9942f45764d8a21a3296e8d83446f33fd65f21c38
  16f569c87d5ec20b7474b55ee0a8877b8f8b4dc13f9567ebe0b8fe8afdeb34d2
  9722032e4b5684f0ecd399480183a9029623636add1e9515621defaf8dbcf3ed
  b4f61b3d19ba06ed60e5f5c06c459409f424a4247cff7e432203d8b0c0236ff5
  89acea387ca97766b248e553ea68400898669b1637cfa31e4ceefff9efa3744d
  257a842724705950b07da76ce0e22ffa80ec77b3e9dfc6702522ac342409da0f
  01e6df90d71d591f4307db3f397a5a4fac93b18533f5a3862156f1a0a7dc8610
  616a3ad264ce29b8f1cb97e53037b139d406899ca8d1f799651e17bfa09830b8
  0b01625d853911cd0e2e088dcfb743261034a091bb379246cb25a14cc4c74bf1
  edaef632cbb643e4e7a221717a6c441a4c1a7c918e6e4d56debc3d8739b233f6
  7637386b5f81e8a719ca336233149005e5fa28b5e6054ea7b67de49355b0ad40
  1c040b8271b37e5076359f8fd54240e371114112924d2df81ef87c7d6a1dfdfd
  94bc677b33d524fb612f62ae201ca7298315e9368d02fe6f007669cf4d8cb3f8
  f719f01f57fec5dea2103ce3b2443b0d457bac44dcb8989f08885116bae12d18
  efdf634b089e9b4200cc31d0f491d179fedc9e9795a34f0414ac1088139ecb8d
  e420be0c89e55462371040e2150c662041fde96f8689ff78f1b2a8a90786db5a
  6bc27728bf5c78643ec2dfae80f8ed0716ceb1ab9e51a1140131063ceaf6a4e7
  6a384889a29be1f449155e38aae113b2e049d56992dea8f31bea644a526d17e9
  1d6ad1693709ae74c5331eb7eca310bd98be62a26a5f8a9b9b17c7b48da89f55
  0ca026a0d26e71c6c3c2fae5593eff1d259f3111e88a208644955dec33127432
  5a3dd8ec218a701fbd51fc4ac9cccab54a126babc315c9b60526a52c0effdcd0
  6cda3076a8c09b31bb1f90da614ea89e7ee194589626eeac613e522849604e47
  3f3d9e0024b1921b067d6f7f88deb4a60cbe7a78e76c64e3f1d7fc3b779b9d04
  fabd33db90ebe0df44b2894add49393e1185b2ec8752440071df4e1edbb612e8
  1f256ecad192880510e84ad60474eab7589218784b9a50bc7ceee34c2b91f1d5
  ca8379865a6e9c0ea01259229453448cb9169afdbc0fccd91f2f3eccf4e31e70
  d418714da1b513c92fd0cd9fb1ed37622170b18b1d4888edf90932b0661f120a
  196a7d5d0bdea931e6521c88bf299862cf2b51d71f79ff214e5f7a6e5fe8137d
  b3110705c94699a050fdcb83108954831dd4a8d1c4a8d320335df4486f6f819c)

set(MEDIA_KIT_ANGLE_ARCHIVE "ANGLE.7z")
set(MEDIA_KIT_ANGLE_URL "https://github.com/CKopoer/media-kit/releases/download/native-2026-11-07/ANGLE.7z")
set(MEDIA_KIT_ANGLE_SHA256 "cc5911bb15d596fd5a2b362613ad35b7093b427117269a7359054a65746a5f9a")
set(MEDIA_KIT_ANGLE_FILE_MANIFEST "${CMAKE_CURRENT_LIST_DIR}/angle-files.cmake")
set(MEDIA_KIT_ANGLE_IMPORT_LIBS lib/libEGL.dll.lib lib/libGLESv2.dll.lib)
set(MEDIA_KIT_ANGLE_RUNTIME_FILES d3dcompiler_47.dll libEGL.dll libGLESv2.dll
  vk_swiftshader.dll vulkan-1.dll zlib.dll)
set(MEDIA_KIT_ANGLE_ROOT "")
if(FLUTTER_TARGET_PLATFORM STREQUAL "windows-arm64")
  include("${CMAKE_CURRENT_LIST_DIR}/arm64/assets.cmake")
elseif(DEFINED FLUTTER_TARGET_PLATFORM AND NOT FLUTTER_TARGET_PLATFORM STREQUAL "windows-x64")
  message(FATAL_ERROR "Unsupported media-kit Windows architecture: ${FLUTTER_TARGET_PLATFORM}")
endif()

function(media_kit_verify_file path expected)
  if(NOT EXISTS "${path}")
    message(FATAL_ERROR "Missing media-kit native asset: ${path}")
  endif()
  file(SHA256 "${path}" actual)
  if(NOT actual STREQUAL expected)
    message(FATAL_ERROR "media-kit native SHA-256 mismatch: ${path}")
  endif()
endfunction()

function(media_kit_verify_mpv_capabilities path)
  # A loadable DLL/export table does not prove this render API was compiled in.
  # Inspect mpv's embedded build metadata without executing the target binary.
  file(STRINGS "${path}" features REGEX "^List of enabled features: " LIMIT_COUNT 1)
  foreach(feature IN ITEMS gl egl-angle)
    if(NOT features MATCHES "(^| )${feature}( |$)")
      message(FATAL_ERROR "media-kit libmpv requires ${feature} rendering support: ${path}")
    endif()
  endforeach()
endfunction()

function(media_kit_fetch_archive path url expected)
  if(NOT EXISTS "${path}")
    file(DOWNLOAD "${url}" "${path}.partial" TLS_VERIFY ON TIMEOUT 180 STATUS status)
    list(GET status 0 code)
    if(NOT code EQUAL 0)
      message(FATAL_ERROR "media-kit native download failed for ${url}: ${status}")
    endif()
    media_kit_verify_file("${path}.partial" "${expected}")
    file(RENAME "${path}.partial" "${path}")
  endif()
  media_kit_verify_file("${path}" "${expected}")
endfunction()

function(media_kit_prepare_windows_assets cache)
  file(MAKE_DIRECTORY "${cache}")
  set(assets MPV ANGLE)
  if(DEFINED MEDIA_KIT_VULKAN_ARCHIVE)
    list(APPEND assets VULKAN)
  endif()
  foreach(asset IN LISTS assets)
    media_kit_fetch_archive("${cache}/${MEDIA_KIT_${asset}_ARCHIVE}"
      "${MEDIA_KIT_${asset}_URL}" "${MEDIA_KIT_${asset}_SHA256}")
  endforeach()
endfunction()

function(media_kit_extract_windows_assets cache)
  media_kit_prepare_windows_assets("${cache}")
  set(sdk "${cache}/libmpv/${MEDIA_KIT_MPV_SHA256}")
  if(NOT EXISTS "${sdk}/libmpv-2.dll")
    file(MAKE_DIRECTORY "${sdk}")
    if(FLUTTER_TARGET_PLATFORM STREQUAL "windows-arm64")
      # This archive uses the ARM64 BCJ filter, absent from CMake's libarchive.
      find_program(MEDIA_KIT_7Z NAMES 7z.exe 7z 7zr.exe PATHS "$ENV{ProgramFiles}/7-Zip" REQUIRED)
      execute_process(COMMAND "${MEDIA_KIT_7Z}" x -y "${cache}/${MEDIA_KIT_MPV_ARCHIVE}"
        "-o${sdk}" RESULT_VARIABLE result)
    else()
      execute_process(COMMAND "${CMAKE_COMMAND}" -E tar xf "${cache}/${MEDIA_KIT_MPV_ARCHIVE}"
        WORKING_DIRECTORY "${sdk}" RESULT_VARIABLE result)
    endif()
    if(NOT result EQUAL 0)
      message(FATAL_ERROR "media-kit libmpv extraction failed")
    endif()
  endif()
  foreach(index RANGE 0 5)
    list(GET MEDIA_KIT_MPV_FILES ${index} name)
    list(GET MEDIA_KIT_MPV_HASHES ${index} expected)
    media_kit_verify_file("${sdk}/${name}" "${expected}")
  endforeach()
  media_kit_verify_mpv_capabilities("${sdk}/libmpv-2.dll")
  set(angle_archive "${cache}/ANGLE/${MEDIA_KIT_ANGLE_SHA256}")
  set(angle "${angle_archive}")
  if(MEDIA_KIT_ANGLE_ROOT)
    set(angle "${angle_archive}/${MEDIA_KIT_ANGLE_ROOT}")
  endif()
  if(NOT EXISTS "${angle}/libEGL.dll")
    file(MAKE_DIRECTORY "${angle_archive}")
    execute_process(COMMAND "${CMAKE_COMMAND}" -E tar xf "${cache}/${MEDIA_KIT_ANGLE_ARCHIVE}"
      WORKING_DIRECTORY "${angle_archive}" RESULT_VARIABLE result)
    if(NOT result EQUAL 0)
      message(FATAL_ERROR "media-kit ANGLE extraction failed")
    endif()
  endif()
  include("${MEDIA_KIT_ANGLE_FILE_MANIFEST}")
  list(LENGTH MEDIA_KIT_ANGLE_FILES count)
  math(EXPR last "${count} - 1")
  foreach(index RANGE 0 ${last})
    list(GET MEDIA_KIT_ANGLE_FILES ${index} name)
    list(GET MEDIA_KIT_ANGLE_HASHES ${index} expected)
    media_kit_verify_file("${angle}/${name}" "${expected}")
  endforeach()
  set(MEDIA_KIT_MPV_SDK "${sdk}" CACHE INTERNAL "Verified libmpv SDK" FORCE)
  set(MEDIA_KIT_ANGLE_SDK "${angle}" CACHE INTERNAL "Verified ANGLE SDK" FORCE)
  set(MEDIA_KIT_ANGLE_IMPORT_LIBS ${MEDIA_KIT_ANGLE_IMPORT_LIBS} CACHE INTERNAL "Verified ANGLE import library paths" FORCE)
  if(DEFINED MEDIA_KIT_VULKAN_ARCHIVE)
    set(vulkan "${cache}/Vulkan/${MEDIA_KIT_VULKAN_SHA256}")
    if(NOT EXISTS "${vulkan}/clangarm64/bin/vulkan-1.dll")
      file(MAKE_DIRECTORY "${vulkan}")
      execute_process(COMMAND "${CMAKE_COMMAND}" -E tar xf "${cache}/${MEDIA_KIT_VULKAN_ARCHIVE}"
        WORKING_DIRECTORY "${vulkan}" RESULT_VARIABLE result)
      if(NOT result EQUAL 0)
        message(FATAL_ERROR "media-kit Vulkan loader extraction failed")
      endif()
    endif()
    media_kit_verify_file("${vulkan}/clangarm64/bin/vulkan-1.dll"
      "664e7dad1ad21ae26cfbfaf467b6ff1fdc1d73a7f82af62d48c90920a6a35d85")
    media_kit_verify_file("${vulkan}/clangarm64/share/licenses/vulkan-loader/LICENSE"
      "43c0a37e6a0fa7ff3c843b3ec5a4fac84b712558ddac103fbd4c1649662a9ece")
    set(MEDIA_KIT_VULKAN_SDK "${vulkan}/clangarm64" CACHE INTERNAL "Verified ARM64 Vulkan loader" FORCE)
  endif()
endfunction()

if(DEFINED MEDIA_KIT_ASSET_CACHE)
  media_kit_extract_windows_assets("${MEDIA_KIT_ASSET_CACHE}")
endif()
