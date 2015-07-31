# The JSON module allows parsing and generating [JSON](http://json.org/) documents.
#
# ### Parsing and generating with `JSON::Mapping`
#
# Use `JSON::Mapping` to define how an object is mapped to JSON, making it
# the recommended easy, type-safe and efficient option for parsing and generating
# JSON. Refer to that module's documentation to learn about it.
#
# ### Parsing with `JSON#parse`
#
# `JSON#parse` will return a `Type`, which is a union of all possible JSON types,
# making it mandatory to use casts or type checks to deal with parsed values:
#
# ```
# require "json"
#
# value = JSON.parse("[1, 2, 3]") #:: JSON::Type
# # value[0] # compile-error, compiler can't know that value is indeed an Array
# array = value as Array
# array[0] #:: JSON::Type
# (array[0] as Int) + 10 #=> 11
# ```
#
# The above becomes tedious quickly, but can be useful for handling dynamic JSON content.
#
# ### Generating with `JSON::Builder`
#
# Use `JSON::Buidler` to generate JSON on the fly by directly emitting data
# to an `IO`.
#
# ### Generating with `to_json`
#
# `to_json` and `to_json(IO)` methods are provided for primitive types, but you
# need to define `to_json(IO)` for custom objects, either manually or using
# `JSON::Mapping`.
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
  def self.parse(input : String | IO) : Type
    Parser.new(input).parse
  end
end

require "./*"
