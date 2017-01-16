require "./openssl/lib_ssl"

# # OpenSSL Integration
#
# - TLS sockets need a context, potentially with keys (required for servers) and configuration.
# - TLS sockets will wrap the underlying TCP socket, and any further communication must happen through the OpenSSL::SSL::Socket only.
#
# ## Usage Example
# - Note: for the below "server" example to work, a key pair should be attained
#
# Recommended ciphers can be taken from
# - https://www.owasp.org/index.php/Transport_Layer_Protection_Cheat_Sheet#Rule_-_Only_Support_Strong_Cryptographic_Ciphers
# - https://cipherli.st/
# - Full list is available at: https://wiki.openssl.org/index.php/Manual:Ciphers(1)#CIPHER_STRINGS
#
# Do note that
# - Crystal does its best to provide sane configuration defaults (see [Mozilla-Intermediate](https://wiki.mozilla.org/Security/Server_Side_TLS#Intermediate_compatibility_.28default.29))
# - Linked version of OpenSSL need to be checked for supporting specific protocols and ciphers
# - If any configurations or choices in Crystal regarding SSL settings and security are found to be lacking or need
#   improvement please open an issue and let us know
#
# ### Server side
#
# ```
# require "socket"
# require "openssl"
#
# def server
#   socket = TCPServer.new(5555) # Bind new TCPSocket to port 5555
#   context = OpenSSL::SSL::Context::Server.new
#   context.private_key = "/path/to/private.key"
#   context.certificate_chain = "/path/to/public.cert"
#   puts "server is up"
#   socket.accept do |client|
#     puts "got client"
#     ssl_socket = OpenSSL::SSL::Socket::Server.new(client, context)
#     slice = Slice(UInt8).new(20)
#     ssl_socket.read(slice)
#     puts String.new(slice)
#   end
# end
# ```
#
# ### Client side
#
# ```
# require "socket"
# require "openssl"
#
# def client
#   socket = TCPSocket.new("127.0.0.1", 5555)
#   context = OpenSSL::SSL::Context::Client.new
#   ssl_socket = OpenSSL::SSL::Socket::Client.new(socket, context)
#   ssl_socket.write("Testing".to_slice)
# end
# ```
module OpenSSL
  class Error < Exception
    getter! code : LibCrypto::ULong?

    def initialize(message = nil, fetched = false)
      @code ||= LibCrypto::ULong.new(0)

      if fetched
        super(message)
      else
        @code, error = fetch_error_details
        super(message ? "#{message}: #{error}" : error)
      end
    end

    protected def fetch_error_details
      code = LibCrypto.err_get_error
      message = String.new(LibCrypto.err_error_string(code, nil)) unless code == 0
      {code, message || "Unknown or no error"}
    end
  end

  module SSL
    alias Modes = LibSSL::Modes
    alias Options = LibSSL::Options
    alias VerifyMode = LibSSL::VerifyMode
    alias ErrorType = LibSSL::SSLError
    {% if LibSSL::OPENSSL_102 %}
    alias X509VerifyFlags = LibCrypto::X509VerifyFlags
    {% end %}

    class Error < OpenSSL::Error
      getter error : ErrorType

      def initialize(ssl : LibSSL::SSL, return_code : LibSSL::Int, func = nil)
        @error = LibSSL.ssl_get_error(ssl, return_code)

        case @error
        when .none?
          message = "Raised erroneously"
        when .syscall?
          @code, message = fetch_error_details
          if @code == 0
            case return_code
            when 0
              message = "Unexpected EOF"
            when -1
              raise Errno.new(func || "OpenSSL")
            else
              message = "Unknown error"
            end
          end
        when .ssl?
          @code, message = fetch_error_details
        else
          message = @error.to_s
        end

        super(func ? "#{func}: #{message}" : message, true)
      end
    end
  end
end

require "./openssl/bio"
require "./openssl/ssl/*"
require "./openssl/digest/*"
require "./openssl/md5"
require "./openssl/x509/x509"
