# Usage from CMake:
# set (MAX_COMPILER_MEMORY 2000 CACHE INTERNAL "") # megabyte
# set (MAX_LINKER_MEMORY 3500 CACHE INTERNAL "") # megabyte
# include (cmake/limit_jobs.cmake)

cmake_host_system_information(RESULT TOTAL_PHYSICAL_MEMORY QUERY TOTAL_PHYSICAL_MEMORY) # Not available under freebsd
cmake_host_system_information(RESULT NUMBER_OF_LOGICAL_CORES QUERY NUMBER_OF_LOGICAL_CORES)

# Set to disable the automatic job-limiting
option(PARALLEL_COMPILE_JOBS "Maximum number of concurrent compilation jobs" OFF)
option(PARALLEL_LINK_JOBS "Maximum number of concurrent link jobs" OFF)

if (NOT PARALLEL_COMPILE_JOBS AND TOTAL_PHYSICAL_MEMORY AND MAX_COMPILER_MEMORY)
    math(EXPR PARALLEL_COMPILE_JOBS ${TOTAL_PHYSICAL_MEMORY}/${MAX_COMPILER_MEMORY})

    if (NOT PARALLEL_COMPILE_JOBS)
        set (PARALLEL_COMPILE_JOBS 1)
    endif ()
    if (NOT NUMBER_OF_LOGICAL_CORES OR PARALLEL_COMPILE_JOBS LESS NUMBER_OF_LOGICAL_CORES)
        set (PARALLEL_COMPILE_JOBS_UNDERUTILIZING TRUE)
    endif()
endif ()

if (NOT PARALLEL_LINK_JOBS AND TOTAL_PHYSICAL_MEMORY AND MAX_LINKER_MEMORY)
    math(EXPR PARALLEL_LINK_JOBS ${TOTAL_PHYSICAL_MEMORY}/${MAX_LINKER_MEMORY})

    if (NOT PARALLEL_LINK_JOBS)
        set (PARALLEL_LINK_JOBS 1)
    endif ()
    if (NOT NUMBER_OF_LOGICAL_CORES OR PARALLEL_LINK_JOBS LESS NUMBER_OF_LOGICAL_CORES)
        set (PARALLEL_LINK_JOBS_UNDERUTILIZING TRUE)
    endif()
endif ()

# ThinLTO provides its own parallel linking
# (which is enabled only for RELWITHDEBINFO)
#
# But use 2 parallel jobs, since:
# - this is what llvm does
# - and I've verfied that lld-11 does not use all available CPU time (in peak) while linking one binary
if (CMAKE_BUILD_TYPE_UC STREQUAL "RELWITHDEBINFO" AND ENABLE_THINLTO AND PARALLEL_LINK_JOBS GREATER 2)
    message(STATUS "ThinLTO provides its own parallel linking - limiting parallel link jobs to 2.")
    set (PARALLEL_LINK_JOBS 2)
endif()

message(STATUS "System has ${NUMBER_OF_LOGICAL_CORES} logical cores and ${TOTAL_PHYSICAL_MEMORY} megabytes of memory. Building with ${PARALLEL_COMPILE_JOBS} compile jobs and ${PARALLEL_COMPILE_JOBS} linker jobs.")

if (PARALLEL_COMPILE_JOBS OR PARALLEL_LINK_JOBS)
    if (PARALLEL_COMPILE_JOBS_UNDERUTILIZING)
        message(WARNING "The autocalculated compile jobs limit (${PARALLEL_COMPILE_JOBS}) underutilizes CPU cores (${NUMBER_OF_LOGICAL_CORES}). Set PARALLEL_COMPILE_JOBS to override.")
    endif()
    if (PARALLEL_LINK_JOBS_UNDERUTILIZING)
        message(WARNING "The autocalculated link jobs limit (${PARALLEL_LINK_JOBS}) underutilizes CPU cores (${NUMBER_OF_LOGICAL_CORES}). Set PARALLEL_LINK_JOBS to override.")
    endif()
endif ()

if (PARALLEL_COMPILE_JOBS AND (NOT NUMBER_OF_LOGICAL_CORES OR PARALLEL_COMPILE_JOBS LESS NUMBER_OF_LOGICAL_CORES))
    set(CMAKE_JOB_POOL_COMPILE compile_job_pool${CMAKE_CURRENT_SOURCE_DIR})
    string (REGEX REPLACE "[^a-zA-Z0-9]+" "_" CMAKE_JOB_POOL_COMPILE ${CMAKE_JOB_POOL_COMPILE})
    set_property(GLOBAL APPEND PROPERTY JOB_POOLS ${CMAKE_JOB_POOL_COMPILE}=${PARALLEL_COMPILE_JOBS})
endif ()

if (PARALLEL_LINK_JOBS AND (NOT NUMBER_OF_LOGICAL_CORES OR PARALLEL_LINK_JOBS LESS NUMBER_OF_LOGICAL_CORES))
    set(CMAKE_JOB_POOL_LINK link_job_pool${CMAKE_CURRENT_SOURCE_DIR})
    string (REGEX REPLACE "[^a-zA-Z0-9]+" "_" CMAKE_JOB_POOL_LINK ${CMAKE_JOB_POOL_LINK})
    set_property(GLOBAL APPEND PROPERTY JOB_POOLS ${CMAKE_JOB_POOL_LINK}=${PARALLEL_LINK_JOBS})
endif ()

