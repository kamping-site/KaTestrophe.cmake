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

# sets the provided output variable KATESTROPHE_OVERSUBSCRIBE_FLAG to the flags
# required to run mpiexec with more MPI ranks than cores available
function(katestrophe_has_oversubscribe KATESTROPHE_OVERSUBSCRIBE_FLAG)
  if(MPI_CXX_LIBRARY_VERSION_STRING)
    string(FIND ${MPI_CXX_LIBRARY_VERSION_STRING} "OpenMPI" SEARCH_POSITION1)
    string(FIND ${MPI_CXX_LIBRARY_VERSION_STRING} "Open MPI" SEARCH_POSITION2)
    # only Open MPI seems to require the --oversubscribe flag MPICH and Intel
    # don't know it but silently run commands with more ranks than cores
    # available
    if(${SEARCH_POSITION1} EQUAL -1 AND ${SEARCH_POSITION2} EQUAL -1)
      set("${KATESTROPHE_OVERSUBSCRIBE_FLAG}"
          ""
          PARENT_SCOPE
      )
    else()
      # We are using Open MPI
      set("${KATESTROPHE_OVERSUBSCRIBE_FLAG}"
          "--oversubscribe"
          PARENT_SCOPE
      )
    endif()
  else()
    set("${KATESTROPHE_OVERSUBSCRIBE_FLAG}"
        ""
        PARENT_SCOPE
    )
  endif()
endfunction()
katestrophe_has_oversubscribe(MPIEXEC_OVERSUBSCRIBE_FLAG)

# register the test main class
add_library(
  mpi-gtest-main EXCLUDE_FROM_ALL ${CMAKE_CURRENT_LIST_DIR}/mpi_gtest_main.cpp
)
target_link_libraries(mpi-gtest-main PUBLIC gtest-mpi-listener)

add_library(KaTestrophe_main INTERFACE)
target_link_libraries(KaTestrophe_main INTERFACE mpi-gtest-main)
add_library(KaTestrophe::main ALIAS KaTestrophe_main)

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
  target_link_libraries(${KATESTROPHE_TARGET} PUBLIC mpi-gtest-main)
endfunction()

# Registers an executable target KATESTROPHE_TEST_TARGET as a test to be
# executed with ctest
#
# KATESTROPHE_TEST_TARGET target name DISCOVER_TESTS sets whether the individual
# tests should be added to the ctest output (like gtest_discover_tests) CORES
# the number of MPI ranks to run the test with
#
# example: katestrophe_add_mpi_test(mytest CORES 2 4 8)
function(katestrophe_add_mpi_test KATESTROPHE_TEST_TARGET)
  cmake_parse_arguments(KATESTROPHE "DISCOVER_TESTS" "" "CORES" ${ARGN})
  if(NOT KATESTROPHE_CORES)
    set(KATESTROPHE_CORES ${MPIEXEC_MAX_NUMPROCS})
  endif()
  foreach(p ${KATESTROPHE_CORES})
    set(TEST_NAME "${KATESTROPHE_TEST_TARGET}.${p}cores")
    set(MPI_EXEC_COMMAND ${MPIEXEC} ${MPIEXEC_NUMPROC_FLAG} ${p}
                         ${MPIEXEC_OVERSUBSCRIBE_FLAG} ${MPIEXEC_PREFLAGS}
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
        ${MPI}
        MPI_EXEC_COMMAND
        "${MPI_EXEC_COMMAND}"
        # PROPERTIES ENVIRONMENT "ASAN_OPTIONS=detect_leaks=0" # Prevent memory
        # leaks in OpenMPI from # making the test fail.
      )
    else()
      add_test(
        NAME "${TEST_NAME}"
        COMMAND ${MPI_EXEC_COMMAND} $<TARGET_FILE:${KATESTROPHE_TEST_TARGET}>
        WORKING_DIRECTORY ${PROJECT_SOURCE_DIR}
      )
      # # Prevent memory leaks in OpenMPI from making the test fail.
      # set_property( TEST ${TEST_NAME} PROPERTY ENVIRONMENT
      # "ASAN_OPTIONS=detect_leaks=0" )
    endif()
    # TODO: Do not rely on the return value of mpiexec to check if a test
    # succeeded, as this does not work for ULFM.
  endforeach()
endfunction()
