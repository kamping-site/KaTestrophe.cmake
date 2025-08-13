add_executable(simple_test simple_test.cpp)

# link the KatTestrophe library, which ensure that MPI is initialized and finalized correctly
# before and after the test and provides the main function for the test
target_link_libraries(simple_test PRIVATE KaTestrophe::main)

# register the test with CTest and execute it using MPI with 1 to 4 processes
katestrophe_add_mpi_test(simple_test CORES 1 2 3 4)

# Register the test with CTest and execute it using MPI with 1 to 4 processes
# The DISCOVER_TESTS option allows CTest to discover the test and outputs each test run individually
# in the CTest output, similar to Google Test's gtest_discover_tests.
katestrophe_add_mpi_test(simple_test CORES 1 2 3 4 DISCOVER_TESTS)
