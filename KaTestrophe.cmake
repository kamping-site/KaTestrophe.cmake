# MIT License
#
# Copyright (c) 2021-2025 Tim Niklas Uhl
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.
cmake_minimum_required(VERSION 3.23)

include_guard(GLOBAL)

option(KATESTROPHE_USE_EXTERNAL_GTEST "Use find_package to find googletest instead of embedding it via FetchContent." OFF)
set(KATESTROPHE_GTEST_VERSION "v1.17.0" CACHE STRING "The googletest version to fetch if FetchContent is used.")

find_package(MPI REQUIRED)
if(KATESTROPHE_USE_EXTERNAL_GTEST)
  find_package(GTest REQUIRED)
else()
  include(FetchContent)
  FetchContent_Declare(
    googletest
    GIT_REPOSITORY https://github.com/google/googletest
    GIT_TAG "${KATESTROPHE_GTEST_VERSION}"
    GIT_SHALLOW ON
    SYSTEM
  )
  set(INSTALL_GTEST OFF)
  FetchContent_MakeAvailable(googletest)
endif()

include(${CMAKE_CURRENT_LIST_DIR}/MPIGoogleTest.cmake)

# gtest-mpi-listener does not use modern CMake, therefore we need this fix
add_library(gtest-mpi-listener INTERFACE)
target_sources(
  gtest-mpi-listener
  INTERFACE
  FILE_SET HEADERS
  BASE_DIRS ${CMAKE_CURRENT_LIST_DIR}
  FILES gtest-mpi-listener.hpp
)

target_link_libraries(
  gtest-mpi-listener INTERFACE MPI::MPI_CXX GTest::gtest GTest::gmock
)

# Open MPI refuses to start more ranks than there are slots unless --oversubscribe is passed; MPICH
# and Intel MPI do not know the flag but oversubscribe silently. The MPI implementation is detected
# from `mpiexec --version` (FindMPI only reports MPI_CXX_LIBRARY_VERSION_STRING when
# MPI_DETERMINE_LIBRARY_VERSION is set). The result is a cache variable, so it is visible in every
# directory, including when KaTestrophe is added via FetchContent/add_subdirectory, and can be
# overridden by the user.
if(NOT DEFINED KATESTROPHE_MPIEXEC_OVERSUBSCRIBE_FLAG)
  set(_katestrophe_oversubscribe_flag "")
  if(MPIEXEC_EXECUTABLE)
    execute_process(
      COMMAND ${MPIEXEC_EXECUTABLE} --version
      OUTPUT_VARIABLE _katestrophe_mpiexec_version
      ERROR_VARIABLE _katestrophe_mpiexec_version
      RESULT_VARIABLE _katestrophe_mpiexec_result
      TIMEOUT 10
    )
    if(_katestrophe_mpiexec_result EQUAL 0
       AND _katestrophe_mpiexec_version MATCHES "Open MPI|OpenMPI|OpenRTE|Open RTE|prterun"
    )
      set(_katestrophe_oversubscribe_flag "--oversubscribe")
    endif()
  endif()
  set(KATESTROPHE_MPIEXEC_OVERSUBSCRIBE_FLAG
      "${_katestrophe_oversubscribe_flag}"
      CACHE STRING "Flag passed to mpiexec to allow more MPI ranks than available slots (detected)."
  )
  mark_as_advanced(KATESTROPHE_MPIEXEC_OVERSUBSCRIBE_FLAG)
endif()

set(KATESTROPHE_MAX_CORES
    ""
    CACHE STRING
    "If set, katestrophe_add_mpi_test skips rank counts larger than this (e.g. ${MPIEXEC_MAX_NUMPROCS}, the number of cores on this machine). Empty: no limit, oversubscribe instead."
)

# sets the provided output variable KATESTROPHE_OVERSUBSCRIBE_FLAG to the flags required to run
# mpiexec with more MPI ranks than cores available (kept for backwards compatibility)
function(katestrophe_has_oversubscribe KATESTROPHE_OVERSUBSCRIBE_FLAG)
  set("${KATESTROPHE_OVERSUBSCRIBE_FLAG}"
      "${KATESTROPHE_MPIEXEC_OVERSUBSCRIBE_FLAG}"
      PARENT_SCOPE
  )
endfunction()
# backwards compatibility: this variable used to be the only source of the flag
set(MPIEXEC_OVERSUBSCRIBE_FLAG "${KATESTROPHE_MPIEXEC_OVERSUBSCRIBE_FLAG}")

# Registers the Google Test + MPI entry point as the library target TARGET_NAME. The MPI runtime is
# initialized with MPI_Init_thread at the requested THREAD_LEVEL (an MPI_THREAD_* constant); when
# THREAD_LEVEL is omitted it defaults to MPI_THREAD_SINGLE, which the MPI standard defines as
# equivalent to the plain MPI_Init used by the default KaTestrophe::main. Link the resulting target
# into a test executable instead of mpi-gtest-main / KaTestrophe::main to obtain an elevated level;
# tests can read the level the runtime actually provided with MPI_Query_thread.
#
# example: katestrophe_add_mpi_main(my-mpi-main THREAD_LEVEL MPI_THREAD_MULTIPLE)
function(katestrophe_add_mpi_main TARGET_NAME)
  cmake_parse_arguments("KATESTROPHE" "" "THREAD_LEVEL" "" ${ARGN})
  add_library(
    ${TARGET_NAME} EXCLUDE_FROM_ALL
                   ${CMAKE_CURRENT_FUNCTION_LIST_DIR}/mpi_gtest_main.cpp
  )
  target_link_libraries(${TARGET_NAME} PUBLIC gtest-mpi-listener)
  if(KATESTROPHE_THREAD_LEVEL)
    target_compile_definitions(
      ${TARGET_NAME}
      PRIVATE KATESTROPHE_REQUIRED_THREAD_LEVEL=${KATESTROPHE_THREAD_LEVEL}
    )
  endif()
endfunction()

# Register a Google Test + MPI entry point for each MPI thread support level. Consumers link the
# matching alias target (KaTestrophe::main_thread_<level>) instead of building their own main.
katestrophe_add_mpi_main(mpi-gtest-main-thread-single THREAD_LEVEL MPI_THREAD_SINGLE)
katestrophe_add_mpi_main(mpi-gtest-main-thread-funneled THREAD_LEVEL MPI_THREAD_FUNNELED)
katestrophe_add_mpi_main(mpi-gtest-main-thread-serialized THREAD_LEVEL MPI_THREAD_SERIALIZED)
katestrophe_add_mpi_main(mpi-gtest-main-thread-multiple THREAD_LEVEL MPI_THREAD_MULTIPLE)

foreach(KATESTROPHE_LEVEL single funneled serialized multiple)
  add_library(KaTestrophe_main_thread_${KATESTROPHE_LEVEL} INTERFACE)
  target_link_libraries(
    KaTestrophe_main_thread_${KATESTROPHE_LEVEL} INTERFACE
    mpi-gtest-main-thread-${KATESTROPHE_LEVEL}
  )
  add_library(KaTestrophe::main_thread_${KATESTROPHE_LEVEL} ALIAS
              KaTestrophe_main_thread_${KATESTROPHE_LEVEL})
endforeach()

# KaTestrophe::main keeps the historic default (MPI_THREAD_SINGLE, i.e. plain-MPI_Init behavior).
add_library(KaTestrophe::main ALIAS KaTestrophe_main_thread_single)

# keep the cache clean
mark_as_advanced(
  BUILD_GMOCK
  BUILD_GTEST
  BUILD_SHARED_LIBS
  gmock_build_tests
  gtest_build_samples
  gtest_build_tests
  gtest_disable_pthreads
  gtest_force_shared_crt
  gtest_hide_internal_symbols
)

# Adds an executable target with the specified files FILES and links gtest and
# the MPI gtest runner
#
# KATESTROPHE_TARGET target name FILES the files to include in the target
#
# example: katestrophe_add_test_executable(mytarget FILES mytarget.cpp
# myotherfile.cpp)
function(katestrophe_add_test_executable KATESTROPHE_TARGET)
  cmake_parse_arguments("KATESTROPHE" "" "" "FILES" ${ARGN})
  add_executable(${KATESTROPHE_TARGET} "${KATESTROPHE_FILES}")
  target_link_libraries(${KATESTROPHE_TARGET} PUBLIC KaTestrophe::main)
endfunction()

# Registers an executable target KATESTROPHE_TEST_TARGET as a test to be executed with ctest, once
# per rank count.
#
# KATESTROPHE_TEST_TARGET: the target name
# DISCOVER_TESTS: add the individual tests to the ctest output (like gtest_discover_tests)
# CORES: the numbers of MPI ranks to run the test with (default: MPIEXEC_MAX_NUMPROCS); counts above
#        KATESTROPHE_MAX_CORES are skipped
# WORKING_DIRECTORY: where the test runs (default: PROJECT_SOURCE_DIR)
#
# example: katestrophe_add_mpi_test(mytest CORES 2 4 8)
function(katestrophe_add_mpi_test KATESTROPHE_TEST_TARGET)
  cmake_parse_arguments(KATESTROPHE "DISCOVER_TESTS" "WORKING_DIRECTORY" "CORES" ${ARGN})
  if(NOT KATESTROPHE_CORES)
    set(KATESTROPHE_CORES ${MPIEXEC_MAX_NUMPROCS})
  endif()
  if(NOT KATESTROPHE_WORKING_DIRECTORY)
    set(KATESTROPHE_WORKING_DIRECTORY ${PROJECT_SOURCE_DIR})
  endif()
  foreach(p ${KATESTROPHE_CORES})
    if(NOT KATESTROPHE_MAX_CORES STREQUAL "" AND p GREATER KATESTROPHE_MAX_CORES)
      message(VERBOSE "KaTestrophe: skipping ${KATESTROPHE_TEST_TARGET} with ${p} ranks "
                      "(KATESTROPHE_MAX_CORES=${KATESTROPHE_MAX_CORES})")
      continue()
    endif()
    set(TEST_NAME "${KATESTROPHE_TEST_TARGET}.${p}cores")
    set(MPI_EXEC_COMMAND ${MPIEXEC_EXECUTABLE} ${MPIEXEC_NUMPROC_FLAG} ${p}
                         ${KATESTROPHE_MPIEXEC_OVERSUBSCRIBE_FLAG} ${MPIEXEC_PREFLAGS}
    )
    if(KATESTROPHE_DISCOVER_TESTS)
      string(REPLACE ";" " " MPI_EXEC_COMMAND "${MPI_EXEC_COMMAND}")
      katestrophe_discover_tests(
        ${KATESTROPHE_TEST_TARGET}
        DISCOVERY_TIMEOUT
        30
        TEST_SUFFIX
        ".${p}cores"
        WORKING_DIRECTORY
        ${KATESTROPHE_WORKING_DIRECTORY}
        MPI_EXEC_COMMAND
        "${MPI_EXEC_COMMAND}"
      )
    else()
      add_test(
        NAME "${TEST_NAME}"
        COMMAND ${MPI_EXEC_COMMAND} $<TARGET_FILE:${KATESTROPHE_TEST_TARGET}>
        WORKING_DIRECTORY ${KATESTROPHE_WORKING_DIRECTORY}
      )
    endif()
    # TODO: Do not rely on the return value of mpiexec to check if a test
    # succeeded, as this does not work for ULFM.
  endforeach()
endfunction()
