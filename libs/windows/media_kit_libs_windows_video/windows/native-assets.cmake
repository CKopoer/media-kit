# One manifest for preparation, compilation and bundling. Standard OpenGL render
# API only: never combine this SDK with a DXGI render extension/header.
set(MEDIA_KIT_MPV_ARCHIVE "mpv-dev-lgpl-x86_64-20261012-git-88eb9f2e73.7z")
set(MEDIA_KIT_MPV_URL "https://github.com/CKopoer/media-kit/releases/download/native-2026-11-07/${MEDIA_KIT_MPV_ARCHIVE}")
set(MEDIA_KIT_MPV_SHA256 "d1a3f57dfb3c7f07e5456e32e9ecc9e406f6457f2560ff5801c9b37a8036f507")
set(MEDIA_KIT_MPV_FILES
  libmpv-2.dll libmpv.dll.a include/mpv/client.h include/mpv/render.h
  include/mpv/render_gl.h include/mpv/stream_cb.h)
set(MEDIA_KIT_MPV_HASHES
  222da57d12a47680df84a8d0ad06f713fbbce4da923784ddeebe9d666135e943
  bef1b89f534bc86b33135e1f04fa2d5064b9d48b5de8bc9866665bbf43def793
  1acf99ee77c8c2a6f1d1993bd81bbc8a91d27fb5924e80171670e6139a4bd353
  192691941602052f00df0587f126246c48785a1cf21de68d22a92ea1908d1c55
  48662c0ed9872a14dd9e1684105c97f69f94a0414709c254c5d372adc41d2e69
  188e58b6d14383e15a5dffdc4ecebbdfbf2e412b9c099ff21b571f747a8ce32d)

set(MEDIA_KIT_ANGLE_ARCHIVE "ANGLE.7z")
set(MEDIA_KIT_ANGLE_URL "https://github.com/CKopoer/media-kit/releases/download/native-2026-11-07/ANGLE.7z")
set(MEDIA_KIT_ANGLE_SHA256 "cc5911bb15d596fd5a2b362613ad35b7093b427117269a7359054a65746a5f9a")

function(media_kit_verify_file path expected)
  if(NOT EXISTS "${path}")
    message(FATAL_ERROR "Missing media-kit native asset: ${path}")
  endif()
  file(SHA256 "${path}" actual)
  if(NOT actual STREQUAL expected)
    message(FATAL_ERROR "media-kit native SHA-256 mismatch: ${path}")
  endif()
endfunction()

function(media_kit_fetch_archive path url expected)
  if(NOT EXISTS "${path}")
    file(DOWNLOAD "${url}" "${path}.partial" TLS_VERIFY ON TIMEOUT 180 STATUS status)
    list(GET status 0 code)
    if(NOT code EQUAL 0)
      message(FATAL_ERROR "media-kit native download failed: ${status}")
    endif()
    media_kit_verify_file("${path}.partial" "${expected}")
    file(RENAME "${path}.partial" "${path}")
  endif()
  media_kit_verify_file("${path}" "${expected}")
endfunction()

function(media_kit_prepare_windows_assets cache)
  file(MAKE_DIRECTORY "${cache}")
  foreach(asset MPV ANGLE)
    media_kit_fetch_archive("${cache}/${MEDIA_KIT_${asset}_ARCHIVE}"
      "${MEDIA_KIT_${asset}_URL}" "${MEDIA_KIT_${asset}_SHA256}")
  endforeach()
endfunction()

function(media_kit_extract_windows_assets cache)
  media_kit_prepare_windows_assets("${cache}")
  set(sdk "${cache}/libmpv/${MEDIA_KIT_MPV_SHA256}")
  if(NOT EXISTS "${sdk}/libmpv-2.dll")
    file(MAKE_DIRECTORY "${sdk}")
    execute_process(COMMAND "${CMAKE_COMMAND}" -E tar xf "${cache}/${MEDIA_KIT_MPV_ARCHIVE}"
      WORKING_DIRECTORY "${sdk}" RESULT_VARIABLE result)
    if(NOT result EQUAL 0)
      message(FATAL_ERROR "media-kit libmpv extraction failed")
    endif()
  endif()
  foreach(index RANGE 0 5)
    list(GET MEDIA_KIT_MPV_FILES ${index} name)
    list(GET MEDIA_KIT_MPV_HASHES ${index} expected)
    media_kit_verify_file("${sdk}/${name}" "${expected}")
  endforeach()
  set(angle "${cache}/ANGLE/${MEDIA_KIT_ANGLE_SHA256}")
  if(NOT EXISTS "${angle}/libEGL.dll")
    file(MAKE_DIRECTORY "${angle}")
    execute_process(COMMAND "${CMAKE_COMMAND}" -E tar xf "${cache}/${MEDIA_KIT_ANGLE_ARCHIVE}"
      WORKING_DIRECTORY "${angle}" RESULT_VARIABLE result)
    if(NOT result EQUAL 0)
      message(FATAL_ERROR "media-kit ANGLE extraction failed")
    endif()
  endif()
  include("${CMAKE_CURRENT_FUNCTION_LIST_DIR}/angle-files.cmake")
  list(LENGTH MEDIA_KIT_ANGLE_FILES count)
  math(EXPR last "${count} - 1")
  foreach(index RANGE 0 ${last})
    list(GET MEDIA_KIT_ANGLE_FILES ${index} name)
    list(GET MEDIA_KIT_ANGLE_HASHES ${index} expected)
    media_kit_verify_file("${angle}/${name}" "${expected}")
  endforeach()
  set(MEDIA_KIT_MPV_SDK "${sdk}" CACHE INTERNAL "Verified libmpv SDK" FORCE)
  set(MEDIA_KIT_ANGLE_SDK "${angle}" CACHE INTERNAL "Verified ANGLE SDK" FORCE)
endfunction()

if(DEFINED MEDIA_KIT_ASSET_CACHE)
  media_kit_extract_windows_assets("${MEDIA_KIT_ASSET_CACHE}")
endif()
