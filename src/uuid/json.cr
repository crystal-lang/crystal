require "json"
require "uuid"

# Adds JSON support to `UUID` for use in a JSON mapping.
#
# NOTE: `require "uuid/json"` is required to opt-in to this feature.
#
# ```
# require "json"
# require "uuid"
# require "uuid/json"
#
# class Example
#   JSON.mapping id: UUID
# end
#
# example = Example.from_json(%({"id": "ba714f86-cac6-42c7-8956-bcf5105e1b81"}))
#
# uuid = UUID.new("87b3042b-9b9a-41b7-8b15-a93d3f17025e")
# uuid.to_json # => "\"87b3042b-9b9a-41b7-8b15-a93d3f17025e\""
# ```
struct UUID
  def self.new(pull : JSON::PullParser)
    new(pull.read_string)
  end

  def to_json(json : JSON::Builder)
    json.string(to_s)
  end
end
