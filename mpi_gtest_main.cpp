// Copyright (C) 2021-2025 by Tim Niklas Uhl
//
// This has been copied from LLNL/gtest-mpi-listener with minor modification,
// which in turn is based on an example from Google Test and triple-licensed
// under BSD-3, MIT, and Apache 2.0
//
// The original copyright notices are replicated below

/******************************************************************************
 *
 * Copyright (c) 2016-2018, Lawrence Livermore National Security, LLC
 * and other gtest-mpi-listener developers. See the COPYRIGHT file for details.
 *
 * SPDX-License-Identifier: (Apache-2.0 OR MIT)
 *
 ******************************************************************************/

#include <stdexcept>

#include <gtest/gtest.h>
#include <mpi.h>

#include "gtest-mpi-listener.hpp"

// The thread support level requested from MPI_Init_thread. Defaults to MPI_THREAD_SINGLE, which the
// MPI standard defines as equivalent to the plain MPI_Init.
// Override per main library via katestrophe_add_mpi_main(THREAD_LEVEL).
#ifndef KATESTROPHE_REQUIRED_THREAD_LEVEL
    #define KATESTROPHE_REQUIRED_THREAD_LEVEL MPI_THREAD_SINGLE
#endif

int main(int argc, char** argv) {
    // Filter out Google Test arguments
    ::testing::InitGoogleTest(&argc, argv);

    // Initialize MPI at the requested thread support level.
    int provided = MPI_THREAD_SINGLE;
    MPI_Init_thread(&argc, &argv, KATESTROPHE_REQUIRED_THREAD_LEVEL, &provided);

    int init_flag;
    MPI_Initialized(&init_flag);
    if (!init_flag) {
        throw std::runtime_error("Not initialized");
    }

    // Add object that will finalize MPI on exit; Google Test owns this pointer
    ::testing::AddGlobalTestEnvironment(new GTestMPIListener::MPIEnvironment);

    // Get the event listener list.
    ::testing::TestEventListeners& listeners = ::testing::UnitTest::GetInstance()->listeners();

    // Remove default listener: the default printer and the default XML printer
    ::testing::TestEventListener* l = listeners.Release(listeners.default_result_printer());

    // Adds MPI listener; Google Test owns this pointer
    listeners.Append(new GTestMPIListener::MPIWrapperPrinter(l, MPI_COMM_WORLD));

    // Run tests, then clean up and exit. RUN_ALL_TESTS() returns 0 if all tests
    // pass and 1 if some test fails.
    int result = RUN_ALL_TESTS();

    return result;
}
