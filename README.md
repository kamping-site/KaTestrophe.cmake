# KaTestrophe.cmake 🌋

CMake support for MPI-enabled GoogleTest. Helps you to easily define and run MPI tests via CTest with minimal boilerplate.

## Quickstart
### 1. Add to your project via FetchContent
```cmake
include(FetchContent)
FetchContent_Declare(
  KaTestrophe
  GIT_REPOSITORY https://github.com/kamping-site/KaTestrophe.cmake
  GIT_TAG        v1.0
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
level, build a dedicated main with `katestrophe_add_mpi_main` and link it instead:

```cmake
# a Google Test + MPI entry point initialized with MPI_Init_thread(MPI_THREAD_MULTIPLE)
katestrophe_add_mpi_main(my-mpi-main THREAD_LEVEL MPI_THREAD_MULTIPLE)

add_executable(threaded_test threaded_test.cpp)
target_link_libraries(threaded_test PRIVATE my-mpi-main)
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

## LICENSE
This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.


