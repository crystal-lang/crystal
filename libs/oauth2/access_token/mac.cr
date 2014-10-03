require "access_token"

class OAuth2::AccessToken::Mac < OAuth2::AccessToken
  getter access_token
  getter expires_in
  getter refresh_token
  getter mac_algorithm
  getter mac_key

  def initialize(@access_token, @expires_in, @refresh_token, @mac_algorithm, @mac_key)
  end

  def token_type
    "Mac"
  end

  def authenticate(request : HTTP::Request)
    # TODO
  end

  def to_json(io)
    io.json_object do |object|
      object.field "token_type", "Mac"
      object.field "access_token", access_token
      object.field "expires_in", expires_in
      object.field "refresh_token", refresh_token
      object.field "mac_algorithm", mac_algorithm
      object.field "mac_key", mac_key
    end
  end

  def_equals_and_hash access_token, expires_in, refresh_token, mac_algorithm, mac_key
end
