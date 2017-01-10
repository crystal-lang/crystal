require "./openssl/lib_ssl"

# ### Example
# ## Server side
# for the below "server" example to work, a key pair should be created, using openssl it can be done like that
# - Generate keys to /tmp/
# - openssl req -x509 -sha256 -nodes -days 365 -newkey rsa:2048 -keyout /tmp/private.key -out /tmp/certificate.crt
# ```crystal
# require "socket"
# require "openssl"
#
# def server
#   socket = TCPServer.new(5555) # Bind new TCPSocket to port 5555
#   context = OpenSSL::SSL::Context::Server.new
#   # Define which ciphers to use with OpenSSL
#   # recommended ciphers can be taken from
#   # - https://www.owasp.org/index.php/Transport_Layer_Protection_Cheat_Sheet#Rule_-_Only_Support_Strong_Cryptographic_Ciphers
#   # - https://cipherli.st/
#   # - Full list is available at: https://wiki.openssl.org/index.php/Manual:Ciphers(1)#CIPHER_STRINGS
#   context.ciphers = "EECDH+AESGCM:EDH+AESGCM:AES256+EECDH:AES256+EDH"
#   context.private_key = "/tmp/private.key"
#   context.certificate_chain = "/tmp/certificate.crt"
#   # Those options are to enhance the security of the server by not using deprecated SSLv2 and SSLv3 protocols
#   # It is also advised to disable Compression and enable only TLS1.2
#   context.add_options(OpenSSL::SSL::Options::NO_SSLV2 | OpenSSL::SSL::Options::NO_SSLV3)
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
# ## Client side
# ```crystal
# require "socket"
# require "openssl"
#
# def client
#   socket = TCPSocket.new("127.0.0.1", 5555)
#   context = OpenSSL::SSL::Context::Client.new
#   context.ciphers = "EECDH+AESGCM:EDH+AESGCM:AES256+EECDH:AES256+EDH"
#   context.add_options(OpenSSL::SSL::Options::NO_SSLV2 | OpenSSL::SSL::Options::NO_SSLV3)
#   context.verify_mode = OpenSSL::SSL::VerifyMode::NONE
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
