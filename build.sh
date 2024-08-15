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

if [ "x$LLVM_PATCH" != "x" ]
then
  cp -r $LLVM_PATCH/* $LLVM_DIR
  echo "with patches" >> $INSTALL_DIR/llvm_tarball_checksum.txt
fi

BASE_CFLAGS="${BASE_CFLAGS:--O3 -g --target=riscv64 -march=rv64imc_zba_zbb_zbc_zbs -fdata-sections -ffunction-sections}"
LLVM_CMAKE_OPTIONS="${LLVM_CMAKE_OPTIONS:-}"

mkdir -p build
cd build
cmake .. \
  -DCMAKE_C_COMPILER="$CLANG" \
  -DCMAKE_CXX_COMPILER="$CLANGXX" \
  -DCMAKE_C_FLAGS="$BASE_CFLAGS -nostdinc --sysroot $MUSL -isystem $MUSL/include" \
  -DCMAKE_CXX_FLAGS="$BASE_CFLAGS -nostdinc --sysroot $MUSL -isystem $MUSL/include -D_GNU_SOURCE=1" \
  -DCMAKE_ASM_FLAGS="$BASE_CFLAGS" \
  -DCMAKE_SYSTEM_NAME="Generic" \
  -DCMAKE_C_COMPILER_WORKS=1 \
  -DCMAKE_CXX_COMPILER_WORKS=1 \
  -DCMAKE_INSTALL_PREFIX=$INSTALL_DIR \
  -DLLVM_ENABLE_RUNTIMES="libunwind;libcxxabi;libcxx" \
  -DLIBUNWIND_ENABLE_SHARED=OFF \
  -DLIBUNWIND_ENABLE_THREADS=OFF \
  -DLIBCXX_HAS_MUSL_LIBC=ON \
  -DLIBCXX_INCLUDE_BENCHMARKS=OFF \
  -DLIBCXX_ENABLE_ABI_LINKER_SCRIPT=OFF \
  -DLIBCXX_ENABLE_SHARED=OFF \
  -DLIBCXX_ENABLE_THREADS=OFF \
  -DLIBCXXABI_ENABLE_SHARED=OFF \
  -DLIBCXXABI_ENABLE_THREADS=OFF \
  -DLIBCXXABI_LIBUNWIND_PATH="$LLVM_DIR/libunwind" \
  $LLVM_CMAKE_OPTIONS
make -j2
make install
cd ..

if [ "x$DEBUG" = "x" ]
then
  rm -rf $LLVM_TARBALL
  rm -rf llvm_src
  rm -rf build
fi
