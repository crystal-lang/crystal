class OAuth::Error < ::Exception
  def initialize(response)
    super("OAuth:Error: #{response.body}")
  end
end
