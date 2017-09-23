class OAuth::RequestToken
  getter token : String
  getter secret : String

  def initialize(@token : String, @secret : String)
  end

  def self.from_response(response) : self
    token = nil
    secret = nil

    HTTP::Params.parse(response) do |key, value|
      case key
      when "oauth_token"        then token = value
      when "oauth_token_secret" then secret = value
      end
    end

    new token.not_nil!, secret.not_nil!
  end
end
