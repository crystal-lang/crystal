class OAuth::RequestToken
  getter token
  getter secret

  def initialize(@token, @secret)
  end

  def self.from_response(response)
    token = nil
    secret = nil
    problem = nil

    CGI.parse(response) do |key, value|
      case key
      when "oauth_token"        then token = value
      when "oauth_token_secret" then secret = value
      when "oauth_problem"      then problem = value
      end
    end

    if problem
      raise Error.new(problem)
    end

    new token.not_nil!, secret.not_nil!
  end
end
