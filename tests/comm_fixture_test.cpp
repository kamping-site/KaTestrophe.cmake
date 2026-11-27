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
#include <gtest/gtest.h>
#include <katestrophe.hpp>
#include <mpi.h>


KATESTROPHE_TEST(KaTestropheCommFixtureTest, comm_is_a_duplicate_of_world) {
  int world_size = 0;
  MPI_Comm_size(MPI_COMM_WORLD, &world_size);
  EXPECT_EQ(size, world_size);
  int cmp = MPI_UNEQUAL;
  MPI_Comm_compare(comm, MPI_COMM_WORLD, &cmp);
  EXPECT_EQ(cmp, MPI_CONGRUENT);

  int value = rank == 0 ? 42 : 0;
  MPI_Bcast(&value, 1, MPI_INT, 0, comm);
  EXPECT_EQ(value, 42);
}

// Derived fixtures work with TEST_F and may override SetUp without calling the base.
class DerivedFixture : public katestrophe::MPITest {
protected:
  void SetUp() override { doubled_rank = 2 * rank; }
  int doubled_rank = -1;
};

TEST_F(DerivedFixture, has_comm) {
  EXPECT_NE(comm, MPI_COMM_NULL);
  EXPECT_EQ(doubled_rank, 2 * rank);
  int sum = 0;
  MPI_Allreduce(&rank, &sum, 1, MPI_INT, MPI_SUM, comm);
  EXPECT_EQ(sum, size * (size - 1) / 2);
}
