#!/bin/sh

set -eo pipefail

Version=$1
Dynamic=$2

export PATH="$(pwd)/build-aux:$PATH"
export CC="$(pwd)/build-aux/compile cl -nologo"
export CXX="$(pwd)/build-aux/compile cl -nologo"
export AR="$(pwd)/build-aux/ar-lib lib"
export LD="link"
export NM="dumpbin -symbols"
export STRIP=":"
export RANLIB=":"
if [ -n "$Dynamic" ]; then
  export CFLAGS="-MD"
  export CXXFLAGS="-MD"
  enable_shared=yes
  enable_static=no
else
  export CFLAGS="-MT"
  export CXXFLAGS="-MT"
  enable_shared=no
  enable_static=yes
  # GNU libiconv appears to define `BUILDING_DLL` unconditionally, so the static
  # library contains `/EXPORT` directives that make any executable also export
  # the iconv symbols, which we don't want
  find . '(' -name '*.h' -or -name '*.h.build.in' ')' -print0 | xargs -0 -i sed -i 's/__declspec(dllexport)//' '{}'
fi
export CPPFLAGS="-O2 -D_WIN32_WINNT=_WIN32_WINNT_WIN7 -I$(pwd)/iconv/include"
export LDFLAGS="-L$(pwd)/iconv/lib"

./configure --host=x86_64-w64-mingw32 --prefix="$(pwd)/iconv" --enable-shared="${enable_shared}" --enable-static="${enable_static}"
make
make install
