class OAuth::AccessToken
  getter token : String
  getter secret : String

  def initialize(@token : String, @secret : String, @extra : Hash(String, String)? = nil)
  end

  def authenticate(client, consumer_key, consumer_secret, extra_params = nil)
    OAuth.authenticate(client, @token, @secret, consumer_key, consumer_secret, extra_params)
  end

  def extra
    @extra ||= {} of String => String
  end

  def self.from_response(response : String) : self
    token = nil
    secret = nil
    extra = nil

    HTTP::Params.parse(response) do |key, value|
      case key
      when "oauth_token"        then token = value
      when "oauth_token_secret" then secret = value
      else
        extra ||= {} of String => String
        extra[key] = value
      end
    end

    new token.not_nil!, secret.not_nil!, extra
  end

  def self.new(pull : JSON::PullParser)
    token = nil
    secret = nil
    extra = nil

    pull.read_object do |key|
      case key
      when "oauth_token"
        token = pull.read_string
      when "oauth_token_secret"
        secret = pull.read_string
      else
        if pull.kind == :STRING
          extra ||= {} of String => String
          extra[key] = pull.read_string
        else
          pull.skip
        end
      end
    end

    new token.not_nil!, secret.not_nil!, extra
  end

  def to_json(json : JSON::Builder)
    json.object do
      json.field "oauth_token", @token
      json.field "oauth_token_secret", @secret
      @extra.try &.each do |key, value|
        json.field key, value
      end
    end
  end
end
