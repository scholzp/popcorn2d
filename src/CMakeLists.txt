cmake_minimum_required(VERSION 2.8)

project(popcorn2d CXX)

include(CheckCCompilerFlag)
include(CheckCXXCompilerFlag)

set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -std=c++11")

set(SOURCES popcorn2d.cpp CsvWriter.cpp)

if("${CMAKE_CXX_COMPILER_ID}" STREQUAL "PGI")
  message(">>> Setting compiler flags for PGI compiler...")

  add_executable(${PROJECT_NAME} ${SOURCES})
  set_target_properties(${PROJECT_NAME} PROPERTIES COMPILE_FLAGS "-noacc")

  add_executable(${PROJECT_NAME}_kepler ${SOURCES})
  set_target_properties(${PROJECT_NAME}_kepler PROPERTIES
    COMPILE_FLAGS "-Minfo=accel -acc -ta=tesla:cc35,nordc" # ta by pgaccelinfo, and no RDC which is default in PGI, see http://stackoverflow.com/a/38214143
    LINK_FLAGS "-laccapi -laccg -laccn -laccg2 -ldl")

  set(CMAKE_CXX_FLAGS "-Minfo=accel -acc -ta=multicore -std=c++11")
  add_executable(${PROJECT_NAME}_multicore ${SOURCES})

else()
  add_executable(${PROJECT_NAME} ${SOURCES})
endif()


find_package(CUDA REQUIRED)

if(CUDA_FOUND AND CMAKE_CXX_COMPILER_ID MATCHES "^(GNU|Clang)$")
  CHECK_CXX_COMPILER_FLAG("-std=c++11" HAS_CPP11_FLAG)
  if (HAS_CPP11_FLAG)
    set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -std=c++11")
  else()
    message(FATAL_ERROR "this requires C++11 support!")
  endif()

  set(CUDA_PROPAGATE_HOST_FLAGS OFF)
  list(APPEND CUDA_NVCC_FLAGS "-std=c++11") #--ftz=false") # || --use_fast_math

  set(GENCODE_SM30 -gencode=arch=compute_30,code=sm_30 -gencode=arch=compute_30,code=compute_30)
  set(GENCODE_SM35 -gencode=arch=compute_35,code=sm_35 -gencode=arch=compute_35,code=compute_35)
  set(GENCODE_SM37 -gencode=arch=compute_37,code=sm_37 -gencode=arch=compute_37,code=compute_37)
  set(GENCODE_SM50 -gencode=arch=compute_50,code=sm_50 -gencode=arch=compute_50,code=compute_50)
  set(GENCODE_SM60 -gencode=arch=compute_60,code=sm_60 -gencode=arch=compute_60,code=compute_60)
  set(GENCODE_SM61 -gencode=arch=compute_61,code=sm_61 -gencode=arch=compute_61,code=compute_61)

  option(CUDA_VERBOSE_PTXAS
    "On to enable verbose output from the PTXAS assembler."
    OFF
    )

  option(POPCORN_GENCODE_SM30
    "ON to generate code for Compute Capability 3.0 devices (e.g. Tesla K10)"
    ON)

  option(POPCORN_GENCODE_SM35
    "ON to generate code for Compute Capability 3.5 devices (e.g. Tesla K20)"
    OFF)

  option(POPCORN_GENCODE_SM37
    "ON to generate code for Compute Capability 3.7 devices (e.g. Tesla K80)"
    OFF)

  option(POPCORN_GENCODE_SM50
    "ON to generate code for Compute Capability 5.0 devices (e.g. GeForce GTX 750)"
    OFF)

  option(POPCORN_GENCODE_SM52
    "ON to generate code for Compute Capability 5.2 devices (e.g. GeForce GTX 980)"
    OFF)

  option(POPCORN_GENCODE_SM60
    "ON to generate code for Compute Capability 6.0 devices (e.g. P100)"
    OFF)

  option(POPCORN_GENCODE_SM61
    "ON to generate code for Compute Capability 6.1 devices (e.g. GTX 1080)"
    OFF)

  if (POPCORN_GENCODE_SM30)
    set(GENCODE ${GENCODE} ${GENCODE_SM30})
  endif(POPCORN_GENCODE_SM30)

  if (POPCORN_GENCODE_SM35)
    set(GENCODE ${GENCODE} ${GENCODE_SM35})
  endif(POPCORN_GENCODE_SM35)

  if (POPCORN_GENCODE_SM37)
    set(GENCODE ${GENCODE} ${GENCODE_SM37})
  endif(POPCORN_GENCODE_SM37)

  if (POPCORN_GENCODE_SM50)
    set(GENCODE ${GENCODE} ${GENCODE_SM50})
  endif(POPCORN_GENCODE_SM50)

  if (POPCORN_GENCODE_SM52)
    set(GENCODE ${GENCODE} ${GENCODE_SM52})
  endif(POPCORN_GENCODE_SM52)

  if (POPCORN_GENCODE_SM60)
    set(GENCODE ${GENCODE} ${GENCODE_SM60})
  endif(POPCORN_GENCODE_SM60)

  if (POPCORN_GENCODE_SM61)
    set(GENCODE ${GENCODE} ${GENCODE_SM61})
  endif(POPCORN_GENCODE_SM61)

  if (CUDA_VERBOSE_PTXAS)
    set(VERBOSE_PTXAS --ptxas-options=-v)
  endif (CUDA_VERBOSE_PTXAS)

  cuda_add_executable(${PROJECT_NAME}_cuda popcorn2d.cu CsvWriter.cpp OPTIONS ${GENCODE} ${VERBOSE_PTXAS})
endif()
