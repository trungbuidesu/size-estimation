cmake_minimum_required(VERSION 3.10)
project(photogrammetry)

# Set C++ standard
set(CMAKE_CXX_STANDARD 14)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Find OpenCV
# Users must set OpenCV_DIR if it's not in standard paths
find_package(OpenCV REQUIRED)

# Find Android Log Library
find_library(log-lib log)

# Include OpenCV directories
include_directories(${OpenCV_INCLUDE_DIRS})

# Create the shared library
add_library(photogrammetry SHARED photogrammetry.cpp)

# Link OpenCV libraries and log library
target_link_libraries(photogrammetry ${OpenCV_LIBS} ${log-lib})

# For Windows/MSVC, ensure standard export behavior if needed (already handled by __declspec in code)
if (MSVC)
    target_compile_results(photogrammetry PRIVATE "/EHsc") # Enable C++ exceptions
endif()
