class OAuth::AccessToken
  getter token
  getter secret

  def initialize(@token, @secret, @extra = nil)
  end

  def extra
    @extra ||= {} of String => String
  end

  def self.from_response(response)
    token = nil
    secret = nil
    extra = {} of String => String

    CGI.parse(response) do |key, value|
      case key
      when "oauth_token"        then token = value
      when "oauth_token_secret" then secret = value
      else                           extra[key] = value
      end
    end

    new token.not_nil!, secret.not_nil!, extra
  end

  def self.new(pull : JSON::PullParser)
    token = nil
    secret = nil
    extra = {} of String => String

    pull.read_object do |key|
      case key
      when "oauth_token"
        token = pull.read_string
      when "oauth_token_secret"
        secret = pull.read_string
      else
        if pull.kind == :STRING
          extra[key] = pull.read_string
        else
          pull.skip
        end
      end
    end

    new token.not_nil!, secret.not_nil!, extra
  end

  def to_json(io : IO)
    io.json_object do |object|
      object.field "oauth_token", @token
      object.field "oauth_token_secret", @secret
      @extra.try &.each do |key, value|
        object.field key, value
      end
    end
  end
end
