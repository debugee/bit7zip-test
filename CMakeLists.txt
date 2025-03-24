cmake_minimum_required(VERSION 3.30)

project(test VERSION 1.0 LANGUAGES C CXX)

list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_SOURCE_DIR}/cmake")

include(TargetArch)

target_architecture(ARCH)

if (ARCH STREQUAL "x86_64")
    set(ARCH "x64")
elseif(ARCH STREQUAL "i386")
    set(ARCH "x86")
elseif(ARCH STREQUAL "armv5" OR ARCH STREQUAL "armv6" OR ARCH STREQUAL "armv7")
    set(ARCH "arm")
endif()

if (MINGW)
    set(VCPKG_TARGET_TRIPLET "${ARCH}-mingw-dynamic")
elseif (WIN32)
    set(VCPKG_TARGET_TRIPLET "${ARCH}-windows")
elseif (APPLE)
    set(VCPKG_TARGET_TRIPLET "${ARCH}-osx-dynamic")
elseif (UNIX)
    set(VCPKG_TARGET_TRIPLET "${ARCH}-linux-dynamic")
endif()

#https://github.com/microsoft/vcpkg/discussions/32643
#set(VCPKG_INSTALL_OPTIONS "--binarysource=clear;--x-cmake-configure-debug=/tmp/vcpkg_configure_pipe\;bit7z")
#set(VCPKG_INSTALL_OPTIONS "--binarysource=clear;--x-cmake-debug=/tmp/vcpkg_configure_pipe\;bit7z")

set(VCPKG_CHAINLOAD_TOOLCHAIN_FILE "${CMAKE_CURRENT_SOURCE_DIR}/vcpkg_toolchain.cmake")
set(VCPKG_OVERLAY_TRIPLETS "${CMAKE_CURRENT_SOURCE_DIR}/overlays/triplets")
set(VCPKG_OVERLAY_PORTS "${CMAKE_CURRENT_SOURCE_DIR}/overlays/ports")
if(DEFINED ENV{VCPKG_ROOT})
    file(TO_CMAKE_PATH "$ENV{VCPKG_ROOT}" CMAKE_VCPKG_ROOT)
    #include vcpkg is nice, we can have some determine logic
    include("${CMAKE_VCPKG_ROOT}/scripts/buildsystems/vcpkg.cmake")
else()
    message(FATAL_ERROR "Environment variable VCPKG_ROOT is not set")
endif()

set(CMAKE_CXX_STANDARD 17)

set(CMAKE_CXX_STANDARD_REQUIRED ON)

add_executable(test test.cpp)

find_package(7zip CONFIG REQUIRED)

find_package(unofficial-bit7z CONFIG REQUIRED)

find_package(Iconv REQUIRED)

target_link_libraries(test PRIVATE Iconv::Iconv)

if(CMAKE_SIZEOF_VOID_P EQUAL 8)
    target_link_libraries(test PRIVATE unofficial::bit7z::bit7z64)
else()
    target_link_libraries(test PRIVATE unofficial::bit7z::bit7z)
endif()

target_compile_options(test PRIVATE
    $<$<CXX_COMPILER_ID:MSVC>:/utf-8>
)

target_link_options(test PRIVATE
    $<$<CXX_COMPILER_ID:Clang>:-Wl,--pdb=>
#    $<$<CXX_COMPILER_ID:MSVC>:/DEBUG>
)

if(CMAKE_CXX_COMPILER_VERSION VERSION_GREATER_EQUAL 14.0.0)
    target_link_options(test PRIVATE
        $<$<CXX_COMPILER_ID:GNU>:-Wl,--pdb=>
    )
    target_compile_options(test PRIVATE
        $<$<CXX_COMPILER_ID:GNU>:-gcodeview>
    )
endif()

target_compile_options(test PRIVATE
    $<$<CXX_COMPILER_ID:Clang>:-gcodeview>
    $<$<CXX_COMPILER_ID:MSVC>:/Zi>
)

if (WIN32)
    target_compile_definitions(test PRIVATE UNICODE _UNICODE)
endif()

if (MINGW)
    target_link_options(test PRIVATE
        -municode
    )
endif()

# if(CMAKE_BUILD_TYPE STREQUAL "Debug")
#     get_target_property(7ZIP_LOCATION 7zip::7zip IMPORTED_LOCATION_DEBUG)
# elseif(CMAKE_BUILD_TYPE STREQUAL "Release")
#     get_target_property(7ZIP_LOCATION 7zip::7zip IMPORTED_LOCATION_RELEASE)
# endif()
# cmake_path(GET 7ZIP_LOCATION FILENAME 7ZIP_FILENAME)

set(7ZIP_FILENAME $<TARGET_FILE_NAME:7zip::7zip>)

add_custom_command(
    OUTPUT "${CMAKE_CURRENT_BINARY_DIR}/test.h"
    COMMAND ${CMAKE_COMMAND} -D7ZIP_FILENAME=${7ZIP_FILENAME} -P "${CMAKE_CURRENT_SOURCE_DIR}/configure_test_h.cmake"
    COMMENT "Configuring test.h"
)

add_custom_target(configure_test_h ALL DEPENDS "${CMAKE_CURRENT_BINARY_DIR}/test.h" COMMENT "Configuring test")

add_dependencies(test configure_test_h)

target_include_directories(test PRIVATE "${CMAKE_CURRENT_BINARY_DIR}")

if(APPLE)
    set_target_properties(test PROPERTIES INSTALL_RPATH "@loader_path/")
elseif(UNIX)
    set_target_properties(test PROPERTIES INSTALL_RPATH "$ORIGIN/")
endif()

set(CMAKE_INSTALL_PREFIX ${CMAKE_CURRENT_BINARY_DIR}/install)

install(TARGETS test DESTINATION bin)

install(FILES $<TARGET_FILE:7zip::7zip> DESTINATION bin)

if (WIN32)
    find_file(ICONV_LIBRARY NAMES iconv-2.dll libiconv-2.dll PATH_SUFFIXES "../bin")
    if (ICONV_LIBRARY)
        install(FILES ${ICONV_LIBRARY} DESTINATION bin)
    endif()
endif()

if (MINGW)
    include(MinGWDlls)
    get_mingw_dlls(MINGW_DLLS)
    install(FILES ${MINGW_DLLS} DESTINATION bin)
endif()

if (MINGW)
    set(MINGW_POSTFIX "-mingw")
endif()

set(CPACK_GENERATOR "ZIP")

set(CPACK_PACKAGE_FILE_NAME "${PROJECT_NAME}-${PROJECT_VERSION}-${CMAKE_HOST_SYSTEM_NAME}-${CMAKE_SYSTEM_NAME}-${ARCH}${MINGW_POSTFIX}")
# set(CPACK_PACKAGE_VERSION_MAJOR "${test_VERSION_MAJOR}")
# set(CPACK_PACKAGE_VERSION_MINOR "${test_VERSION_MINOR}")
# set(CPACK_PACKAGE_VERSION_PATCH "${test_VERSION_PATCH}")

include(CPack)