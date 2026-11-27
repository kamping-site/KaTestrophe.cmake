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

# More ranks than a typical CI runner has cores: exercises --oversubscribe with Open MPI, and
# is skipped when KATESTROPHE_MAX_CORES is smaller.
katestrophe_add_mpi_test(simple_test CORES 8)

# Consecutive tests in one binary must be isolated (issue #7); this only shows up when all tests run
# in the same process, i.e. without DISCOVER_TESTS.
add_executable(isolation_test isolation_test.cpp)
target_link_libraries(isolation_test PRIVATE KaTestrophe::main)
katestrophe_add_mpi_test(isolation_test CORES 2 4)

# Per-test communicators via katestrophe::MPITest / KATESTROPHE_TEST.
add_executable(comm_fixture_test comm_fixture_test.cpp)
target_link_libraries(comm_fixture_test PRIVATE KaTestrophe::main)
katestrophe_add_mpi_test(comm_fixture_test CORES 1 2 4)
