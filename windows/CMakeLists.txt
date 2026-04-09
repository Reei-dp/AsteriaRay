# Project-level configuration.
cmake_minimum_required(VERSION 3.14)
project(asteriaray LANGUAGES CXX)

# The name of the executable created for the application. Change this to change
# the on-disk name of your application.
set(BINARY_NAME "asteriaray")

# Explicitly opt in to modern CMake behaviors to avoid warnings with recent
# versions of CMake.
cmake_policy(VERSION 3.14...3.25)

# Define build configuration option.
get_property(IS_MULTICONFIG GLOBAL PROPERTY GENERATOR_IS_MULTI_CONFIG)
if(IS_MULTICONFIG)
  set(CMAKE_CONFIGURATION_TYPES "Debug;Profile;Release"
    CACHE STRING "" FORCE)
else()
  if(NOT CMAKE_BUILD_TYPE AND NOT CMAKE_CONFIGURATION_TYPES)
    set(CMAKE_BUILD_TYPE "Debug" CACHE
      STRING "Flutter build mode" FORCE)
    set_property(CACHE CMAKE_BUILD_TYPE PROPERTY STRINGS
      "Debug" "Profile" "Release")
  endif()
endif()
# Define settings for the Profile build mode.
set(CMAKE_EXE_LINKER_FLAGS_PROFILE "${CMAKE_EXE_LINKER_FLAGS_RELEASE}")
set(CMAKE_SHARED_LINKER_FLAGS_PROFILE "${CMAKE_SHARED_LINKER_FLAGS_RELEASE}")
set(CMAKE_C_FLAGS_PROFILE "${CMAKE_C_FLAGS_RELEASE}")
set(CMAKE_CXX_FLAGS_PROFILE "${CMAKE_CXX_FLAGS_RELEASE}")

# Use Unicode for all projects.
add_definitions(-DUNICODE -D_UNICODE)

# Compilation settings that should be applied to most targets.
#
# Be cautious about adding new options here, as plugins use this function by
# default. In most cases, you should add new options to specific targets instead
# of modifying this function.
function(APPLY_STANDARD_SETTINGS TARGET)
  target_compile_features(${TARGET} PUBLIC cxx_std_17)
  target_compile_options(${TARGET} PRIVATE /W4 /WX /wd"4100")
  target_compile_options(${TARGET} PRIVATE /EHsc)
  target_compile_definitions(${TARGET} PRIVATE "_HAS_EXCEPTIONS=0")
  target_compile_definitions(${TARGET} PRIVATE "$<$<CONFIG:Debug>:_DEBUG>")
endfunction()

# Flutter library and tool build rules.
set(FLUTTER_MANAGED_DIR "${CMAKE_CURRENT_SOURCE_DIR}/flutter")
add_subdirectory(${FLUTTER_MANAGED_DIR})

# Application build; see runner/CMakeLists.txt.
add_subdirectory("runner")


# Generated plugin build rules, which manage building the plugins and adding
# them to the application.
include(flutter/generated_plugins.cmake)


# === Installation ===
# Support files are copied into place next to the executable, so that it can
# run in place. This is done instead of making a separate bundle (as on Linux)
# so that building and running from within Visual Studio will work.
set(BUILD_BUNDLE_DIR "$<TARGET_FILE_DIR:${BINARY_NAME}>")
# Make the "install" step default, as it's required to run.
set(CMAKE_VS_INCLUDE_INSTALL_TO_DEFAULT_BUILD 1)
if(CMAKE_INSTALL_PREFIX_INITIALIZED_TO_DEFAULT)
  set(CMAKE_INSTALL_PREFIX "${BUILD_BUNDLE_DIR}" CACHE PATH "..." FORCE)
endif()

set(INSTALL_BUNDLE_DATA_DIR "${CMAKE_INSTALL_PREFIX}/data")
set(INSTALL_BUNDLE_LIB_DIR "${CMAKE_INSTALL_PREFIX}")

install(TARGETS ${BINARY_NAME} RUNTIME DESTINATION "${CMAKE_INSTALL_PREFIX}"
  COMPONENT Runtime)

install(FILES "${FLUTTER_ICU_DATA_FILE}" DESTINATION "${INSTALL_BUNDLE_DATA_DIR}"
  COMPONENT Runtime)

install(FILES "${FLUTTER_LIBRARY}" DESTINATION "${INSTALL_BUNDLE_LIB_DIR}"
  COMPONENT Runtime)

if(PLUGIN_BUNDLED_LIBRARIES)
  install(FILES "${PLUGIN_BUNDLED_LIBRARIES}"
    DESTINATION "${INSTALL_BUNDLE_LIB_DIR}"
    COMPONENT Runtime)
endif()

# Copy the native assets provided by the build.dart from all packages.
# If the directory is missing (no native assets), skip — otherwise install() fails (MSB3073).
set(NATIVE_ASSETS_DIR "${PROJECT_BUILD_DIR}native_assets/windows/")
if(EXISTS "${NATIVE_ASSETS_DIR}")
  install(DIRECTORY "${NATIVE_ASSETS_DIR}"
     DESTINATION "${INSTALL_BUNDLE_LIB_DIR}"
     COMPONENT Runtime)
endif()

# Fully re-copy the assets directory on each build to avoid having stale files
# from a previous install.
set(FLUTTER_ASSET_DIR_NAME "flutter_assets")
install(CODE "
  file(REMOVE_RECURSE \"${INSTALL_BUNDLE_DATA_DIR}/${FLUTTER_ASSET_DIR_NAME}\")
  " COMPONENT Runtime)
install(DIRECTORY "${PROJECT_BUILD_DIR}/${FLUTTER_ASSET_DIR_NAME}"
  DESTINATION "${INSTALL_BUNDLE_DATA_DIR}" COMPONENT Runtime)

# Optional: Xray-core + Wintun for Windows VLESS (see tools/fetch_xray_windows.ps1).
# Use copy_if_different so INSTALL does not touch the destination when bytes match — avoids
# "Permission denied" when asteriaray.exe / sidecars are still running (Windows locks open PE files).
set(WINDOWS_XRAY_DIR "${CMAKE_CURRENT_SOURCE_DIR}/xray")
if(EXISTS "${WINDOWS_XRAY_DIR}/xray.exe")
  install(CODE "
    execute_process(COMMAND \"${CMAKE_COMMAND}\" -E copy_if_different
      \"${WINDOWS_XRAY_DIR}/xray.exe\"
      \"${CMAKE_INSTALL_PREFIX}/xray.exe\"
      RESULT_VARIABLE _cr)
    if(NOT _cr EQUAL 0)
      message(WARNING \"INSTALL: could not update xray.exe (exit \${_cr}). Close apps locking the output folder or copy from windows/xray/ manually.\")
    endif()
  " COMPONENT Runtime)
endif()
if(EXISTS "${WINDOWS_XRAY_DIR}/wintun.dll")
  install(CODE "
    execute_process(COMMAND \"${CMAKE_COMMAND}\" -E copy_if_different
      \"${WINDOWS_XRAY_DIR}/wintun.dll\"
      \"${CMAKE_INSTALL_PREFIX}/wintun.dll\"
      RESULT_VARIABLE _cr)
    if(NOT _cr EQUAL 0)
      message(WARNING \"INSTALL: could not update wintun.dll (exit \${_cr}). Close apps locking the output folder.\")
    endif()
  " COMPONENT Runtime)
endif()

# Optional: AmneziaWG (amneziawg-go + awg.exe); wintun.dll can be shared with Xray (see tools/fetch_amneziawg_windows.bat).
set(WINDOWS_AMNEZIAWG_DIR "${CMAKE_CURRENT_SOURCE_DIR}/amneziawg")
if(EXISTS "${WINDOWS_AMNEZIAWG_DIR}/amneziawg-go.exe")
  install(CODE "
    execute_process(COMMAND \"${CMAKE_COMMAND}\" -E copy_if_different
      \"${WINDOWS_AMNEZIAWG_DIR}/amneziawg-go.exe\"
      \"${CMAKE_INSTALL_PREFIX}/amneziawg-go.exe\"
      RESULT_VARIABLE _cr)
    if(NOT _cr EQUAL 0)
      message(WARNING \"INSTALL: could not update amneziawg-go.exe (exit \${_cr}). Close AsteriaRay/amneziawg-go or copy from windows/amneziawg/ manually.\")
    endif()
  " COMPONENT Runtime)
endif()
if(EXISTS "${WINDOWS_AMNEZIAWG_DIR}/awg.exe")
  install(CODE "
    execute_process(COMMAND \"${CMAKE_COMMAND}\" -E copy_if_different
      \"${WINDOWS_AMNEZIAWG_DIR}/awg.exe\"
      \"${CMAKE_INSTALL_PREFIX}/awg.exe\"
      RESULT_VARIABLE _cr)
    if(NOT _cr EQUAL 0)
      message(WARNING \"INSTALL: could not update awg.exe (exit \${_cr}). Close apps locking the output folder.\")
    endif()
  " COMPONENT Runtime)
endif()

# Install the AOT library on non-Debug builds only.
install(FILES "${AOT_LIBRARY}" DESTINATION "${INSTALL_BUNDLE_DATA_DIR}"
  CONFIGURATIONS Profile;Release
  COMPONENT Runtime)
