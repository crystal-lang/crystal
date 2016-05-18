require "./lib_crypto"

@[Link("ssl")]
lib LibSSL
  alias Int = LibC::Int

  type SSLMethod = Void*
  type SSLContext = Void*
  type SSL = Void*

  enum SSLFileType
    PEM  = 1
    ASN1 = 2
  end

  fun ssl_load_error_strings = SSL_load_error_strings
  fun ssl_library_init = SSL_library_init
  fun sslv23_method = SSLv23_method : SSLMethod
  fun ssl_ctx_new = SSL_CTX_new(method : SSLMethod) : SSLContext
  fun ssl_ctx_free = SSL_CTX_free(context : SSLContext)

  @[Raises]
  fun ssl_new = SSL_new(context : SSLContext) : SSL

  @[Raises]
  fun ssl_connect = SSL_connect(handle : SSL) : Int

  @[Raises]
  fun ssl_accept = SSL_accept(handle : SSL) : Int

  @[Raises]
  fun ssl_write = SSL_write(handle : SSL, text : UInt8*, length : Int) : Int

  @[Raises]
  fun ssl_read = SSL_read(handle : SSL, buffer : UInt8*, read_size : Int) : Int

  @[Raises]
  fun ssl_shutdown = SSL_shutdown(handle : SSL) : Int

  fun ssl_free = SSL_free(handle : SSL)
  fun ssl_ctx_use_certificate_chain_file = SSL_CTX_use_certificate_chain_file(ctx : SSLContext, file : UInt8*) : Int
  fun ssl_ctx_use_privatekey_file = SSL_CTX_use_PrivateKey_file(ctx : SSLContext, file : UInt8*, filetype : SSLFileType) : Int
  fun ssl_set_bio = SSL_set_bio(handle : SSL, rbio : LibCrypto::Bio*, wbio : LibCrypto::Bio*)
end

LibSSL.ssl_library_init
LibSSL.ssl_load_error_strings
LibCrypto.openssl_add_all_algorithms
LibCrypto.err_load_crypto_strings
