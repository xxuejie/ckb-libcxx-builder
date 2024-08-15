cmake_minimum_required(VERSION 3.20.0)
project(CKBLIBCXX C CXX ASM)
find_package(Python3 REQUIRED COMPONENTS Interpreter)

add_subdirectory(llvm_src/libunwind libunwind)
add_subdirectory(llvm_src/libcxxabi libcxxabi)
add_subdirectory(llvm_src/libcxx libcxx)
