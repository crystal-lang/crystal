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
    extra = nil

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
        extra ||= {} of String => String
        extra[key] = pull.read_raw
      end
    end

    access_token = access_token.not_nil!

    token_type ||= "bearer"

    case token_type.downcase
    when "bearer"
      Bearer.new(access_token, expires_in, refresh_token, scope, extra)
    when "mac"
      Mac.new(access_token, expires_in, mac_algorithm.not_nil!, mac_key.not_nil!, refresh_token, scope, Time.now.epoch, extra)
    else
      raise "Unknown token_type in access token json: #{token_type}"
    end
  end

  property access_token : String
  property expires_in : Int64?
  property refresh_token : String?
  property scope : String?

  # JSON key-value pairs that are outside of the OAuth2 spec are
  # stored in this property in case they are needed. Their value
  # is the raw JSON string found in the JSON value (with possible
  # changes in the string format, but preserving JSON semantic).
  # For example if the value was `[1, 2, 3]` then the value in this hash
  # will be the string "[1,2,3]".
  property extra : Hash(String, String)?

  def initialize(@access_token : String, expires_in : Int?, @refresh_token : String? = nil, @scope : String? = nil, @extra = nil)
    @expires_in = expires_in.try &.to_i64
  end

  abstract def authenticate(request : HTTP::Request, tls)

  def authenticate(client : HTTP::Client)
    client.before_request do |request|
      authenticate request, client.tls?
    end
  end
end
