#!/usr/bin/env bash
set -ex

CLANG="${CLANG:-clang-18}"
LLVM_VERSION="${LLVM_VERSION:-18.1.8}"
MUSL="$(realpath "${MUSL:-../musl/release}")"
INSTALL_DIR="$(realpath "${INSTALL_DIR:-./release}")"

CLANGXX="${CLANG/clang/clang++}"
LLVM_TARBALL="llvmorg-${LLVM_VERSION}.tar.gz"

if ! [ -f $LLVM_TARBALL ]; then
  curl -LO https://github.com/llvm/llvm-project/archive/$LLVM_TARBALL
fi

mkdir -p $INSTALL_DIR
shasum -a 256 $LLVM_TARBALL > $INSTALL_DIR/llvm_tarball_checksum.txt

LLVM_DIR="$(realpath ./llvm_src)"
if ! [ -d llvm_src ]; then
  mkdir -p llvm_src
  cd llvm_src
  tar xzf ../$LLVM_TARBALL --strip-components=1
  cd ..
fi

COMMON_FLAGS="-O3 -g --target=riscv64 -march=rv64imc_zba_zbb_zbc_zbs -fdata-sections -ffunction-sections"

sed '/cmake_minimum_required/a project(LIBUNWIND LANGUAGES C CXX ASM)' llvm_src/libunwind/CMakeLists.txt > llvm_src/libunwind/CMakeLists.txt.patched
mv llvm_src/libunwind/CMakeLists.txt.patched llvm_src/libunwind/CMakeLists.txt
mkdir -p build/libunwind
cd build/libunwind
cmake $LLVM_DIR/libunwind \
  -DLIBUNWIND_ENABLE_SHARED=OFF \
  -DLIBUNWIND_ENABLE_THREADS=OFF \
  -DCMAKE_C_COMPILER="$CLANG" \
  -DCMAKE_CXX_COMPILER="$CLANGXX" \
  -DCMAKE_C_FLAGS="$COMMON_FLAGS -nostdinc --sysroot $MUSL -isystem $MUSL/include" \
  -DCMAKE_CXX_FLAGS="$COMMON_FLAGS -nostdinc --sysroot $MUSL -isystem $MUSL/include -D_GNU_SOURCE=1" \
  -DCMAKE_ASM_FLAGS="$COMMON_FLAGS" \
  -DCMAKE_CXX_COMPILER_WORKS=1 \
  -DCMAKE_INSTALL_PREFIX=$INSTALL_DIR
make -j2
make install
cd ../..

mkdir -p build/libcxx
cd build/libcxx
cmake $LLVM_DIR/libcxx \
  -DLIBCXX_HAS_MUSL_LIBC=ON \
  -DLIBCXX_INCLUDE_BENCHMARKS=OFF \
  -DLIBCXX_ENABLE_ABI_LINKER_SCRIPT=OFF \
  -DLIBCXX_ENABLE_SHARED=OFF \
  -DLIBCXX_ENABLE_THREADS=OFF \
  -DCMAKE_SYSTEM_NAME="Generic" \
  -DCMAKE_C_COMPILER="$CLANG" \
  -DCMAKE_CXX_COMPILER="$CLANGXX" \
  -DCMAKE_C_FLAGS="$COMMON_FLAGS -nostdinc --sysroot $MUSL -isystem $MUSL/include" \
  -DCMAKE_CXX_FLAGS="$COMMON_FLAGS -nostdinc --sysroot $MUSL -isystem $MUSL/include -isystem $LLVM_DIR/libcxxabi/include -D_GNU_SOURCE=1" \
  -DCMAKE_CXX_COMPILER_WORKS=1 \
  -DCMAKE_INSTALL_PREFIX=$INSTALL_DIR
make -j2
make install
cd ../..

mkdir -p build/libcxxabi
cd build/libcxxabi
cmake $LLVM_DIR/libcxxabi \
  -DLLVM_ENABLE_RUNTIMES=libunwind \
  -DLIBCXXABI_ENABLE_SHARED=OFF \
  -DLIBCXXABI_ENABLE_THREADS=OFF \
  -DCMAKE_C_COMPILER="$CLANG" \
  -DCMAKE_CXX_COMPILER="$CLANGXX" \
  -DCMAKE_C_FLAGS="$COMMON_FLAGS -nostdinc --sysroot $MUSL -isystem $MUSL/include" \
  -DCMAKE_CXX_FLAGS="$COMMON_FLAGS -nostdinc --sysroot $MUSL -isystem $INSTALL_DIR/include/c++/v1 -isystem $INSTALL_DIR/include -isystem $MUSL/include -D_GNU_SOURCE=1" \
  -DCMAKE_CXX_COMPILER_WORKS=1 \
  -DCMAKE_INSTALL_PREFIX=$INSTALL_DIR
make -j2
make install
cd ../..

if [ "x$DEBUG" = "x" ]
then
  rm -rf $LLVM_TARBALL
  rm -rf llvm_src
  rm -rf build
fi
