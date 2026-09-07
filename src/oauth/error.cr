class OAuth::Error < ::Exception
  def initialize(message : String)
    super
  end

  def initialize(response : HTTP::Client::Response)
    super("OAuth:Error: #{response.body}")
  end
end
