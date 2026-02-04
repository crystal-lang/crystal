struct OAuth2::ErrorResponse
  include JSON::Serializable

  getter error : String
  getter extra : Hash(String, String) { {} of String => String }

  # Taken from JSON::Serializable::Unmapped
  protected def on_unknown_json_attribute(pull, key, key_location)
    extra[key] = begin
      case value = ::JSON::Any.new(pull)
      when .as_s?
        value.as_s
      else
        value.raw.to_s
      end
    rescue exc : ::JSON::ParseException
      raise ::JSON::SerializableError.new(exc.message, self.class.to_s, key, *key_location, exc)
    end
  end
end
