# The JSON module allows parsing and generating [JSON](http://json.org/) documents.
#
# NOTE: To use `JSON` or its children, you must explicitly import it with `require "json"`
#
# ### General type-safe interface
#
# The general type-safe interface for parsing JSON is to invoke `T.from_json` on a
# target type `T` and pass either a `String` or `IO` as an argument.
#
# ```
# require "json"
#
# json_text = %([1, 2, 3])
# Array(Int32).from_json(json_text) # => [1, 2, 3]
#
# json_text = %({"x": 1, "y": 2})
# Hash(String, Int32).from_json(json_text) # => {"x" => 1, "y" => 2}
# ```
#
# Serializing is achieved by invoking `to_json`, which returns a `String`, or
# `to_json(io : IO)`, which will stream the JSON to an `IO`.
#
# ```
# require "json"
#
# [1, 2, 3].to_json            # => "[1,2,3]"
# {"x" => 1, "y" => 2}.to_json # => "{\"x\":1,\"y\":2}"
# ```
#
# Most types in the standard library implement these methods. For user-defined types
# you can define a `self.new(pull : JSON::PullParser)` for parsing and
# `to_json(builder : JSON::Builder)` for serializing. The following sections
# show convenient ways to do this using `JSON::Serializable`.
#
# NOTE: JSON object keys are always strings but they can still be parsed
# and deserialized to other types. To deserialize, define a
# `T.from_json_object_key?(key : String) : T?` method, which can return `nil`
# if the string can't be parsed into that type. To serialize, define a
# `to_json_object_key : String` method can be serialized that way.
# All integer and float types in the standard library can be deserialized that way.
#
# ```
# require "json"
#
# json_text = %({"1": 2, "3": 4})
# Hash(Int32, Int32).from_json(json_text) # => {1 => 2, 3 => 4}
#
# {1.5 => 2}.to_json # => "{\"1.5\":2}"
# ```
#
# ### Parsing with `JSON.parse`
#
# `JSON.parse` will return an `Any`, which is a convenient wrapper around all possible JSON types,
# making it easy to traverse a complex JSON structure but requires some casts from time to time,
# mostly via some method invocations.
#
# ```
# require "json"
#
# value = JSON.parse("[1, 2, 3]") # : JSON::Any
#
# value[0]               # => 1
# typeof(value[0])       # => JSON::Any
# value[0].as_i          # => 1
# typeof(value[0].as_i)  # => Int32
# value[0].as_i?         # => 1
# typeof(value[0].as_i?) # => Int32 | Nil
# value[0].as_s?         # => nil
# typeof(value[0].as_s?) # => String | Nil
#
# value[0] + 1       # Error, because value[0] is JSON::Any
# value[0].as_i + 10 # => 11
# ```
#
# `JSON.parse` can read from an `IO` directly (such as a file) which saves
# allocating a string:
#
# ```
# require "json"
#
# json = File.open("path/to/file.json") do |file|
#   JSON.parse(file)
# end
# ```
#
# Parsing with `JSON.parse` is useful for dealing with a dynamic JSON structure.
#
# ### Generating with `JSON.build`
#
# Use `JSON.build`, which uses `JSON::Builder`, to generate JSON
# by emitting scalars, arrays and objects:
#
# ```
# require "json"
#
# string = JSON.build do |json|
#   json.object do
#     json.field "name", "foo"
#     json.field "values" do
#       json.array do
#         json.number 1
#         json.number 2
#         json.number 3
#       end
#     end
#   end
# end
# string # => %<{"name":"foo","values":[1,2,3]}>
# ```
#
# ### Generating with `to_json`
#
# `to_json`, `to_json(IO)` and `to_json(JSON::Builder)` methods are provided
# for primitive types, but you need to define `to_json(JSON::Builder)`
# for custom objects, either manually or using `JSON::Serializable`.
module JSON
  # Generic JSON error.
  class Error < Exception
  end

  # Exception thrown on a JSON parse error.
  class ParseException < Error
    getter line_number : Int32
    getter column_number : Int32

    def initialize(message, @line_number, @column_number, cause = nil)
      super "#{message} at line #{@line_number}, column #{@column_number}", cause
    end

    def location : {Int32, Int32}
      {line_number, column_number}
    end
  end

  # Parses a JSON document as a `JSON::Any`.
  def self.parse(input : String | IO) : Any
    Parser.new(input).parse
  end
end

require "./json/*"
