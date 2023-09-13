require "json"
require "uuid"

struct UUID
  # Creates UUID from JSON using `JSON::PullParser`.
  #
  # NOTE: `require "uuid/json"` is required to opt-in to this feature.
  #
  # ```
  # require "json"
  # require "uuid"
  # require "uuid/json"
  #
  # class Example
  #   include JSON::Serializable
  #
  #   property id : UUID
  # end
  #
  # example = Example.from_json(%({"id": "ba714f86-cac6-42c7-8956-bcf5105e1b81"}))
  # example.id # => UUID(ba714f86-cac6-42c7-8956-bcf5105e1b81)
  # ```
  def self.new(pull : JSON::PullParser)
    new(pull.read_string)
  end

  # Returns UUID as JSON value.
  #
  # NOTE: `require "uuid/json"` is required to opt-in to this feature.
  #
  # ```
  # uuid = UUID.new("87b3042b-9b9a-41b7-8b15-a93d3f17025e")
  # uuid.to_json # => "\"87b3042b-9b9a-41b7-8b15-a93d3f17025e\""
  # ```
  def to_json(json : JSON::Builder) : Nil
    json.string(to_s)
  end

  # :nodoc:
  def to_json_object_key
    to_s
  end

  # Deserializes the given JSON *key* into a `UUID`.
  #
  # NOTE: `require "uuid/json"` is required to opt-in to this feature.
  def self.from_json_object_key?(key : String)
    UUID.new(key)
  end
end
