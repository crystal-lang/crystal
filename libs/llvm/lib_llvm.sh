#!/usr/bin/env bash

if [ "$LLVM_CONFIG" = "" ]; then
  which llvm-config-3.3 > /dev/null
  if [ $? = 0 ]; then
    LLVM_CONFIG="llvm-config-3.3"
  else
    LLVM_CONFIG="llvm-config"
  fi
fi

# Verify llvm-config is actually out there
which $LLVM_CONFIG > /dev/null
if [ $? != 0 ]; then exit 1; fi

$LLVM_CONFIG --libs
$LLVM_CONFIG --ldflags

case `uname -s` in
  Darwin)
    echo -lc++ -lstdc++
    ;;
  *)
    echo -lstdc++
    ;;
esac

