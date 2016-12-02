# Base class for the two possible access tokens: Bearer and Mac.
#
# Use `#authenticate` to authenticate an `HTTP::Client`.
abstract class OAuth2::AccessToken
  def self.new(pull : JSON::PullParser)
    token_type = nil
    access_token = nil
    expires_in = nil
    refresh_token = nil
    scope = nil
    mac_algorithm = nil
    mac_key = nil

    pull.read_object do |key|
      case key
      when "token_type"    then token_type = pull.read_string
      when "access_token"  then access_token = pull.read_string
      when "expires_in"    then expires_in = pull.read_int
      when "refresh_token" then refresh_token = pull.read_string_or_null
      when "scope"         then scope = pull.read_string_or_null
      when "mac_algorithm" then mac_algorithm = pull.read_string
      when "mac_key"       then mac_key = pull.read_string
      else
        raise "Uknown key in access token json: #{key}"
      end
    end

    access_token = access_token.not_nil!
    expires_in = expires_in.not_nil!

    if token_type
      case token_type.downcase
      when "bearer"
        Bearer.new(access_token, expires_in, refresh_token, scope)
      when "mac"
        Mac.new(access_token, expires_in, mac_algorithm.not_nil!, mac_key.not_nil!, refresh_token, scope)
      else
        raise "Uknown token_type in access token json: #{token_type}"
      end
    else
      raise "Missing token_type in access token json"
    end
  end

  property access_token : String
  property expires_in : Int64
  property refresh_token : String?
  property scope : String?

  def initialize(@access_token : String, expires_in : Int, @refresh_token : String? = nil, @scope : String? = nil)
    @expires_in = expires_in.to_i64
  end

  abstract def authenticate(request : HTTP::Request, tls)

  def authenticate(client : HTTP::Client)
    client.before_request do |request|
      authenticate request, client.tls?
    end
  end
end
