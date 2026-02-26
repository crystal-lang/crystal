# Ported from OpenSSL include/internal/ktls.h private header to enable KTLS
# through a custom BIO so the actual TCP communication goes through the normal
# Crystal::EventLoop regardless of the socket's blocking mode.
#
# Copyright 2018-2024 The OpenSSL Project Authors. All Rights Reserved.
#
# Licensed under the Apache License 2.0 (the "License").  You may not use
# this file except in compliance with the License.  You can obtain a copy
# in the file LICENSE in the source distribution or at
# https://www.openssl.org/source/license.html

# libressl doesn't support Kernel TLS
{% skip_file if compare_versions(LibSSL::LIBRESSL_VERSION, "0.0.0") > 0 %}

# libevent evloop doesn't implement recvmsg/sendmsg
{% skip_file if Crystal::EventLoop.has_constant?(:LibEvent) %}

{% if flag?(:linux) %}
  require "c/linux/tls"
{% elsif flag?(:freebsd) %}
  require "c/sys/ktls"
{% else %}
  {% skip_file %}
{% end %}

require "c/netinet/tcp"
require "c/sys/socket"

module OpenSSL
  # :nodoc:
  module KTLS
    private CMSG_LEVEL =
      {% if flag?(:linux) %}
        LibC::SOL_TLS
      {% elsif flag?(:freebsd) %}
        LibC::IPPROTO_TCP
      {% end %}

    # When successful, this socket option doesn't change the behaviour of the
    # TCP socket, except changing the TCP setsockopt handler to enable the
    # processing of SOL_TLS socket options. All other functionality remains the
    # same.
    #
    # Socket must be in TCP established state to enable KTLS. Further calls to
    # enable ktls will return EEXIST
    def self.enable(socket : Socket) : Bool
      {% if flag?(:linux) %}
        LibC.setsockopt(socket.fd, LibC::SOL_TCP, LibC::TCP_ULP, "tls", "tls".bytesize) == 0
      {% elsif flag?(:freebsd) %}
        true
      {% end %}
    end

    def self.enable_tx_zerocopy_sendfile(socket : Socket) : Bool
      {% if flag?(:linux) %}
        enable = LibC::Int.new(1)
        LibC.setsockopt(socket.fd, LibC::SOL_TLS, LibC::TLS_TX_ZEROCOPY_RO, pointerof(enable), sizeof(LibC::Int)) == 0
      {% elsif flag?(:freebsd) %}
        true
      {% end %}
    end

    # The TLS_TX socket option changes the send/sendmsg handlers of the TCP
    # socket. If successful, then data sent using this socket will be encrypted
    # and encapsulated in TLS records using the crypto_info provided here.
    #
    # The TLS_RX socket option changes the recv/recvmsg handlers of the TCP
    # socket. If successful, then data received using this socket will be
    # decrypted, authenticated and decapsulated using the crypto_info provided
    # here.
    def self.start(socket : Socket, crypto_info : Pointer, is_tx : Bool) : Bool
      {% if flag?(:linux) %}
        if len = crypto_info_len(crypto_info)
          optname = is_tx ? LibC::TLS_TX : LibC::TLS_RX
          LibC.setsockopt(socket.fd, LibC::SOL_TLS, optname, crypto_info, len) == 0
        else
          return false
        end
      {% elsif flag?(:freebsd) %}
        optname = is_tx ? LibC::TCP_TXTLS_ENABLE : LibC::TCP_RXTLS_ENABLE
        LibC.setsockopt(socket.fd, LibC::IPPROTO_TCP, optname, crypto_info, sizeof(LibC::Tls_enable)) == 0
      {% end %}
    end

    {% if flag?(:linux) %}
      # OpenSSL uses an internal struct { union { cipher... }, len } and of
      # course the union size depends on how and where openssl has been built,
      # for example against which linux kernel headers.
      #
      # Hopefully 'struct crypto_info' puts the cipher version/type first, so
      # we can at least handle an allow list for currently supported ciphers.
      private def self.crypto_info_len(crypto_info)
        case type = crypto_info.as(LibC::Tls_crypto_info*).value.cipher_type
        when LibC::TLS_CIPHER_AES_GCM_128
          sizeof(LibC::Tls12_crypto_info_aes_gcm_128)
        when LibC::TLS_CIPHER_AES_GCM_256
          sizeof(LibC::Tls12_crypto_info_aes_gcm_256)
        when LibC::TLS_CIPHER_AES_CCM_128
          sizeof(LibC::Tls12_crypto_info_aes_ccm_128)
        when LibC::TLS_CIPHER_CHACHA20_POLY1305
          sizeof(LibC::Tls12_crypto_info_chacha20_poly1305)
        when LibC::TLS_CIPHER_SM4_GCM
          sizeof(LibC::Tls12_crypto_info_sm4_gcm)
        when LibC::TLS_CIPHER_SM4_CCM
          sizeof(LibC::Tls12_crypto_info_sm4_ccm)
        when LibC::TLS_CIPHER_ARIA_GCM_128
          sizeof(LibC::Tls12_crypto_info_aria_gcm_128)
        when LibC::TLS_CIPHER_ARIA_GCM_256
          sizeof(LibC::Tls12_crypto_info_aria_gcm_256)
        else
          # unknown TLS cipher (Linux 6.17, OpenSSL 3.6), check linux/tls.h and
          # 'struct tls_crypto_info_all' in openssl/include/internal/ktls.h
          STDERR.print "WARNING: unknown TLS cipher (skipping Kernel TLS)\n"
          nil
        end
      end
    {% end %}

    # Send a TLS record using the crypto_info provided in ktls_start and use
    # record_type instead of the default SSL3_RT_APPLICATION_DATA.
    # When the socket is non-blocking, then this call either returns EAGAIN or
    # the entire record is pushed to TCP. It is impossible to send a partial
    # record using this control message.
    def self.send_ctrl_message(socket : Socket, record_type : UInt8, data : UInt8*, length : Int32) : Int32 | Errno
      buf = uninitialized UInt8[24] # CMSG_SPACE(sizeof(record_type))

      cmsg = buf.to_unsafe.as(LibC::Cmsghdr*)
      cmsg.value.cmsg_level = CMSG_LEVEL
      cmsg.value.cmsg_type = LibC::TLS_SET_RECORD_TYPE
      cmsg.value.cmsg_len = sizeof(LibC::Cmsghdr) + sizeof(UInt8) # CMSG_LEN(sizeof(record_type))
      cmsg.value.cmsg_data.to_unsafe.value = record_type

      msg_iov = LibC::Iovec.new
      msg_iov.iov_base = data.as(Void*)
      msg_iov.iov_len = length

      msg = LibC::Msghdr.new
      msg.msg_control = buf.to_unsafe.as(Void*)
      msg.msg_controllen = cmsg.value.cmsg_len
      msg.msg_iov = pointerof(msg_iov)
      msg.msg_iovlen = 1

      Crystal::EventLoop.current.sendmsg(socket, pointerof(msg), 0)
    end

    # Receive a TLS record using the crypto_info provided in ktls_start.
    # The kernel strips the TLS record header, IV and authentication tag,
    # returning only the plaintext data or an error on failure.
    # We add the TLS record header here to satisfy routines in rec_layer_s3.c
    def self.read_record(socket : Socket, data : UInt8*, length : Int32) : Int32 | Errno
      buf = uninitialized UInt8[24] # CMSG_SPACE(sizeof(record_type))
      p = data.as(UInt8*)
      prepend_length = LibCrypto::SSL3_RT_HEADER_LENGTH

      if data_too_small?(length, prepend_length)
        return Errno::EINVAL
      end

      cdata_len =
        {% if flag?(:linux) %}
          sizeof(LibC::Char)
        {% elsif flag?(:freebsd) %}
          sizeof(LibC::Tls_get_record)
        {% end %}

      cmsg = buf.to_unsafe.as(LibC::Cmsghdr*)
      cmsg.value.cmsg_level = CMSG_LEVEL
      cmsg.value.cmsg_len = sizeof(LibC::Cmsghdr) + cdata_len # CMSGLEN(cdata_len)

      msg_iov = LibC::Iovec.new
      msg_iov.iov_base = (p + LibCrypto::SSL3_RT_HEADER_LENGTH).as(Void*)
      msg_iov.iov_len = iov_len(length - prepend_length)

      msg = LibC::Msghdr.new
      msg.msg_control = buf.to_unsafe.as(Void*)
      msg.msg_controllen = cmsg.value.cmsg_len
      msg.msg_iov = pointerof(msg_iov)
      msg.msg_iovlen = 1

      ret = Crystal::EventLoop.current.recvmsg(socket, pointerof(msg), 0)
      return ret if ret.is_a?(Errno)

      {% if flag?(:linux) %}
        if msg.msg_controllen > 0
          cmsg = msg.msg_control.as(LibC::Cmsghdr*)

          if cmsg.value.cmsg_type == LibC::TLS_GET_RECORD_TYPE
            p[0] = cmsg.value.cmsg_data.to_unsafe.value # tls record type
            p[1] = LibCrypto::TLS1_2_VERSION_MAJOR.to_u8!
            p[2] = LibCrypto::TLS1_2_VERSION_MINOR.to_u8!
            # returned length is limited to msg_iov.iov_len above
            p[3] = (ret >> 8).to_u8!
            p[4] = ret.to_u8!
            ret += prepend_length
          end
        end
      {% elsif flag?(:freebsd) %}
        if (msg.msg_flags & (LibC::MSG_EOR | LibC::MSG_CTRUNC)) != LibC::MSG_EOR
          return Errno::EMSGSIZE
        end

        if msg.msg_controllen == 0
          return Errno::EBADMSG
        end

        cmsg = msg.msg_control.as(LibC::Cmsghdr*)

        if cmsg.value.cmsg_level != LibC::IPPROTO_TCP ||
           cmsg.value.cmsg_type != LibC::TLS_GET_RECORD ||
           cmsg.value.cmsg_len != sizeof(LibC::Cmsghdr) + cdata_len # CMSGLEN(cdata_len)
          return Errno::EBADMSG
        end

        tgr = cmsg.value.cmsg_data.to_unsafe.as(LibC::Tls_get_record*)
        p[0] = tgr.value.tls_type
        p[1] = tgr.value.tls_vmajor
        p[2] = tgr.value.tls_vminor
        p[3] = (ret >> 8).to_u8!
        p[4] = ret.to_u8!

        ret += prepend_length
      {% end %}

      ret
    end

    private def self.data_too_small?(length, prepend_length)
      {% if flag?(:linux) %}
        length < prepend_length + LibCrypto::EVP_GCM_TLS_TAG_LEN
      {% elsif flag?(:freebsd) %}
        length <= prepend_length
      {% end %}
    end

    private def self.iov_len(length)
      {% if flag?(:linux) %}
        length - LibCrypto::EVP_GCM_TLS_TAG_LEN
      {% elsif flag?(:freebsd) %}
        length
      {% end %}
    end
  end
end
