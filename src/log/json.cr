require "json"

class Log::Metadata
  # Returns `Log::Metadata` as JSON value.
  #
  # NOTE: `require "log/json"` is required to opt-in to this feature.
  #
  # ```
  # log_entry.context.to_json # => "{\"user_id\":1}"
  # ```
  def to_json(builder : JSON::Builder) : Nil
    builder.object do
      each do |(key, value)|
        builder.field key.to_json_object_key do
          value.to_json(builder)
        end
      end
    end
  end

  struct Value
    # Returns `Log::Metadata::Value` as JSON value.
    #
    # NOTE: `require "log/json"` is required to opt-in to this feature.
    def to_json(builder : JSON::Builder) : Nil
      @raw.to_json builder
    end
  end
end
