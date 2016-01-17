# The JSON module allows parsing and generating [JSON](http://json.org/) documents.
#
# ### Parsing and generating with `JSON#mapping`
#
# Use `JSON#mapping` to define how an object is mapped to JSON, making it
# the recommended easy, type-safe and efficient option for parsing and generating
# JSON. Refer to that module's documentation to learn about it.
#
# ### Parsing with `JSON#parse`
#
# `JSON#parse` will return an `Any`, which is a convenient wrapper around all possible JSON types,
# making it easy to traverse a complex JSON structure but requires some casts from time to time,
# mostly via some method invocations.
#
# ```
# require "json"
#
# value = JSON.parse("[1, 2, 3]") # :: JSON::Any
#
# value[0]              # => 1
# typeof(value[0])      # => JSON::Any
# value[0].as_i         # => 1
# typeof(value[0].as_i) # => Int32
#
# value[0] + 1       # Error, because value[0] is JSON::Any
# value[0].as_i + 10 # => 11
# ```
#
# The above is useful for dealing with a dynamic JSON structure but is slower than using `JSON#mapping`.
#
# ### Generating with `JSON::Builder`
#
# Use `JSON::Builder` to generate JSON on the fly by directly emitting data
# to an `IO`.
#
# ### Generating with `to_json`
#
# `to_json` and `to_json(IO)` methods are provided for primitive types, but you
# need to define `to_json(IO)` for custom objects, either manually or using
# `JSON#mapping`.
module JSON
  # Exception thrown on a JSON parse error.
  class ParseException < Exception
    getter line_number
    getter column_number

    def initialize(message, @line_number, @column_number)
      super "#{message} at #{@line_number}:#{@column_number}"
    end
  end

  # All valid JSON types
  alias Type = Nil | Bool | Int64 | Float64 | String | Array(Type) | Hash(String, Type)

  # Parses a JSON document.
  def self.parse(input : String | IO) : Any
    Any.new Parser.new(input).parse
  end
end

require "./*"
