require "json"

class Log::Context
  # Returns `Log::Context` as JSON value.
  #
  # NOTE: `require "log/json"` is required to opt-in to this feature.
  #
  # ```
  # log_entry.context.to_json # => "{\"user_id\":1}"
  # ```
  def to_json(builder : JSON::Builder) : Nil
    @raw.to_json builder
  end
end
