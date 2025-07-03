class OAuth::RequestToken
  getter token : String
  getter secret : String

  def initialize(@token : String, @secret : String)
  end

  def self.from_response(response) : self
    token = nil
    secret = nil

    URI::Params.parse(response) do |key, value|
      case key
      when "oauth_token"        then token = value
      when "oauth_token_secret" then secret = value
      else
        # Not a key we are interested in
      end
    end

    new token.not_nil!, secret.not_nil!
  end

  def_equals_and_hash @token, @secret
end
