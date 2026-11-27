# KaTestrophe.cmake 🌋

CMake support for MPI-enabled GoogleTest. Helps you to easily define and run MPI tests via CTest with minimal boilerplate.

## Quickstart
### 1. Add to your project via FetchContent
```cmake
include(FetchContent)
FetchContent_Declare(
  KaTestrophe
  GIT_REPOSITORY https://github.com/kamping-site/KaTestrophe.cmake
  GIT_TAG        v1.2.0
)
FetchContent_MakeAvailable(KaTestrophe)
```
## 2. Write you tests as usual using GoogleTest and use MPI functions
```cpp
# FILE: simple_test.cpp

#include <gtest/gtest.h>
#include <mpi.h>

TEST(KaTestropheSimpleTest, broadcast_works) {
   int rank = 0;
  MPI_Comm_rank(MPI_COMM_WORLD, &rank);
  int value = 0;
  if (rank == 0) {
    value = 42;
  }
  MPI_Bcast(&value, 1, MPI_INT, 0, MPI_COMM_WORLD);
  EXPECT_EQ(value, 42);
}
```

### 3. Add a cmake target and register it with CTest using KaTestrophe
```cmake
# link the KatTestrophe library, which ensure that MPI is initialized and finalized correctly
# before and after the test and provides the main function for the test
add_executable(simple_test simple_test.cpp)

target_link_libraries(simple_test PRIVATE KaTestrophe::main)

# register the test with CTest and execute it using MPI with 1 to 4 processes
katestrophe_add_mpi_test(simple_test CORES 1 2 3 4)

# or discover tests in excutable automatically, similar to how gtest_discover_tests works
katestrophe_add_mpi_test(simple_test DISCOVER_TESTS CORES 1 2 3 4)
```

### Requesting an MPI thread support level

`KaTestrophe::main` initializes MPI at `MPI_THREAD_SINGLE`. To exercise code that needs a higher
level, link one of the predefined main targets instead. There is one alias per MPI thread support
level:

| Target                                | `MPI_Init_thread` level |
| ------------------------------------- | ----------------------- |
| `KaTestrophe::main`                   | `MPI_THREAD_SINGLE`     |
| `KaTestrophe::main_thread_single`     | `MPI_THREAD_SINGLE`     |
| `KaTestrophe::main_thread_funneled`   | `MPI_THREAD_FUNNELED`   |
| `KaTestrophe::main_thread_serialized` | `MPI_THREAD_SERIALIZED` |
| `KaTestrophe::main_thread_multiple`   | `MPI_THREAD_MULTIPLE`   |

```cmake
add_executable(threaded_test threaded_test.cpp)

# initialize MPI with MPI_Init_thread(MPI_THREAD_MULTIPLE)
target_link_libraries(threaded_test PRIVATE KaTestrophe::main_thread_multiple)
katestrophe_add_mpi_test(threaded_test CORES 1 2 4)
```

Because an implementation may provide a lower level than requested, query what was actually provided
with `MPI_Query_thread` and skip otherwise:

```cpp
int provided = MPI_THREAD_SINGLE;
MPI_Query_thread(&provided);
if (provided < MPI_THREAD_MULTIPLE) {
  GTEST_SKIP() << "runtime does not provide MPI_THREAD_MULTIPLE";
}
```

### Test isolation and per-test communicators

When all tests of a binary run in one `mpiexec` call (i.e. without `DISCOVER_TESTS`), KaTestrophe
puts a barrier after every test. No rank starts a test before every rank has finished the previous one
and destroyed its objects. A rank still inside test N therefore never receives a message that a
faster rank sends for test N+1. KaTestrophe sends its own result reports on a duplicate of
`MPI_COMM_WORLD`, so they never interfere with messages of the tests.

The barrier does not remove messages that a test sends and never receives. If your code takes a
communicator, give each test its own with `KATESTROPHE_TEST`. The test then runs in the fixture
`katestrophe::MPITest`, which duplicates `MPI_COMM_WORLD` before the test and frees it afterwards:

```cpp
#include <katestrophe.hpp>

KATESTROPHE_TEST(MySuite, broadcast_works) {
  // comm: this test's own duplicate of MPI_COMM_WORLD; rank and size refer to it
  int value = rank == 0 ? 42 : 0;
  MPI_Bcast(&value, 1, MPI_INT, 0, comm);
  EXPECT_EQ(value, 42);
}

// or derive your own fixture and use TEST_F
class MyFixture : public katestrophe::MPITest {};
TEST_F(MyFixture, works) { /* uses comm, rank, size */ }
```

### Running more ranks than cores

Open MPI refuses to start more ranks than there are slots. KaTestrophe detects Open MPI from
`mpiexec --version` and then passes `--oversubscribe` (MPICH and Intel MPI oversubscribe without a
flag). Override the detected flag with `-DKATESTROPHE_MPIEXEC_OVERSUBSCRIBE_FLAG=...`.

To skip rank counts instead of oversubscribing, set `KATESTROPHE_MAX_CORES`. Tests registered with
more ranks are then not added to CTest. For example, to limit tests to the cores of the machine:

```cmake
find_package(MPI REQUIRED)
set(KATESTROPHE_MAX_CORES ${MPIEXEC_MAX_NUMPROCS}) # before FetchContent_MakeAvailable(KaTestrophe)
```

or from the command line: `cmake -DKATESTROPHE_MAX_CORES=4 ...`.

### Working directory

Tests run in `PROJECT_SOURCE_DIR` by default, with and without `DISCOVER_TESTS`. Pass
`WORKING_DIRECTORY <dir>` to `katestrophe_add_mpi_test` to change it.

## LICENSE
This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.


