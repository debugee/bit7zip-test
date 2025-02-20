target_compile_options(${LIB_TARGET} PRIVATE
    $<$<CXX_COMPILER_ID:GNU>:-Wno-cast-function-type>
    $<$<CXX_COMPILER_ID:Clang>:-Wno-cast-function-type>
)