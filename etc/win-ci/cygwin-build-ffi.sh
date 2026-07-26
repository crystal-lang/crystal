#!/bin/sh
# shellcheck disable=SC2155

set -e

Dynamic=$1

case "$(uname)" in
  *-ARM64)
    host=aarch64-w64-mingw32
    mflag=-marm64
    ;;
  *)
    host=x86_64-w64-mingw32
    mflag=-m64
    ;;
esac

export CC="$(pwd)/msvcc.sh ${mflag}"
export CXX="$(pwd)/msvcc.sh ${mflag}"
export CPP="cl -nologo -EP"
export CXXCPP="cl -nologo -EP"
export AR="$(pwd)/.ci/ar-lib lib"
export LD="link -nologo"
export NM="dumpbin -symbols"
export STRIP=":"
if [ -n "$Dynamic" ]; then
  export CFLAGS="-DFFI_BUILDING_DLL"
  export CXXFLAGS="-DFFI_BUILDING_DLL"
  export CPPFLAGS="-DFFI_BUILDING_DLL"
  enable_shared=yes
  enable_static=no
else
  export CFLAGS="-DFFI_BUILDING_DLL -DUSE_STATIC_RTL"
  export CXXFLAGS="-DFFI_BUILDING_DLL -DUSE_STATIC_RTL"
  export CPPFLAGS="-DFFI_BUILDING_DLL -DUSE_STATIC_RTL"
  enable_shared=no
  enable_static=yes
fi
export LDFLAGS="-no-undefined"

./configure --host="${host}" --prefix="$(pwd)/ffi" --enable-shared="${enable_shared}" --enable-static="${enable_static}" --disable-docs
make
# `make install` does not work with the `msvcc.sh` wrapper
mkdir ffi
if [ -n "$Dynamic" ]; then
  cp "$(find "${host}/.libs" -name 'libffi-?.dll')" ffi/
  cp "$(find "${host}/.libs" -name 'libffi-?.lib')" ffi/libffi.lib
else
  cp "${host}/.libs/libffi.lib" ffi/
fi
