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

// Regression test for consecutive tests in one binary not being isolated (issue #7): a fast rank
// must not start the next test while a slow rank is still inside the previous one.
#include <chrono>
#include <thread>

#include <gtest/gtest.h>
#include <mpi.h>

namespace {
constexpr int kTag = 4242;
// Set on rank 0 if the receive of the first test matched the message of the second test.
bool message_stolen = false;
} // namespace

// Rank 0 has an outstanding receive on MPI_COMM_WORLD for a while; the other ranks leave at once.
TEST(KaTestropheIsolationTest, a_slow_rank_with_pending_receive) {
  int rank = 0;
  MPI_Comm_rank(MPI_COMM_WORLD, &rank);
  if (rank != 0) {
    return;
  }
  int buffer = 0;
  MPI_Request request;
  MPI_Irecv(&buffer, 1, MPI_INT, MPI_ANY_SOURCE, kTag, MPI_COMM_WORLD, &request);
  // Poll (and thereby progress) the receive for a while, like a message queue would.
  int completed = 0;
  auto const deadline = std::chrono::steady_clock::now() + std::chrono::milliseconds(500);
  while (!completed && std::chrono::steady_clock::now() < deadline) {
    MPI_Test(&request, &completed, MPI_STATUS_IGNORE);
    std::this_thread::sleep_for(std::chrono::milliseconds(1));
  }
  if (!completed) {
    MPI_Cancel(&request);
    MPI_Wait(&request, MPI_STATUS_IGNORE);
  }
  message_stolen = completed;
  EXPECT_FALSE(completed) << "received a message sent by the next test";
}

// Rank 1 sends to rank 0 right away. Without synchronization between tests, this message is matched
// by the receive of the previous test.
TEST(KaTestropheIsolationTest, b_fast_rank_sends) {
  int rank = 0;
  int size = 0;
  MPI_Comm_rank(MPI_COMM_WORLD, &rank);
  MPI_Comm_size(MPI_COMM_WORLD, &size);
  if (size < 2) {
    GTEST_SKIP() << "needs at least 2 ranks";
  }
  int value = 42;
  if (rank == 1) {
    MPI_Send(&value, 1, MPI_INT, 0, kTag, MPI_COMM_WORLD);
  } else if (rank == 0 && !message_stolen) {
    int received = 0;
    MPI_Recv(&received, 1, MPI_INT, 1, kTag, MPI_COMM_WORLD, MPI_STATUS_IGNORE);
    EXPECT_EQ(received, 42);
  }
}
