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
  add_executable(${PROJECT_NAME} ${SOURCES})
  set_target_properties(${PROJECT_NAME} PROPERTIES COMPILE_FLAGS "-ta=host")

  add_executable(${PROJECT_NAME}_kepler ${SOURCES})
  set_target_properties(${PROJECT_NAME}_kepler PROPERTIES
    COMPILE_FLAGS "-Minfo=accel -acc -ta=nvidia:kepler"
    LINK_FLAGS "-laccapi -laccg -laccn -laccg2 -ldl")

  add_executable(${PROJECT_NAME}_multicore ${SOURCES})
  set_target_properties(${PROJECT_NAME}_multicore PROPERTIES
    COMPILE_FLAGS "-Minfo=accel -acc -ta=multicore"
    LINK_FLAGS "-laccapi -laccg -laccn -laccg2 -ldl")
endif()
