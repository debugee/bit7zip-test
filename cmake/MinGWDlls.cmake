
function(get_mingw_dll_path input_var output_var)
    set(${output_var} FALSE PARENT_SCOPE)

    execute_process(COMMAND ${CMAKE_CXX_COMPILER} "-print-file-name=${input_var}"
        OUTPUT_VARIABLE OUTPUT_LIBTEST_FILE_PATH
        RESULT_VARIABLE RESULT_LIBTEST_FILE_PATH
    )

    if(RESULT_LIBTEST_FILE_PATH)
        return()
    endif()

    string(STRIP "${OUTPUT_LIBTEST_FILE_PATH}" OUTPUT_LIBTEST_FILE_PATH)

    cmake_path(SET OUTPUT_LIBTEST_FILE_PATH
        NORMALIZE
        "${OUTPUT_LIBTEST_FILE_PATH}"
    )

    message(STATUS "Normalized ${input_var} file path: ${OUTPUT_LIBTEST_FILE_PATH}")

    if(NOT EXISTS ${OUTPUT_LIBTEST_FILE_PATH})
        return()
    endif()

    set(${output_var} "${OUTPUT_LIBTEST_FILE_PATH}" PARENT_SCOPE)
endfunction()

function(get_mingw_dlls output_var)
    set(${output_var} "" PARENT_SCOPE)

    if(NOT MINGW)
        return()
    endif()

    get_mingw_dll_path("crt1.o" MINGW_ARCH_LIB_FILE_PATH)

    if(NOT MINGW_ARCH_LIB_FILE_PATH)
        message(FATAL_ERROR "Could not find crt1.o")
    endif()

    cmake_path(GET MINGW_ARCH_LIB_FILE_PATH PARENT_PATH MINGW_ARCH_LIB_PATH) # lib path
    cmake_path(GET MINGW_ARCH_LIB_PATH PARENT_PATH MINGW_ARCH_PATH) # arch path

    file(GLOB_RECURSE MINGW_DLLS "${MINGW_ARCH_PATH}/*.dll")

    if(CMAKE_CXX_COMPILER_ID STREQUAL "GNU")
        get_mingw_dll_path("libgcc_s_seh-1.dll" MINGW_LIBEXCEPT_DLL)
        get_mingw_dll_path("libstdc++-6.dll" MINGW_LIBCXX_DLL)
    elseif(CMAKE_CXX_COMPILER_ID STREQUAL "Clang")
        foreach(MINGW_DLL ${MINGW_DLLS})
            cmake_path(GET MINGW_DLL FILENAME MINGW_DLL_NAME)

            if(MINGW_DLL_NAME STREQUAL "libunwind.dll")
                set(MINGW_LIBEXCEPT_DLL ${MINGW_DLL})
            elseif(MINGW_DLL_NAME STREQUAL "libc++.dll")
                set(MINGW_LIBCXX_DLL ${MINGW_DLL})
            endif()
        endforeach()
    endif()

    foreach(MINGW_DLL ${MINGW_DLLS})
        cmake_path(GET MINGW_DLL FILENAME MINGW_DLL_NAME)

        if(MINGW_DLL_NAME STREQUAL "libwinpthread-1.dll")
            set(MINGW_LIBWINPTHREAD_DLL ${MINGW_DLL})
        endif()
    endforeach()

    if(NOT(MINGW_LIBEXCEPT_DLL AND MINGW_LIBCXX_DLL AND MINGW_LIBWINPTHREAD_DLL))
        message(FATAL_ERROR "Could not find required MinGW DLLs")
    endif()

    set(MINGW_DLLS "")
    list(APPEND MINGW_DLLS "${MINGW_LIBEXCEPT_DLL}")
    list(APPEND MINGW_DLLS "${MINGW_LIBCXX_DLL}")
    list(APPEND MINGW_DLLS "${MINGW_LIBWINPTHREAD_DLL}")

    set(${output_var} ${MINGW_DLLS} PARENT_SCOPE)
endfunction()
