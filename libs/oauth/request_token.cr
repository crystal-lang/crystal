class OAuth::RequestToken
  getter token
  getter secret

  def initialize(@token, @secret)
  end

  def self.from_response(response)
    token = nil
    secret = nil

    CGI.parse(response) do |key, value|
      case key
      when "oauth_token"        then token = value
      when "oauth_token_secret" then secret = value
      end
    end

    new token.not_nil!, secret.not_nil!
  end
end
