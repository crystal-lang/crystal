#! /bin/sh

LIBNAME=$1

if [ -z $OPENSSL_DIR ]; then
    # use pkg-config if available:
    OPENSSL_CFLAGS=$(command -v pkg-config > /dev/null && pkg-config --cflags --silence-errors $LIBNAME)
else
    # use specified prefix:
    OPENSSL_CFLAGS="-I$OPENSSL_DIR/include"
fi

# extract version numbers from OpenSSL/LibreSSL C headers:
LIBRESSL_VERSION_NUMBER=$(printf "#include <openssl/opensslv.h>\nLIBRESSL_VERSION_NUMBER" | ${CC:-cc} $OPENSSL_CFLAGS -E - 2> /dev/null | tail -n 1)
OPENSSL_VERSION_NUMBER=$(printf "#include <openssl/opensslv.h>\nOPENSSL_VERSION_NUMBER" | ${CC:-cc} $OPENSSL_CFLAGS -E - 2> /dev/null | tail -n 1)

if [ $LIBRESSL_VERSION_NUMBER = LIBRESSL_VERSION_NUMBER ]; then
    # not libressl:
    echo LIBRESSL_VERSION_NUMBER = 0x0

    if [ $OPENSSL_VERSION_NUMBER = OPENSSL_VERSION_NUMBER ]; then
        echo '{% raise "Error: failed to find OpenSSL or LibreSSL development headers" %}'
    else
        # detected OpenSSL:
        echo OPENSSL_VERSION_NUMBER = $(echo $OPENSSL_VERSION_NUMBER | sed 's/L//')
    fi
else
    # detected LibreSSL:
    echo LIBRESSL_VERSION_NUMBER = $(echo $LIBRESSL_VERSION_NUMBER | sed 's/L//')
    echo OPENSSL_VERSION_NUMBER = 0x0
fi

if [ -z $OPENSSL_DIR ]; then
    echo LDFLAGS = nil
else
    # pass specified lib folder:
    echo LDFLAGS = \"-L$OPENSSL_DIR/lib\"
fi
