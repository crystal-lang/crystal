class OAuth2::Error < Exception
  getter error : String
  getter error_description : String?

  def initialize(@error, @error_description)
    if error_description = @error_description
      super("#{@error}: #{error_description}")
    else
      super(@error)
    end
  end

  def self.new(pull : JSON::PullParser)
    error = nil
    error_description = nil

    pull.read_object do |key|
      case key
      when "error"             then error = pull.read_string
      when "error_description" then error_description = pull.read_string
      else
        raise "Unknown key in oauth2 error json: #{key}"
      end
    end

    new error.not_nil!, error_description
  end
end
