# This file is a part of media_kit (https://github.com/media-kit/media-kit).
#
# Copyright © 2021 & onwards, Hitesh Kumar Saini <saini123hitesh@gmail.com>.
# All rights reserved.
# Use of this source code is governed by MIT license that can be found in the LICENSE file.

cmake_minimum_required(VERSION 3.14)
if(POLICY CMP0175)
  cmake_policy(SET CMP0175 NEW)
endif()

# This option is read by the other packages which are part of package:media_kit.
option(MEDIA_KIT_LIBS_AVAILABLE "package:media_kit libraries are available." ON)

set(PROJECT_NAME "media_kit_libs_windows_video")
project(${PROJECT_NAME} LANGUAGES CXX)

# Deal with MSVC incompatiblity
add_compile_definitions(_DISABLE_CONSTEXPR_MUTEX_CONSTRUCTOR)

if(NOT FLUTTER_TARGET_PLATFORM MATCHES "^windows-(x64|arm64)$")
  message(FATAL_ERROR "Unsupported Windows architecture: ${FLUTTER_TARGET_PLATFORM}")
endif()

# Source, checksums and native ownership live with this library plugin.
include("${CMAKE_CURRENT_LIST_DIR}/native-assets.cmake")
media_kit_extract_windows_assets("${CMAKE_BINARY_DIR}")
set(LIBMPV_SRC "${MEDIA_KIT_MPV_SDK}")
set(ANGLE_SRC "${MEDIA_KIT_ANGLE_SDK}")
if(FLUTTER_TARGET_PLATFORM STREQUAL "windows-arm64")
  # The upstream archive ships DLLs but omits their MSVC import libraries.
  # Export definitions are derived from the exact hash-verified DLLs. Generate
  # target import libraries with MSVC's librarian rather than using static ANGLE.
  foreach(name libEGL libGLESv2)
    execute_process(COMMAND "${CMAKE_AR}" /nologo /machine:arm64
      "/def:${CMAKE_CURRENT_LIST_DIR}/arm64/${name}.def"
      "/out:${ANGLE_SRC}/${name}.lib" RESULT_VARIABLE result)
    if(NOT result EQUAL 0)
      message(FATAL_ERROR "Could not generate the ARM64 ${name} import library")
    endif()
  endforeach()
endif()

set(PLUGIN_NAME "media_kit_libs_windows_video_plugin")

add_library(
  ${PLUGIN_NAME} SHARED
  "include/media_kit_libs_windows_video/media_kit_libs_windows_video_plugin_c_api.h"
  "media_kit_libs_windows_video_plugin_c_api.cpp"
)

apply_standard_settings(${PLUGIN_NAME})

set_target_properties(
  ${PLUGIN_NAME}
  PROPERTIES
  CXX_VISIBILITY_PRESET
  hidden
)
target_compile_definitions(
  ${PLUGIN_NAME}
  PRIVATE
  FLUTTER_PLUGIN_IMPL
)

target_include_directories(
  ${PLUGIN_NAME} INTERFACE
  "${CMAKE_CURRENT_SOURCE_DIR}/include"
)
target_link_libraries(
  ${PLUGIN_NAME}
  PRIVATE
  flutter
  flutter_wrapper_plugin
)

set(windows_runtime "${LIBMPV_SRC}/libmpv-2.dll")
foreach(file IN LISTS MEDIA_KIT_ANGLE_RUNTIME_FILES)
  list(APPEND windows_runtime "${ANGLE_SRC}/${file}")
endforeach()
set(media_kit_libs_windows_video_bundled_libraries ${windows_runtime} PARENT_SCOPE)
if(FLUTTER_TARGET_PLATFORM STREQUAL "windows-arm64")
  install(FILES "${ANGLE_SRC}/LICENSE" DESTINATION "data/licenses/angle" COMPONENT Runtime)
  install(FILES "${CMAKE_CURRENT_LIST_DIR}/arm64/SOURCE.md" DESTINATION "data/licenses/angle" COMPONENT Runtime)
endif()

# Refuse a replaced DLL at install time as well as during configuration.
list(GET MEDIA_KIT_MPV_HASHES 0 expected_dll)
install(CODE "file(SHA256 \"${LIBMPV_SRC}/libmpv-2.dll\" actual)
  if(NOT actual STREQUAL \"${expected_dll}\")
    message(FATAL_ERROR \"media-kit libmpv changed after configuration\")
  endif()" COMPONENT Runtime)
