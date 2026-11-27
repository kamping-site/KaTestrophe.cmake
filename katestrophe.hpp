// MIT License
//
// Copyright (c) 2025 Tim Niklas Uhl
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.
#pragma once

#include <gtest/gtest.h>
#include <mpi.h>

namespace katestrophe {

// Test fixture that gives every test its own communicator: a duplicate of MPI_COMM_WORLD, created
// before the test and freed after it. Messages that a test leaves unreceived on `comm` can therefore
// never be matched by a later test. Use it with KATESTROPHE_TEST, or derive your own fixture from it
// and use TEST_F.
//
// The duplicate is created in the constructor and freed in the destructor (not in SetUp/TearDown),
// so derived fixtures that override SetUp/TearDown do not need to call the base versions, and
// members of derived fixtures are destroyed before `comm` is freed.
class MPITest : public ::testing::Test {
protected:
    MPITest() {
        MPI_Comm_dup(MPI_COMM_WORLD, &comm);
        MPI_Comm_rank(comm, &rank);
        MPI_Comm_size(comm, &size);
    }

    ~MPITest() override {
        MPI_Comm_free(&comm);
    }

    MPITest(MPITest const&)            = delete;
    MPITest& operator=(MPITest const&) = delete;

    MPI_Comm comm = MPI_COMM_NULL; ///< This test's communicator, a duplicate of MPI_COMM_WORLD.
    int      rank = 0;             ///< Rank of this process in `comm`.
    int      size = 0;             ///< Number of ranks in `comm`.
};

} // namespace katestrophe

// Like TEST(test_suite_name, test_name), but the test body runs in a katestrophe::MPITest fixture and
// can use `comm`, `rank` and `size`.
//
// example:
//   KATESTROPHE_TEST(MySuite, broadcast_works) {
//       int value = rank == 0 ? 42 : 0;
//       MPI_Bcast(&value, 1, MPI_INT, 0, comm);
//       EXPECT_EQ(value, 42);
//   }
#define KATESTROPHE_TEST(test_suite_name, test_name) \
    GTEST_TEST_(                                     \
        test_suite_name,                             \
        test_name,                                   \
        ::katestrophe::MPITest,                      \
        ::testing::internal::GetTypeId<::katestrophe::MPITest>())
