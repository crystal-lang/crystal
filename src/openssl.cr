require "./openssl/lib_ssl"
require "./openssl/error"

# The OpenSSL module allows for access to Secure Sockets Layer (SSL) and Transport Layer Security (TLS)
# encryption, as well as classes for encrypting data, decrypting data, and computing hashes. It uses
# the SSL library provided by the operating system, which may be either [OpenSSL](https://openssl.org)
# or [LibreSSL](https://www.libressl.org).
#
# WARNING: This module should not be used without first reading the [Security considerations](#security-considerations).
#
# To create secure sockets, use either `OpenSSL::SSL::Socket::Client` for client applications, or
# `OpenSSL::SSL::Socket::Server` for servers.  These classes use a default context, but you can provide
# your own by supplying an `OpenSSL::SSL::Context`.  For more control, consider subclassing `OpenSSL::SSL::Socket`.
#
# Hashing algorithms are provided by classes such as `Digest::SHA256` and `Digest::MD5`.  If you need
# a different option, you can initialize one using the name of the digest with `OpenSSL::Digest`.
# A Hash-based Message Authentication Code (HMAC) can be computed using `HMAC` and specifying a digest
# `Algorithm`.
#
# The `OpenSSL::Cipher` class can be used for encrypting and decrypting data.
#
# NOTE: To use `OpenSSL`, you must explicitly import it using the `require "openssl"` statement.
#
# ## Security Considerations
#
# Crystal aims to provide reasonable configuration defaults in accordance with
# [Mozilla's recommendations](https://wiki.mozilla.org/Security/Server_Side_TLS#Intermediate_compatibility_.28recommended.29).
# However, these defaults may not be suitable for your application.  It is recommended that you refer
# to the Open Worldwide Application Security Project (OWASP) cheat sheet on
# [implementing transport layer protection](https://cheatsheetseries.owasp.org/cheatsheets/Transport_Layer_Security_Cheat_Sheet.html)
# to ensure the appropriate configuration for your use.
#
# If you come across any shortcomings or spots for improvement in Crystal's configuration options,
# please don't hesitate to let us know by [opening an issue](https://github.com/crystal-lang/crystal/issues/new).
#
# ## Usage Example
#
# ### Server side
#
# An `SSL` server is created with a `TCPServer` and a `SSL::Context`.  You can then use the
# SSL server like an ordinary TCP server.
#
# NOTE: For the below example to work, a certificate and private key should be attained.
#
# ```
# require "openssl"
# require "socket"
#
# PORT = ENV["PORT"] ||= "5555"
#
# # Bind new TCPServer to PORT
# socket = TCPServer.new(PORT.to_i)
#
# context = OpenSSL::SSL::Context::Server.new
# context.private_key = "/path/to/private.key"
# context.certificate_chain = "/path/to/public.cert"
#
# puts "Server is up. Listening on port #{PORT}."
#
# socket.accept do |client|
#   puts "Got client"
#
#   bytes = Bytes.new(20)
#
#   OpenSSL::SSL::Socket::Server.open(client, context) do |ssl_socket|
#     ssl_socket.read(bytes)
#   end
#
#   puts "Client said: #{String.new(bytes)}"
# end
#
# socket.close
# puts "Server has stopped."
# ```
#
# ### Client side
#
# An `SSL` client is created with a `TCPSocket` and a `SSL::Context`. Unlike a SSL server,
# a client does not require a certificate or private key.
#
# NOTE: By default, closing an `SSL::Socket` does not close the underlying socket.  You need to
#       set `SSL::Socket#sync_close=` to true if you want this behaviour.
#
# ```
# require "openssl"
# require "socket"
#
# PORT = ENV["PORT"] ||= "5555"
#
# # Bind TCPSocket to PORT and open a connection
# TCPSocket.open("127.0.0.1", PORT) do |socket|
#   context = OpenSSL::SSL::Context::Client.new
#
#   OpenSSL::SSL::Socket::Client.open(socket, context) do |ssl_socket|
#     ssl_socket << "Hello from client!"
#   end
# end
# ```
module OpenSSL
  module SSL
    alias Modes = LibSSL::Modes
    alias Options = LibSSL::Options
    alias VerifyMode = LibSSL::VerifyMode
    alias ErrorType = LibSSL::SSLError
    {% if LibCrypto.has_constant?(:X509VerifyFlags) %}
      alias X509VerifyFlags = LibCrypto::X509VerifyFlags
    {% end %}

    class Error < OpenSSL::Error
      getter error : ErrorType
      getter? underlying_eof : Bool = false

      def initialize(ssl : LibSSL::SSL, return_code : LibSSL::Int, func = nil)
        @error = LibSSL.ssl_get_error(ssl, return_code)

        case @error
        when .none?
          message = "Raised erroneously"
        when .syscall?
          @code, message = fetch_error_details
          {% if LibSSL.has_constant?(:SSL_R_UNEXPECTED_EOF_WHILE_READING) %}
            if @code == 0
              # FIXME: this isn't a per the OpenSSL documentation for how to
              #        detect EOF, but this fixes the EOF detection spec...
              message = "Unexpected EOF while reading"
              @underlying_eof = true
            else
              cause = RuntimeError.from_errno(func || "OpenSSL")
            end
          {% else %}
            case return_code
            when 0
              message = "Unexpected EOF while reading"
              @underlying_eof = true
            when -1
              cause = RuntimeError.from_errno(func || "OpenSSL")
              message = "I/O error"
            else
              message = "Unknown error"
            end
          {% end %}
        when .ssl?
          code, message = fetch_error_details
          @code = code
          {% if LibSSL.has_constant?(:SSL_R_UNEXPECTED_EOF_WHILE_READING) %}
            if get_reason(code) == LibSSL::SSL_R_UNEXPECTED_EOF_WHILE_READING
              @underlying_eof = true
            end
          {% end %}
        else
          message = @error.to_s
        end

        super(func ? "#{func}: #{message}" : message, true, cause: cause)
      end
    end
  end
end

require "./openssl/bio"
require "./openssl/ssl/*"
require "./openssl/digest"
require "./openssl/md5"
require "./openssl/x509/x509"
require "./openssl/pkcs5"
require "./openssl/cipher"
