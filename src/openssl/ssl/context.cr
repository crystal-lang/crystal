abstract class OpenSSL::SSL::Context
  class Client < Context
    # Generates a new SSL client context with sane defaults for a client connection.
    #
    # By default it defaults to the `SSLv23_method` which actually means that
    # OpenSSL will negotiate the TLS or SSL protocol to use with the remote
    # endpoint.
    #
    # Don't change the method unless you must restrict a specific protocol to be
    # used (eg: TLSv1.2) and nothing else. You should specify options to disable
    # specific protocols, yet allow to negotiate from various other ones. For
    # example the following snippet will enable the TLSv1, TLSv1.1 and TLSv1.2
    # protocols but disable the deprecated SSLv2 and SSLv3 protocols:
    #
    # ```
    # ssl_context = OpenSSL::SSL::Context::Client.new
    # ssl_context.options = LibSSL::Options::NO_SSLV2 | LibSSL::Options::NO_SSLV3
    # ```
    def initialize(method : LibSSL::SSLMethod = LibSSL.sslv23_method)
      super(method)
      set_default_verify_paths
      self.verify_mode = OpenSSL::SSL::VerifyMode::PEER
    end

    # Returns a new SSL client context with only the given method set.
    #
    # For everything else this uses the defaults of your OpenSSL.
    # Use this only if undoing the defaults that `new` sets is too much hassle.
    def self.insecure(method : LibSSL::SSLMethod = LibSSL.sslv23_method)
      super(method)
    end
  end

  class Server < Context
    # Generates a new SSL server context with sane defaults for a server connection.
    #
    # By default it defaults to the `SSLv23_method` which actually means that
    # OpenSSL will negotiate the TLS or SSL protocol to use with the remote
    # endpoint.
    #
    # Don't change the method unless you must restrict a specific protocol to be
    # used (eg: TLSv1.2) and nothing else. You should specify options to disable
    # specific protocols, yet allow to negotiate from various other ones. For
    # example the following snippet will enable the TLSv1, TLSv1.1 and TLSv1.2
    # protocols but disable the deprecated SSLv2 and SSLv3 protocols:
    #
    # ```
    # ssl_context = OpenSSL::SSL::Context::Server.new
    # ssl_context.options = LibSSL::Options::NO_SSLV2 | LibSSL::Options::NO_SSLV3
    # ```
    def initialize(method : LibSSL::SSLMethod = LibSSL.sslv23_method)
      super(method)
      set_default_verify_paths
    end

    # Returns a new SSL server context with only the given method set.
    #
    # For everything else this uses the defaults of your OpenSSL.
    # Use this only if undoing the defaults that `new` sets is too much hassle.
    def self.insecure(method : LibSSL::SSLMethod = LibSSL.sslv23_method)
      super(method)
    end
  end

  protected def initialize(method : LibSSL::SSLMethod)
    @handle = LibSSL.ssl_ctx_new(method)
    raise OpenSSL::Error.new("SSL_CTX_new") if @handle.null?
  end

  # Overriding initialize or new in the child classes as public methods,
  # makes it either impossible to access the parent versions or makes the parent
  # versions public too. So to provide insecure in the child classes, we need
  # a second constructor that we call from there without getting the
  # overridden ones of the childs.
  protected def _initialize_insecure(method : LibSSL::SSLMethod)
    @handle = LibSSL.ssl_ctx_new(method)
    raise OpenSSL::Error.new("SSL_CTX_new") if @handle.null?
  end

  protected def self.insecure(method : LibSSL::SSLMethod)
    obj = allocate
    obj._initialize_insecure(method)
    obj
  end

  def finalize
    LibSSL.ssl_ctx_free(@handle)
  end

  # Sets the default paths for `ca_certiifcates=` and `ca_certificates_path=`.
  def set_default_verify_paths
    LibSSL.ssl_ctx_set_default_verify_paths(@handle)
  end

  # Sets the path to a file containing all CA certificates, in PEM format, used to
  # validate the peers certificate.
  def ca_certificates=(file_path : String)
    ret = LibSSL.ssl_ctx_load_verify_locations(@handle, file_path, nil)
    raise OpenSSL::Error.new("SSL_CTX_load_verify_locations") unless ret == 1
  end

  # Sets the path to a directory containing all CA certificates used to
  # validate the peers certificate. The certificates should be in PEM format
  # and the `c_rehash(1)` utility must have been run in the directory.
  def ca_certificates_path=(dir_path : String)
    ret = LibSSL.ssl_ctx_load_verify_locations(@handle, nil, dir_path)
    raise OpenSSL::Error.new("SSL_CTX_load_verify_locations") unless ret == 1
  end

  # Specify the path to the certificate chain file to use. In server mode this
  # is presented to the client, in client mode this used as client certificate.
  def certificate_chain=(file_path)
    ret = LibSSL.ssl_ctx_use_certificate_chain_file(@handle, file_path)
    raise OpenSSL::Error.new("SSL_CTX_use_certificate_chain_file") unless ret == 1
  end

  # Specify the path to the private key to use. The key must in PEM format.
  # The key must correspond to the entity certificate set by `certificate_chain=`.
  def private_key=(file_path)
    ret = LibSSL.ssl_ctx_use_privatekey_file(@handle, file_path, LibSSL::SSLFileType::PEM)
    raise OpenSSL::Error.new("SSL_CTX_use_PrivateKey_file") unless ret == 1
  end

  # Specify a list of SSL ciphers to use or discard.
  def ciphers=(ciphers : String)
    ret = LibSSL.ssl_ctx_set_cipher_list(@handle, ciphers)
    raise OpenSSL::Error.new("SSL_CTX_set_cipher_list") if ret == 0
    ciphers
  end

  # Adds a temporary ECDH key curve to the SSL context. This is required to
  # enable the EECDH cipher suites. By default the prime256 curve will be used.
  def set_tmp_ecdh_key(curve = LibCrypto::NID_X9_62_prime256v1)
    key = LibCrypto.ec_key_new_by_curve_name(curve)
    raise OpenSSL::Error.new("ec_key_new_by_curve_name") if key.null?
    LibSSL.ssl_ctx_ctrl(@handle, LibSSL::SSL_CTRL_SET_TMP_ECDH, 0, key)
    LibCrypto.ec_key_free(key)
  end

  # Returns the current modes set on the SSL context.
  def modes
    LibSSL::Modes.new LibSSL.ssl_ctx_ctrl(@handle, LibSSL::SSL_CTRL_MODE, 0, nil)
  end

  # Adds modes to the SSL context.
  def add_modes(mode : LibSSL::Modes)
    LibSSL::Modes.new LibSSL.ssl_ctx_ctrl(@handle, LibSSL::SSL_CTRL_MODE, mode, nil)
  end

  # Removes modes from the SSL context.
  def remove_modes(mode : LibSSL::Modes)
    LibSSL::Modes.new LibSSL.ssl_ctx_ctrl(@handle, LibSSL::SSL_CTRL_CLEAR_MODE, mode, nil)
  end

  # Returns the current options set on the SSL context.
  def options
    LibSSL::Options.new LibSSL.ssl_ctx_ctrl(@handle, LibSSL::SSL_CTRL_OPTIONS, 0, nil)
  end

  # Adds options to the SSL context.
  #
  # Example:
  # ```
  # ssl_context.add_options(
  #   LibSSL::Options::ALL |        # various workarounds
  #     LibSSL::Options::NO_SSLV2 | # disable overly deprecated SSLv2
  #     LibSSL::Options::NO_SSLV3   # disable deprecated SSLv3
  # )
  # ```
  def add_options(options : LibSSL::Options)
    LibSSL::Options.new LibSSL.ssl_ctx_ctrl(@handle, LibSSL::SSL_CTRL_OPTIONS, options, nil)
  end

  # Removes options from the SSL context.
  #
  # Example:
  # ```
  # ssl_context.remove_options(LibSSL::SSL_OP_NO_SSLV3)
  # ```
  def remove_options(options : LibSSL::Options)
    LibSSL::Options.new LibSSL.ssl_ctx_ctrl(@handle, LibSSL::SSL_CTRL_CLEAR_OPTIONS, options, nil)
  end

  @alpn_protocol : Pointer(Void)?

  # Specifies an ALPN protocol to negotiate with the remote endpoint. This is
  # required to negotiate HTTP/2 with browsers, since browser vendors decided
  # not to implement HTTP/2 over insecure connections.
  #
  # Example:
  # ```
  # ssl_context.alpn_protocol = "h2"
  # ```
  def alpn_protocol=(protocol : String)
    proto = Slice(UInt8).new(protocol.bytesize + 1)
    proto[0] = protocol.bytesize.to_u8
    protocol.to_slice.copy_to(proto.to_unsafe + 1, protocol.bytesize)
    self.alpn_protocol = proto
  end

  # Returns the current verify mode. See the `SSL_CTX_set_verify(3)` manpage for more details.
  def verify_mode
    LibSSL.ssl_ctx_get_verify_mode(@handle)
  end

  # Sets the verify mode. See the `SSL_CTX_set_verify(3)` manpage for more details.
  def verify_mode=(mode : OpenSSL::SSL::VerifyMode)
    LibSSL.ssl_ctx_set_verify(@handle, mode, nil)
  end

  private def alpn_protocol=(protocol : Slice(UInt8))
    alpn_cb = ->(ssl : LibSSL::SSL, o : LibC::Char**, olen : LibC::Char*, i : LibC::Char*, ilen : LibC::Int, data : Void*) {
      proto = Box(Slice(UInt8)).unbox(data)
      ret = LibSSL.ssl_select_next_proto(o, olen, proto, 2, i, ilen)
      if ret != LibSSL::OPENSSL_NPN_NEGOTIATED
        LibSSL::SSL_TLSEXT_ERR_NOACK
      else
        LibSSL::SSL_TLSEXT_ERR_OK
      end
    }
    @alpn_protocol = alpn_protocol = Box.box(protocol)
    LibSSL.ssl_ctx_set_alpn_select_cb(@handle, alpn_cb, alpn_protocol)
  end

  def to_unsafe
    @handle
  end
end
