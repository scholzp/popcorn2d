cmake_minimum_required(VERSION 2.8)

project(popcorn2d CXX)

include(CheckCCompilerFlag)
include(CheckCXXCompilerFlag)

#scorep
# set_property(GLOBAL PROPERTY RULE_LAUNCH_COMPILE scorep)
# set_property(GLOBAL PROPERTY RULE_LAUNCH_LINK scorep)

set(SOURCES popcorn2d.cpp)

set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -std=c++11")

if("${CMAKE_CXX_COMPILER_ID}" STREQUAL "PGI")
  message(">>> Setting compiler flags for PGI compiler...")
  #set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -Minfo=accel -acc -ta=nvidia:kepler -ta=host")
  set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -Minfo=accel -acc -ta=nvidia:kepler")
endif()

add_executable(${PROJECT_NAME} ${SOURCES})
