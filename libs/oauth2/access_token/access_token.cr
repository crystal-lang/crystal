abstract class OAuth2::AccessToken
  def self.new(pull : Json::PullParser)
    token_type = nil
    access_token = nil
    expires_in = nil
    refresh_token = nil
    mac_algorithm = nil
    mac_key = nil

    pull.read_object do |key|
      case key
      when "token_type"    then token_type    = pull.read_string
      when "access_token"  then access_token  = pull.read_string
      when "expires_in"    then expires_in    = pull.read_int
      when "refresh_token" then refresh_token = pull.read_string_or_null
      when "mac_algorithm" then mac_algorithm = pull.read_string
      when "mac_key"       then mac_key       = pull.read_string
      else
        raise "Uknown key in access token json: #{key}"
      end
    end

    access_token = access_token.not_nil!
    expires_in = expires_in.not_nil!

    if token_type
      case token_type.downcase
      when "bearer"
        Bearer.new(access_token, expires_in, refresh_token)
      when "mac"
        Mac.new(access_token, expires_in, refresh_token, mac_algorithm.not_nil!, mac_key.not_nil!)
      else
        raise "Uknown token_type in access token json: #{token_type}"
      end
    else
      raise "Missing token_type in access token json"
    end
  end

  property access_token
  property expires_in
  property refresh_token

  def initialize(@access_token, @expires_in, @refresh_token)
  end

  abstract def authenticate(request : HTTP::Request, ssl)

  def authenticate(client : HTTP::Client)
    client.before_request do |request|
      authenticate request, client.ssl?
    end
  end
end
