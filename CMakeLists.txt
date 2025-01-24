cmake_minimum_required(VERSION 3.30)

set(VCPKG_OVERLAY_PORTS "${CMAKE_CURRENT_SOURCE_DIR}/overlays")
if(DEFINED ENV{VCPKG_ROOT})
    file(TO_CMAKE_PATH "$ENV{VCPKG_ROOT}" VCPKG_ROOT_LINUX)
    set(CMAKE_TOOLCHAIN_FILE "${VCPKG_ROOT_LINUX}/scripts/buildsystems/vcpkg.cmake")
else()
    message(FATAL_ERROR "Environment variable VCPKG_ROOT is not set")
endif()

set(CMAKE_CXX_STANDARD 17)

set(CMAKE_CXX_STANDARD_REQUIRED ON)

project(test VERSION 1.0)

add_executable(test test.cpp)

if (MINGW)
    target_link_libraries(test PRIVATE libwinpthread.a libc++.a libunwind.a)
endif()

find_package(7zip CONFIG REQUIRED)

find_package(unofficial-bit7z CONFIG REQUIRED)

target_link_libraries(test PRIVATE unofficial::bit7z::bit7z64)

target_link_options(test PRIVATE
    $<$<CXX_COMPILER_ID:GNU>:-Wl,--pdb=>
    $<$<CXX_COMPILER_ID:Clang>:-Wl,--pdb=>
#    $<$<CXX_COMPILER_ID:MSVC>:/DEBUG>
)

target_compile_options(test PRIVATE
    $<$<CXX_COMPILER_ID:GNU>:-gcodeview>
    $<$<CXX_COMPILER_ID:Clang>:-gcodeview>
    $<$<CXX_COMPILER_ID:MSVC>:/Zi>
)

if(CMAKE_BUILD_TYPE STREQUAL "Debug")
    get_target_property(7ZIP_LOCATION 7zip::7zip IMPORTED_LOCATION_DEBUG)
elseif(CMAKE_BUILD_TYPE STREQUAL "Release")
    get_target_property(7ZIP_LOCATION 7zip::7zip IMPORTED_LOCATION_RELEASE)
endif()
cmake_path(GET 7ZIP_LOCATION FILENAME 7ZIP_FILENAME)

configure_file(test.h.in test.h @ONLY)

target_include_directories(test PRIVATE "${CMAKE_CURRENT_BINARY_DIR}")

if(APPLE)
    set_target_properties(test PROPERTIES INSTALL_RPATH "@loader_path/")
elseif(UNIX)
    set_target_properties(test PROPERTIES INSTALL_RPATH "$ORIGIN/")
endif()

set(CMAKE_INSTALL_PREFIX install)

install(TARGETS test DESTINATION bin)

install(FILES "${7ZIP_LOCATION}" DESTINATION bin)

include(CPack)

set(CPACK_GENERATOR "ZIP")
set(CPACK_PACKAGE_FILE_NAME "test-${test_VERSION}")
set(CPACK_PACKAGE_VERSION_MAJOR "${test_VERSION_MAJOR}")
set(CPACK_PACKAGE_VERSION_MINOR "${test_VERSION_MINOR}")
set(CPACK_PACKAGE_VERSION_PATCH "${test_VERSION_PATCH}")


