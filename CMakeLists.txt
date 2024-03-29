﻿# see https://github.com/chromium/chromium/blob/9db0b5162b8648833c3a6b1af044cebd9d7d3855/base/BUILD.gn

cmake_minimum_required(VERSION 3.4)

# project() must be before checks, see https://stackoverflow.com/a/26437667/10904212
set(PROJECT_NAME "chromium_icu")
set(PROJECT_VERSION 1.0.0.1)
project(${PROJECT_NAME}
  VERSION ${PROJECT_VERSION}
  LANGUAGES CXX C)

set(STATIC_LIB_NAME ${PROJECT_NAME}-static)

option(COMPILE_WITH_LLVM_TOOLS
  "Enable clang from llvm_tools (conan package)" OFF)

# see https://github.com/Ericsson/codechecker/blob/master/tools/report-converter/README.md#undefined-behaviour-sanitizer
# NOTE: Compile with -g and -fno-omit-frame-pointer
# to get proper debug information in your binary.
# NOTE: Run your program with environment variable UBSAN_OPTIONS=print_stacktrace=1.
# see https://github.com/google/sanitizers/wiki/SanitizerCommonFlags
option(ENABLE_UBSAN
  "Enable Undefined Behaviour Sanitizer" OFF)

# see https://github.com/google/sanitizers/wiki/AddressSanitizerLeakSanitizer
# see https://github.com/Ericsson/codechecker/blob/master/tools/report-converter/README.md#address-sanitizer
# NOTE: Compile with -g and -fno-omit-frame-pointer
# to get proper debug information in your binary.
# NOTE: use ASAN_OPTIONS=detect_leaks=1 LSAN_OPTIONS=suppressions=suppr.txt
# NOTE: You need the ASAN_OPTIONS=symbolize=1
# to turn on resolving addresses in object code
# to source code line numbers and filenames.
# This option is implicit for Clang but it won't do any harm.
# see https://github.com/google/sanitizers/wiki/SanitizerCommonFlags
option(ENABLE_ASAN
  "Enable Address Sanitizer" OFF)

# see https://github.com/Ericsson/codechecker/blob/master/tools/report-converter/README.md#memory-sanitizer
# NOTE: Compile with -g and -fno-omit-frame-pointer
# to get proper debug information in your binary.
option(ENABLE_MSAN
  "Enable Memory Sanitizer" OFF)

# see https://github.com/Ericsson/codechecker/blob/master/tools/report-converter/README.md#thread-sanitizer
# NOTE: Compile with -g
# to get proper debug information in your binary.
option(ENABLE_TSAN
  "Enable Thread Sanitizer" OFF)

if(COMPILE_WITH_LLVM_TOOLS)
  message(STATUS
    "Using COMPILE_WITH_LLVM_TOOLS")
  # do not check compile in conanbuildinfo
  # cause we will switch to other compiler after conan install
  set(CONAN_DISABLE_CHECK_COMPILER ON)
else(COMPILE_WITH_LLVM_TOOLS)
  message(STATUS
    "Disabled COMPILE_WITH_LLVM_TOOLS")
endif(COMPILE_WITH_LLVM_TOOLS)

# --------------------------- conan configuration ------------------------------

# Conan package manager List of packages used by the project is container in
# conanfile.py
option(CONAN_AUTO_INSTALL "Let CMake call conan install automatically" OFF)
if (CONAN_AUTO_INSTALL)
  set(CONAN_PROFILE
      "default"
      CACHE STRING "Conan profile to use during installation")
  include(cmake/conan-auto-install.cmake)
  conan_auto_install(${CONAN_PROFILE})
endif()

if(EXISTS "${CMAKE_BINARY_DIR}/conanbuildinfo.cmake")
  list(APPEND CMAKE_MODULE_PATH ${CMAKE_BINARY_DIR}/)
  include(${CMAKE_BINARY_DIR}/conanbuildinfo.cmake)
  include(${CMAKE_BINARY_DIR}/conan_paths.cmake OPTIONAL)
  conan_basic_setup(
    # prevent conan_basic_setup from resetting cmake variables
    TARGETS
    KEEP_RPATHS
    # see https://github.com/conan-io/conan/issues/6012
    NO_OUTPUT_DIRS)
else()
  message (FATAL_ERROR "must use conan")
endif()

list(APPEND CMAKE_MODULE_PATH ${CMAKE_CURRENT_SOURCE_DIR}/)

if(ENABLE_MSAN OR ENABLE_TSAN OR ENABLE_ASAN OR ENABLE_UBSAN)
  find_package(cmake_sanitizers REQUIRED)
endif()

find_package(cmake_helper_utils REQUIRED)

# prefer ASCII for folder names
force_latin_paths() # from cmake_helper_utils (conan package)

# out dirs (CMAKE_*_OUTPUT_DIRECTORY) must be not empty
validate_out_dirs() # from cmake_helper_utils (conan package)

# In-source builds not allowed
validate_out_source_build(WARNING) # from cmake_helper_utils (conan package)

if(ENABLE_MSAN)
  add_msan_flags()
endif(ENABLE_MSAN)

if(ENABLE_TSAN)
  add_tsan_flags()
endif(ENABLE_TSAN)

if(ENABLE_ASAN)
  add_asan_flags()
endif(ENABLE_ASAN)

if(ENABLE_UBSAN)
  add_ubsan_flags()
endif(ENABLE_UBSAN)

if(COMPILE_WITH_LLVM_TOOLS)
  message(STATUS
    "Using COMPILE_WITH_LLVM_TOOLS")
  # force change CMAKE_*_COMPILER and CMAKE_LINKER to clang from conan
  compile_with_llvm_tools() # from cmake_helper_utils (conan package)
else(COMPILE_WITH_LLVM_TOOLS)
  message(STATUS
    "Disabled COMPILE_WITH_LLVM_TOOLS")
endif(COMPILE_WITH_LLVM_TOOLS)

find_package(cmake_platform_detection REQUIRED)
run_cmake_platform_detection()
# NOTE: perform platform checks before everything else
include(cmake/PlatformChecks)

find_package(cmake_build_options REQUIRED)
setup_default_build_type(RELEASE)
setup_cmake_build_options(RELEASE DEBUG)

set(ICU_PARENT_FULL_DIR ${CMAKE_CURRENT_SOURCE_DIR}/)

set(ICU_FULL_DIR ${ICU_PARENT_FULL_DIR}third_party/icu/)

include(cmake/CommonOptions)

include(cmake/icuOptions)

include(cmake/ProjectFiles)

# $<INSTALL_INTERFACE:...> is exported using install(EXPORT)
# $<BUILD_INTERFACE:...> is exported using export(), or when the target is used by another target in the same buildsystem
macro(add_relative_include_dir TARGET VISIBILITY_BUILD VISIBILITY_INSTALL NEW_ELEM)
  target_include_directories(${TARGET}
    ${VISIBILITY_BUILD} "$<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/${NEW_ELEM}>"
    ${VISIBILITY_INSTALL} "$<INSTALL_INTERFACE:$<INSTALL_PREFIX>/${CMAKE_INSTALL_INCLUDEDIR}/${NEW_ELEM}>"
  )
endmacro(add_relative_include_dir)

#
#set(COMMON_FLAGS "${COMMON_FLAGS} -DSK_USING_THIRD_PARTY_ICU=1")
# https://github.com/google/skia/blob/master/third_party/icu/BUILD.gn#L15
#set(COMMON_FLAGS "${COMMON_FLAGS} -DU_USING_ICU_NAMESPACE=0")
#

if(NOT EXISTS "${ICU_FULL_DIR}source/common")
  message(FATAL_ERROR "Unable to find ${ICU_FULL_DIR}source/common")
endif(NOT EXISTS "${ICU_FULL_DIR}source/common")

#if(TARGET_EMSCRIPTEN)
#  set(USE_OWN_ICU TRUE)
#elseif(TARGET_LINUX)
#  set(USE_OWN_ICU TRUE)
#  if (NOT USE_OWN_ICU)
#    # todo
#    set(EXTRA_ICU_DEFINITIONS
#      USING_SYSTEM_ICU=1
#      #ICU_UTIL_DATA_IMPL=ICU_UTIL_DATA_FILE
#      ICU_UTIL_DATA_IMPL=ICU_UTIL_DATA_STATIC
#      U_ICUDATAENTRY_IN_COMMON # if 'OS == "win" or icu_use_data_file_flag==1'
#      UCHAR_TYPE=uint16_t
#    )
#  endif(NOT USE_OWN_ICU)
#else()
#  message(FATAL_ERROR "icu platform not supported")
#endif()

#if(USE_OWN_ICU)
  add_library(${STATIC_LIB_NAME} STATIC
    ${ICU_SOURCES}
  )

  add_relative_include_dir(${STATIC_LIB_NAME} PUBLIC PUBLIC "")

  add_relative_include_dir(${STATIC_LIB_NAME} PUBLIC PUBLIC "third_party/icu/")

  #add_relative_include_dir(${STATIC_LIB_NAME} PUBLIC PUBLIC "third_party/icu/third_party")

  add_relative_include_dir(${STATIC_LIB_NAME} PUBLIC PUBLIC "third_party/icu/")

  add_relative_include_dir(${STATIC_LIB_NAME} PUBLIC PUBLIC "third_party/icu/source")

  # path to unicode/uvernum.h
  add_relative_include_dir(${STATIC_LIB_NAME} PUBLIC PUBLIC "third_party/icu/source/common")

  # path to uvernum.h
  add_relative_include_dir(${STATIC_LIB_NAME} PUBLIC PUBLIC "third_party/icu/source/common/unicode")

  add_relative_include_dir(${STATIC_LIB_NAME} PUBLIC PUBLIC "third_party/icu/source/i18n")

  add_relative_include_dir(${STATIC_LIB_NAME} PUBLIC PUBLIC "third_party/icu/source/allinone")

  add_relative_include_dir(${STATIC_LIB_NAME} PUBLIC PUBLIC "third_party/icu/source/config")

  add_relative_include_dir(${STATIC_LIB_NAME} PUBLIC PUBLIC "third_party/icu/source/data")

  add_relative_include_dir(${STATIC_LIB_NAME} PUBLIC PUBLIC "third_party/icu/source/extra")

  add_relative_include_dir(${STATIC_LIB_NAME} PUBLIC PUBLIC "third_party/icu/source/io")

  add_relative_include_dir(${STATIC_LIB_NAME} PUBLIC PUBLIC "third_party/icu/source/layoutex")

  add_relative_include_dir(${STATIC_LIB_NAME} PUBLIC PUBLIC "third_party/icu/source/stubdata")

  add_relative_include_dir(${STATIC_LIB_NAME} PUBLIC PUBLIC "third_party/icu/source/tools")

  # POSITION_INDEPENDENT_CODE for -fPIC
  # -fPIC may be used to link static library into dynamic one
  # Position-independent code requires special support,
  # and therefore works only on certain machines.
  # see https://akkadia.org/drepper/dsohowto.pdf
  set_property(TARGET ${STATIC_LIB_NAME} PROPERTY POSITION_INDEPENDENT_CODE ON)

  if(ENABLE_MSAN OR ENABLE_TSAN OR ENABLE_ASAN OR ENABLE_UBSAN)
    message(STATUS
      "Using sanitizers")

    if(cmake_build_type_tolower MATCHES "release" )
      message(WARNING
        "Disable sanitizers in Release builds")
    endif()

    # use llvm_tools from conan
    find_program_helper(llvm-symbolizer
      PATHS
        #${CONAN_BIN_DIRS}
        ${CONAN_BIN_DIRS_LLVM_TOOLS}
      NO_SYSTEM_ENVIRONMENT_PATH
      NO_CMAKE_SYSTEM_PATH
      ${ARGUMENTS_UNPARSED_ARGUMENTS}
      REQUIRED
      OUT_VAR LLVM_SYMBOLIZER_PROGRAM
      VERBOSE TRUE
    )
    check_sanitizer_options(
      ENABLE_TSAN ${ENABLE_TSAN}
      ENABLE_ASAN ${ENABLE_ASAN}
      ENABLE_MSAN ${ENABLE_MSAN}
      ENABLE_UBSAN ${ENABLE_UBSAN}
      LLVM_SYMBOLIZER_PROGRAM ${LLVM_SYMBOLIZER_PROGRAM}
    )
  else()
    message(STATUS
      "Disabled sanitizers")
  endif()

  if(ENABLE_MSAN)
    message(STATUS "enabling MSAN on ${STATIC_LIB_NAME}")
    add_msan_static_link(${STATIC_LIB_NAME})
    add_msan_definitions(${STATIC_LIB_NAME})
    add_msan_flags()
  else(ENABLE_MSAN)
    message(STATUS
      "Disabled ENABLE_MSAN")
  endif(ENABLE_MSAN)

  if(ENABLE_TSAN)
    message(STATUS "enabling TSAN on ${STATIC_LIB_NAME}")
    add_tsan_static_link(${STATIC_LIB_NAME})
    add_tsan_flags(${STATIC_LIB_NAME})
    add_tsan_definitions(${STATIC_LIB_NAME})
    add_tsan_flags()
  else(ENABLE_TSAN)
    message(STATUS
      "Disabled ENABLE_TSAN")
  endif(ENABLE_TSAN)

  if(ENABLE_ASAN)
    message(STATUS "enabling ASAN on ${STATIC_LIB_NAME}")
    add_asan_static_link(${STATIC_LIB_NAME})
    add_asan_definitions(${STATIC_LIB_NAME})
    add_asan_flags()
  else(ENABLE_ASAN)
    message(STATUS
      "Disabled ENABLE_ASAN")
  endif(ENABLE_ASAN)

  if(ENABLE_UBSAN)
    message(STATUS "enabling UBSAN on ${STATIC_LIB_NAME}")
    add_ubsan_static_link(${STATIC_LIB_NAME})
    add_ubsan_definitions(${STATIC_LIB_NAME})
    add_ubsan_flags()
  else(ENABLE_UBSAN)
    message(STATUS
      "Disabled ENABLE_UBSAN")
  endif(ENABLE_UBSAN)

  if(TARGET_EMSCRIPTEN)
    # use PROPERTY compiler.cppstd
  else()
    target_compile_features(${STATIC_LIB_NAME}
      PUBLIC cxx_auto_type
      PRIVATE cxx_variadic_templates)
  endif()

  target_compile_options(${STATIC_LIB_NAME} PRIVATE
    $<$<CXX_COMPILER_ID:GNU>:-Wall>)

  # In your source, include files from base/ like normal.
  # So if you want to use the string printf API, do:
  # #include <base/stringprintf.h>
  #target_include_directories(${STATIC_LIB_NAME} PUBLIC
  #  #${CHROMIUM_DIR}
  #  ${OWN_ICU_INCLUDE_DIRS}
  #)

  #target_include_directories(${STATIC_LIB_NAME} PRIVATE
    #${BASE_DIR}
  #)

  if(TARGET_EMSCRIPTEN)
    list(APPEND ICU_PUBLIC_DEFINES
      UCONFIG_NO_FILE_IO=1
      U_ENABLE_DYLOAD=0
      U_CHECK_DYLOAD=0
      UCONFIG_ONLY_HTML_CONVERSION=1
      # UCONFIG_NO_CONVERSION=1 # see UConverter & LIBXML_ICU_ENABLED
      UCONFIG_NO_IDNA=1 # see UIDNA_INFO_INITIALIZER in url/url_idna_icu.cc
      # UCONFIG_NO_NORMALIZATION=1 # NOTE: also disables break iteration!
      UCONFIG_NO_REGULAR_EXPRESSIONS=1
      UCONFIG_NO_TRANSLITERATION=1
      UCONFIG_NO_SERVICE=1
    )
  endif(TARGET_EMSCRIPTEN)

if(DISABLE_COLLATION)
  list(APPEND ICU_PUBLIC_DEFINES
    UCONFIG_NO_COLLATION=1 # see icu::Collator::TERTIARY in base/i18n
  )
  message(STATUS "COLLATION DISABLED")
else()
  message(STATUS "COLLATION ENABLED")
endif(DISABLE_COLLATION)

if(DISABLE_FORMATTING)
  list(APPEND ICU_PUBLIC_DEFINES
    UCONFIG_NO_FORMATTING=1 # see icu::NumberFormat in base/i18n
  )
  message(STATUS "FORMATTING DISABLED")
else()
  message(STATUS "FORMATTING ENABLED")
endif(DISABLE_FORMATTING)

# # TODO https://github.com/mbbill/JSC.js
# # # http://userguide.icu-project.org/howtouseicu
# # see http://transit.iut2.upmf-grenoble.fr/doc/icu-doc/html/uconfig_8h.html
# # see https://github.com/sillsdev/icu-dotnet/wiki/Making-a-minimal-build-for-ICU58-or-later
# set(COMMON_CXX_FLAGS "-DLIB_ICU_I18N_STATIC=1")
# set(COMMON_CXX_FLAGS "-DU_CHARSET_IS_UTF8=1")
# #set(COMMON_CXX_FLAGS "-DU_NO_DEFAULT_INCLUDE_UTF_HEADERS=0")
# #set(COMMON_CXX_FLAGS "-DU_NO_DEFAULT_INCLUDE_UTF_HEADERS=0")
# set(COMMON_CXX_FLAGS "-DU_ENABLE_DYLOAD=0")
# #set(COMMON_CXX_FLAGS "-DICU_UTIL_DATA_IMPL=ICU_UTIL_DATA_STATIC")
# set(COMMON_CXX_FLAGS "-DICU_UTIL_DATA_IMPL=ICU_UTIL_DATA_FILE")
# #
# #set(COMMON_CXX_FLAGS "-DU_DISABLE_VERSION_SUFFIX=1")
# #set(COMMON_FLAGS "${COMMON_FLAGS} -DU_USING_ICU_NAMESPACE=0")
# #
# #set(COMMON_CXX_FLAGS "-DUCONFIG_NO_SERVICE=1")
# set(COMMON_CXX_FLAGS "-DU_HAVE_STD_STRING=1")
# set(COMMON_CXX_FLAGS "-DUCONFIG_NO_LEGACY_CONVERSION=1")
# set(COMMON_CXX_FLAGS "-DUCONFIG_ONLY_COLLATION=1")
# set(COMMON_CXX_FLAGS "-DUCONFIG_NO_FILE_IO=1")
# set(COMMON_CXX_FLAGS "-DUCONFIG_NO_CONVERSION=1")
# set(COMMON_CXX_FLAGS "-DUCONFIG_NO_COLLATION=1")
# set(COMMON_CXX_FLAGS "-DUCONFIG_NO_FORMATTING=1")
# set(COMMON_CXX_FLAGS "-DUCONFIG_NO_IDNA=1")
# set(COMMON_CXX_FLAGS "-DUCONFIG_NO_NORMALIZATION=1")
# set(COMMON_CXX_FLAGS "-DUCONFIG_NO_REGULAR_EXPRESSIONS=1")
# set(COMMON_CXX_FLAGS "-DUCONFIG_NO_TRANSLITERATION=1")
# set(COMMON_CXX_FLAGS "-DU_NO_DEFAULT_INCLUDE_UTF_HEADERS=1")
# #
# #set(COMMON_CXX_FLAGS "-DUCONFIG_NO_BREAK_ITERATION=0")
# #set(COMMON_CXX_FLAGS "-DU_STATIC_IMPLEMENTATION=1")
# set(ICU_DEFINES "${ICU_DEFINES} -DUCHAR_TYPE=uint16_t")
# # set(ICU_DEFINES "${ICU_DEFINES} -DU_STATIC_IMPLEMENTATION=1")
# # set(ICU_DEFINES "${ICU_DEFINES} -DU_COMMON_IMPLEMENTATION=1")
# # set(ICU_DEFINES "${ICU_DEFINES} -DU_I18N_IMPLEMENTATION=1")
# # set(ICU_DEFINES "${ICU_DEFINES} -DU_ENABLE_DYLOAD=0")
# # set(ICU_DEFINES "${ICU_DEFINES} -DHAVE_DLFCN_H=0")
# # set(ICU_DEFINES "${ICU_DEFINES} -DHAVE_DLOPEN=0")
# # if(TARGET_EMSCRIPTEN)
# #   # Tell ICU that we are a 32 bit platform, otherwise,
# #   # double-conversion-utils.h doesn't know how to operate.
# #   set(ICU_DEFINES "${ICU_DEFINES} -D__i386__=1")
# # endif()
# # set(ICU_DEFINES "${ICU_DEFINES} -DU_NO_DEFAULT_INCLUDE_UTF_HEADERS=0")
# # # undefines U_ATTRIBUTE_DEPRECATED
# # set(ICU_DEFINES "${ICU_DEFINES} -UU_ATTRIBUTE_DEPRECATED")
# # # undefines U_NO_DEFAULT_INCLUDE_UTF_HEADERS
# # #set(ICU_DEFINES "${ICU_DEFINES} -UU_NO_DEFAULT_INCLUDE_UTF_HEADERS")
#

# TODO https://github.com/mbbill/JSC.js
# # http://userguide.icu-project.org/howtouseicu
# see http://transit.iut2.upmf-grenoble.fr/doc/icu-doc/html/uconfig_8h.html
# see https://github.com/sillsdev/icu-dotnet/wiki/Making-a-minimal-build-for-ICU58-or-later
  # http://userguide.icu-project.org/howtouseicu#TOC-C-With-Your-Own-Build-System
  list(APPEND ICU_PUBLIC_DEFINES
    U_ENABLE_TRACING=1
    U_ENABLE_RESOURCE_TRACING=0
    U_ENABLE_DYLOAD=0
    ICU_UTIL_DATA_IMPL=ICU_UTIL_DATA_FILE
    #ICU_UTIL_DATA_IMPL=ICU_UTIL_DATA_STATIC
    LIB_ICU_I18N_STATIC=1
    # see http://site.icu-project.org/repository/tips/linux
    U_CHARSET_IS_UTF8=1
    #U_HAVE_STD_STRING=1 # obsolete (ICU-12736)
    # UCONFIG_ONLY_COLLATION=1 # NOTE: also disables break iteration!
    #UCONFIG_NO_FILE_IO=1
    # see http://userguide.icu-project.org/packaging
    #UCONFIG_NO_LEGACY_CONVERSION=1
    #UCONFIG_ONLY_HTML_CONVERSION=1
    UCONFIG_USE_WINDOWS_LCID_MAPPING_API=0
    U_USING_ICU_NAMESPACE=0
    #
    # If U_NO_DEFAULT_INCLUDE_UTF_HEADERS is 0 then utf.h is
    # included by utypes.h and itself includes utf8.h
    # and utf16.h after some common definitions.
    # If U_NO_DEFAULT_INCLUDE_UTF_HEADERS is 1 then
    # each of these headers must be included explicitly
    # if their definitions are used.
    # SEE: http://icu-project.org/apiref/icu4c/utf_8h.html
    # U_NO_DEFAULT_INCLUDE_UTF_HEADERS=1 # see U16_NEXT in base/i18n
    #
    #U_HIDE_OBSOLETE_UTF_OLD_H=1 # utf_old.h is deprecated or obsolete, ICU>60
  )

  set(ICU_PRIVATE_DEFINES
    HAVE_DLOPEN=0
    # see http://icu-project.org/apiref/icu4c561/uconfig_8h.html
    #
    # custom
    HAVE_DLFCN_H=0
  )

  # U_EXPORT (defined in unicode/platform.h) is used to set public visibility
  # on classes through the U_COMMON_API and U_I18N_API macros (among others).
  # When linking against the system ICU library, we want its symbols to have
  # public LTO visibility. This disables CFI checks for the ICU classes and
  # allows whole-program optimization to be applied to the rest of Chromium.
  #
  # Both U_COMMON_API and U_I18N_API macros would be defined to U_EXPORT only
  # when U_COMBINED_IMPLEMENTATION is defined (see unicode/utypes.h). Because
  # we override the default system UCHAR_TYPE (char16_t), it is not possible
  # to use U_COMBINED_IMPLEMENTATION at this moment, meaning the U_COMMON_API
  # and U_I18N_API macros are set to U_IMPORT which is an empty definition.
  #
  # Until building with UCHAR_TYPE=char16_t is supported, one way to apply
  # public visibility (and thus public LTO visibility) to all ICU classes is
  # to define U_IMPORT to have the same value as U_EXPORT. For more details,
  # please see: https://crbug.com/822820
  list(APPEND ICU_PUBLIC_DEFINES
    U_IMPORT=U_EXPORT
  )

  #    "USING_SYSTEM_ICU=1",a_
  #    "ICU_UTIL_DATA_IMPL=ICU_UTIL_DATA_STATIC",
  #    "UCHAR_TYPE=uint16_t",
  #
  #    # U_EXPORT (defined in unicode/platform.h) is used to set public visibility
  #    # on classes through the U_COMMON_API and U_I18N_API macros (among others).
  #    # When linking against the system ICU library, we want its symbols to have
  #    # public LTO visibility. This disables CFI checks for the ICU classes and
  #    # allows whole-program optimization to be applied to the rest of Chromium.
  #    #
  #    # Both U_COMMON_API and U_I18N_API macros would be defined to U_EXPORT only
  #    # when U_COMBINED_IMPLEMENTATION is defined (see unicode/utypes.h). Because
  #    # we override the default system UCHAR_TYPE (char16_t), it is not possible
  #    # to use U_COMBINED_IMPLEMENTATION at this moment, meaning the U_COMMON_API
  #    # and U_I18N_API macros are set to U_IMPORT which is an empty definition.
  #    #
  #    # Until building with UCHAR_TYPE=char16_t is supported, one way to apply
  #    # public visibility (and thus public LTO visibility) to all ICU classes is
  #    # to define U_IMPORT to have the same value as U_EXPORT. For more details,
  #    # please see: https://crbug.com/822820
  #    "U_IMPORT=U_EXPORT",

  target_compile_definitions(${STATIC_LIB_NAME} PUBLIC
    ${ICU_PUBLIC_DEFINES}
    #${WTF_EMCC_DEFINITIONS}
    #${WTF_COMMON_DEFINITIONS}
    LIB_ICU_I18N_STATIC=1
    #U_NO_DEFAULT_INCLUDE_UTF_HEADERS=0
    #U_NO_DEFAULT_INCLUDE_UTF_HEADERS
    #U_ATTRIBUTE_DEPRECATED
  )

  target_compile_definitions(${STATIC_LIB_NAME} PRIVATE
    ICU_IMPLEMENTATION=1
    U_STATIC_IMPLEMENTATION=1
    U_COMMON_IMPLEMENTATION=1
    U_I18N_IMPLEMENTATION=1
    U_ATTRIBUTE_DEPRECATED=
    ${ICU_PRIVATE_DEFINES}
    OFFICIAL_BUILD=1
    # https://cs.chromium.org/chromium/src/build/build_config.h?g=0&l=86
    COMPONENT_BUILD=1
    # https://github.com/cool-easy/libchromiumbase/blob/master/build/config/linux/BUILD.gn#L88
    # USE_GLIB=1
    __STDC_FORMAT_MACROS
    #
    #${WTF_EMCC_DEFINITIONS}
    #${WTF_COMMON_DEFINITIONS}
    #
    #SYSTEM_NATIVE_UTF8
    #COM_INIT_CHECK_HOOK_DISABLED
    #USE_SYMBOLIZE
    #BASE_I18N_IMPLEMENTATION
    #MALLOC_WRAPPER_LIB=\"${shlib_prefix}malloc_wrapper${shlib_extension}\"
    #MEMORY_TOOL_REPLACES_ALLOCATOR=1
  )

  target_compile_options(${STATIC_LIB_NAME} PRIVATE
    -Wno-error
    # TODO: remove rtti from icu
    # https://bugs.chromium.org/p/chromium/issues/detail?id=463085
    -frtti
  )
#endif(USE_OWN_ICU)

#if(TARGET_EMSCRIPTEN)
#  # Tell ICU that we are a 32 bit platform, otherwise,
#  # double-conversion-utils.h doesn't know how to operate.
#  set(ICU_DEFINES "${ICU_DEFINES} -D__i386__=1")
#endif()

set_property(TARGET ${STATIC_LIB_NAME} PROPERTY C_EXTENSIONS ON)
set_property(TARGET ${STATIC_LIB_NAME} PROPERTY C_STANDARD 11)
#set_property(TARGET ${STATIC_LIB_NAME} PROPERTY CXX_STANDARD 17)

set(DEBUG_LIBRARY_SUFFIX "-d")
set_target_properties(${STATIC_LIB_NAME}
  PROPERTIES
    ARCHIVE_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}" # TODO: /lib
    LIBRARY_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}" # TODO: /lib
    RUNTIME_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}" # TODO: /bin
    OUTPUT_NAME "${STATIC_LIB_NAME}$<$<CONFIG:Debug>:${DEBUG_LIBRARY_SUFFIX}>"
)

# install and export steps
include(cmake/Exports)
