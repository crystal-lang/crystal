require "secure_random"
require "openssl/hmac"
require "base64"
require "./access_token"

class OAuth2::AccessToken::Mac < OAuth2::AccessToken
  property mac_algorithm
  property mac_key
  property issued_at

  def initialize(access_token, expires_in, @mac_algorithm, @mac_key, refresh_token = nil, scope = nil, @issued_at = Time.now.to_i)
    super(access_token, expires_in, refresh_token, scope)
  end

  def token_type
    "Mac"
  end

  def authenticate(request : HTTP::Request, ssl)
    ts = Time.now.to_i
    nonce = "#{ts - @issued_at}:#{SecureRandom.hex}"
    method = request.method
    uri = request.path
    host, port = host_and_port request, ssl
    ext = ""

    mac = Mac.signature ts, nonce, method, uri, host, port, ext, mac_algorithm, mac_key

    header = %(MAC id="#{access_token}", nonce="#{nonce}", ts="#{ts}", mac="#{mac}")
    request.headers["Authorization"] = header
  end

  def self.signature(ts, nonce, method, uri, host, port, ext, mac_algorithm, mac_key)
    normalized_request_string = "#{ts}\n#{nonce}\n#{method}\n#{uri}\n#{host}\n#{port}\n#{ext}\n"

    digest = case mac_algorithm
             when "hmac-sha-1"   then :sha1
             when "hmac-sha-256" then :sha256
             else raise "unsupported algorithm: #{mac_algorithm}"
             end
    Base64.strict_encode64 OpenSSL::HMAC.digest(digest, mac_key, normalized_request_string)
  end

  def to_json(io)
    io.json_object do |object|
      object.field "token_type", "mac"
      object.field "access_token", access_token
      object.field "expires_in", expires_in
      object.field "refresh_token", refresh_token if refresh_token
      object.field "scope", scope if scope
      object.field "mac_algorithm", mac_algorithm
      object.field "mac_key", mac_key
    end
  end

  def_equals_and_hash access_token, expires_in, mac_algorithm, mac_key, refresh_token, scope

  private def host_and_port(request, ssl)
    host_header = request.headers["Host"]
    if colon_index = host_header.index ':'
      host = host_header[0 ... colon_index]
      port = host_header[colon_index + 1 .. -1].to_i
    else
      host = host_header
      port = ssl ? 443 : 80
    end
    {host, port}
  end
end
