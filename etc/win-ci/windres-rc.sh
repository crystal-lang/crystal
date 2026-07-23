#! /bin/sh
# Minimal wrapper for Microsoft rc.exe

# This wrapper is necessary for libiconv, since by default Cygwin will use
# x86_64-w64-mingw32-windres to build the library's resource file, even on an
# ARM64 Windows host, leading to an MSVC linker error about architecture
# mismatch. The build will call something like:
#
#     /bin/sh ../libtool --mode=compile --tag=RC ${RC-:windres} \
#       `/bin/sh ./../windows/windres-options --escape 1.19` \
#       -i ./../windows/libiconv.rc -o libiconv.res.lo --output-format=coff
#
# which becomes:
#
#     windres -DPACKAGE_VERSION_STRING=\\\"1.19\\\" \
#       -DPACKAGE_VERSION_MAJOR=1 \
#       -DPACKAGE_VERSION_MINOR=19 \
#       -DPACKAGE_VERSION_SUBMINOR=0 \
#       -i ./../windows/libiconv.rc --output-format=coff -o libiconv.res.obj
#
# the corresponding rc.exe invocation is:
#
#     rc.exe /NOLOGO -DPACKAGE_VERSION_STRING=\"1.19\" \
#       -DPACKAGE_VERSION_MAJOR=1 \
#       -DPACKAGE_VERSION_MINOR=19 \
#       -DPACKAGE_VERSION_SUBMINOR=0 \
#       /FO libiconv.res.obj libiconv.rc

RC=$1
input=
output=
defines=""

while [ $# -gt 0 ]
do
  case $1 in
    -D* | -d*)
      defines="$1 ${defines}"
      shift
      ;;
    -i)
      shift
      input=$1
      shift
      ;;
    -o)
      shift
      output=$1
      shift
      ;;
    *)
      # ignore --output-format=coff as it is the default already
      shift
      ;;
  esac
done

# shellcheck disable=SC2086
$RC -NOLOGO $defines -FO "$output" "$input"
