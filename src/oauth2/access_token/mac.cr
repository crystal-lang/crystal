require "random/secure"
require "openssl/hmac"
require "base64"
require "./access_token"

class OAuth2::AccessToken::Mac < OAuth2::AccessToken
  def self.new(pull : JSON::PullParser)
    OAuth2::AccessToken.new(pull).as(self)
  end

  property mac_algorithm : String
  property mac_key : String
  property issued_at : Int64

  def initialize(access_token, expires_in, @mac_algorithm, @mac_key, refresh_token = nil, scope = nil, @issued_at = Time.now.epoch, extra = nil)
    super(access_token, expires_in, refresh_token, scope, extra)
  end

  def token_type
    "Mac"
  end

  def authenticate(request : HTTP::Request, tls)
    ts = Time.now.epoch
    nonce = "#{ts - @issued_at}:#{Random::Secure.hex}"
    method = request.method
    uri = request.resource
    host, port = host_and_port request, tls
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
             else                     raise "Unsupported algorithm: #{mac_algorithm}"
             end
    Base64.strict_encode OpenSSL::HMAC.digest(digest, mac_key, normalized_request_string)
  end

  def to_json(json : JSON::Builder)
    json.object do
      json.field "token_type", "mac"
      json.field "access_token", access_token
      json.field "expires_in", expires_in
      json.field "refresh_token", refresh_token if refresh_token
      json.field "scope", scope if scope
      json.field "mac_algorithm", mac_algorithm
      json.field "mac_key", mac_key
    end
  end

  def_equals_and_hash access_token, expires_in, mac_algorithm, mac_key, refresh_token, scope

  private def host_and_port(request, tls)
    host_header = request.headers["Host"]
    if colon_index = host_header.index ':'
      host = host_header[0...colon_index]
      port = host_header[colon_index + 1..-1].to_i
    else
      host = host_header
      port = tls ? 443 : 80
    end
    {host, port}
  end
end
