# This file is a part of media_kit (https://github.com/media-kit/media-kit).
#
# Copyright © 2021 & onwards, Hitesh Kumar Saini <saini123hitesh@gmail.com>.
# All rights reserved.
# Use of this source code is governed by MIT license that can be found in the LICENSE file.

cmake_minimum_required(VERSION 3.10)

set(PROJECT_NAME "media_kit_video")
set(CMAKE_CXX_STANDARD 17)
project(${PROJECT_NAME} LANGUAGES CXX)

set(PLUGIN_NAME "media_kit_video_plugin")

if(MEDIA_KIT_LIBS_AVAILABLE)
  add_library(
    ${PLUGIN_NAME} SHARED
    "media_kit_video_plugin.cc"
    "texture_gl.cc"
    "texture_sw.cc"
    "video_output_manager.cc"
    "video_output.cc"
    "utils.cc"
  )

  apply_standard_settings(${PLUGIN_NAME})

  # Build and link the same libmpv that the library plugin bundles. Linking a
  # distro SDK can preload a second libmpv before Dart opens the bundled one.
  if(NOT MEDIA_KIT_LINUX_MPV OR NOT TARGET media_kit_linux_mpv)
    message(FATAL_ERROR "media_kit_video requires the matching personal Linux library plugin.")
  endif()
  add_dependencies(${PLUGIN_NAME} media_kit_linux_mpv)
  set_target_properties(${PLUGIN_NAME} PROPERTIES INSTALL_RPATH "$ORIGIN")

  # Check for epoxy headers & libraries.
  find_package(PkgConfig REQUIRED)
  pkg_check_modules(epoxy IMPORTED_TARGET epoxy)

  set_target_properties(
    ${PLUGIN_NAME} PROPERTIES
    CXX_VISIBILITY_PRESET hidden
  )

  target_compile_definitions(
    ${PLUGIN_NAME} PRIVATE
    FLUTTER_PLUGIN_IMPL
  )
  
  target_compile_options(${PLUGIN_NAME} PRIVATE "${epoxy_CFLAGS_OTHER}")

  target_include_directories(${PLUGIN_NAME} PRIVATE
    "${MEDIA_KIT_LINUX_MPV}/install/include")

  target_include_directories(
    ${PLUGIN_NAME} INTERFACE
    "${CMAKE_CURRENT_SOURCE_DIR}/include"
    "${epoxy_INCLUDE_DIRS}"
  )

  target_link_libraries(
    ${PLUGIN_NAME} PRIVATE
    flutter
    PkgConfig::GTK
    "${MEDIA_KIT_LINUX_MPV}/libmpv.so.2"
    PkgConfig::epoxy
  )
else()
  message(NOTICE "media_kit: WARNING: package:media_kit_libs_*** not found.")

  add_library(
    ${PLUGIN_NAME} SHARED
    "media_kit_video_plugin.cc"
  )

  apply_standard_settings(${PLUGIN_NAME})

  set_target_properties(
    ${PLUGIN_NAME} PROPERTIES
    CXX_VISIBILITY_PRESET hidden
  )

  target_compile_definitions(
    ${PLUGIN_NAME} PRIVATE
    FLUTTER_PLUGIN_IMPL

    # Add macro to indicate that package:media_kit_libs_*** is not available.
    "MEDIA_KIT_LIBS_NOT_FOUND=1"
  )

  target_include_directories(
    ${PLUGIN_NAME} INTERFACE
    "${CMAKE_CURRENT_SOURCE_DIR}/include"
  )

  target_link_libraries(
    ${PLUGIN_NAME} PRIVATE
    flutter
    PkgConfig::GTK
  )
endif()

set(
  media_kit_video_bundled_libraries
  ""
  PARENT_SCOPE
)
