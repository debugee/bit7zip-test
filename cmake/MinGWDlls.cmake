
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

function(get_dll_dependencies dll_name output_dlls)
    set(${output_dlls} FALSE PARENT_SCOPE)

    if(NOT EXISTS "${dll_name}")
        return()
    endif()

    if (CMAKE_CXX_COMPILER_ID STREQUAL "MSVC")
        find_program(CMAKE_DUMPBIN dumpbin.exe REQUIRED)
        set(CMAKE_DUMPBIN_ARGS "-DEPENDENTS")
        set(CMAKE_DUMPBIN_REGEXP "[ \r\n\t]*    ([^ \r\n\t]+\.dll)\n")
    else()
        set(CMAKE_DUMPBIN_ARGS "-p")
        set(CMAKE_DUMPBIN "${CMAKE_OBJDUMP}")
        set(CMAKE_DUMPBIN_REGEXP "[ \t\r\n]+DLL Name: ([^\n]+\.dll)\n")
    endif()

    if(NOT EXISTS "${CMAKE_DUMPBIN}")
        return()
    endif()

    execute_process(COMMAND "${CMAKE_DUMPBIN}" ${CMAKE_DUMPBIN_ARGS} "${dll_name}"
        OUTPUT_VARIABLE output_var
        RESULT_VARIABLE result_var
    )

    if(result_var)
        return()
    endif()

    string(REGEX MATCHALL "${CMAKE_DUMPBIN_REGEXP}" matches_vars "${output_var}")
    foreach(match_line_var ${matches_vars})
        string(REGEX REPLACE "${CMAKE_DUMPBIN_REGEXP}" "\\1" dll_name_var "${match_line_var}")
        list(APPEND dll_names_var "${dll_name_var}")
    endforeach()

    set(${output_dlls} ${dll_names_var} PARENT_SCOPE)
endfunction()

function(get_pe_file_arch dll_name output_arch)
    set(${output_arch} FALSE PARENT_SCOPE)
    if(NOT EXISTS "${dll_name}")
        return()
    endif()

    if(NOT EXISTS "${CMAKE_OBJDUMP}")
        return()
    endif()

    execute_process(COMMAND ${CMAKE_OBJDUMP} -a "${dll_name}"
        OUTPUT_VARIABLE output_var
        RESULT_VARIABLE result_var
    )
    #objdump 32 cant work for 64 pe,so when 32 objdump do with 64 pe return FALSE
    if(result_var)
        return()
    endif()

    string(REGEX MATCH ".+file format [^\n]+-x86-64\n" match_var "${output_var}")
    if (match_var)
        set(_arch "x86_64")
    else()
        set(_arch "x86")
    endif()
    set(${output_arch} ${_arch} PARENT_SCOPE)
endfunction()

function(get_exception_dll_name output_var)
    set(${output_var} FALSE PARENT_SCOPE)
    set(_source "
    #include <iostream>
    int main(){
        try{
        std::cout << \"test\" << std::endl;
    }catch(std::exception &excep){
    }
        return 0;
    }
    ")
    string(RANDOM LENGTH 32 _file_name)
    set(_file_full_name "${CMAKE_CURRENT_BINARY_DIR}/${_file_name}")
    try_compile(_compileResultVar
        SOURCE_FROM_VAR "${_file_name}.cpp" _source
        COPY_FILE "${_file_full_name}"
        OUTPUT_VARIABLE OUTPUT)
    if (NOT _compileResultVar)
        return()
    endif()
    
    get_dll_dependencies("${_file_full_name}" import_dlls)
    foreach(dll_name ${import_dlls})
        string(REGEX MATCH "^libgcc_s_.+\.dll$" dll_name_var "${dll_name}")
        if (dll_name_var)
            set(${output_var} ${dll_name_var} PARENT_SCOPE)
            break()
        endif()
    endforeach()
    file(REMOVE "${_file_full_name}")
endfunction()

function(get_mingw_dlls output_var)
    set(${output_var} FALSE PARENT_SCOPE)
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

    # set(MINGW_LIBEXCEPT_DLL_NAME "libgcc_s_seh-1.dll")
    # if(CMAKE_SIZEOF_VOID_P EQUAL 4)
    #     set(MINGW_LIBEXCEPT_DLL_NAME "libgcc_s_sjlj-1.dll")
    # endif()
    get_exception_dll_name(MINGW_LIBEXCEPT_DLL_NAME)
    set(MINGW_LIBCXX_DLL_NAME "libstdc++-6.dll")
    set(MINGW_LIBWINPTHREAD_DLL_NAME "libwinpthread-1.dll")
    if(CMAKE_CXX_COMPILER_ID STREQUAL "Clang")
        set(MINGW_LIBEXCEPT_DLL_NAME "libunwind.dll")
        set(MINGW_LIBCXX_DLL_NAME "libc++.dll")
    endif()

    get_mingw_dll_path(${MINGW_LIBEXCEPT_DLL_NAME} MINGW_LIBEXCEPT_DLL)
    get_mingw_dll_path(${MINGW_LIBCXX_DLL_NAME} MINGW_LIBCXX_DLL)
    get_mingw_dll_path(${MINGW_LIBWINPTHREAD_DLL_NAME} MINGW_LIBWINPTHREAD_DLL)

    set(current_arch "x86")
    if (CMAKE_SIZEOF_VOID_P EQUAL 8)
        set(current_arch "x86_64")
    endif()
    foreach(MINGW_DLL ${MINGW_DLLS})
        message("DLL: ${MINGW_DLL}")
        get_pe_file_arch("${MINGW_DLL}" file_arch)
        if (current_arch STREQUAL file_arch)
            cmake_path(GET MINGW_DLL FILENAME MINGW_DLL_NAME)
            if((NOT MINGW_LIBEXCEPT_DLL) AND MINGW_DLL_NAME STREQUAL MINGW_LIBEXCEPT_DLL_NAME)
                set(MINGW_LIBEXCEPT_DLL ${MINGW_DLL})
            elseif((NOT MINGW_LIBCXX_DLL) AND MINGW_DLL_NAME STREQUAL MINGW_LIBCXX_DLL_NAME)
                set(MINGW_LIBCXX_DLL ${MINGW_DLL})
            elseif((NOT MINGW_LIBWINPTHREAD_DLL) AND MINGW_DLL_NAME STREQUAL MINGW_LIBWINPTHREAD_DLL_NAME)
                set(MINGW_LIBWINPTHREAD_DLL ${MINGW_DLL})
            endif()
        endif()
    endforeach()

    if(NOT(MINGW_LIBEXCEPT_DLL AND MINGW_LIBCXX_DLL AND MINGW_LIBWINPTHREAD_DLL))
        message(FATAL_ERROR "Could not find required MinGW DLLs")
    endif()

    set(MINGW_DLLS "")

    file(REAL_PATH "${MINGW_LIBEXCEPT_DLL}" MINGW_LIBEXCEPT_DLL)
    file(REAL_PATH "${MINGW_LIBCXX_DLL}" MINGW_LIBCXX_DLL)
    file(REAL_PATH "${MINGW_LIBWINPTHREAD_DLL}" MINGW_LIBWINPTHREAD_DLL)

    list(APPEND MINGW_DLLS "${MINGW_LIBEXCEPT_DLL}")
    list(APPEND MINGW_DLLS "${MINGW_LIBCXX_DLL}")
    list(APPEND MINGW_DLLS "${MINGW_LIBWINPTHREAD_DLL}")

    set(${output_var} ${MINGW_DLLS} PARENT_SCOPE)
endfunction()
