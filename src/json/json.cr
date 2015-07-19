# JavaScript Object Notation (JSON)
#
# JSON (JavaScript Object Notation) is a way to write data in Javascript.
# Like XML, it allows to encode structured data in a text format that can
# be easily read by humans Its simple syntax and native compatibility with
# JavaScript have made it a widely used format.
#
# An object is a series of string keys mapping to values, in `"key": value`
# format. Arrays are enclosed in square brackets `[ ... ]` and objects in
# curly brackets `{ ... }`.
#
# Crystal provides a mechanism for encoding & decoding of values to and
# from JSON via the serialization API.
#
# To read more about JSON visit: json.org
#
# Parsing JSON
#
# To parse a JSON string received by another application or generated within
# your existing application:
#
# ```
# require "json"
#
# hash = JSON.parse("{\"hello\": \"goodbye\"}") as Hash
# hash["hello"] # => {"hello": "goodbye"}
# ```
#
# Important: the compiler has no way of figuring out what the parser will
# return at runtime, everything is possible, including nil.
#
# ```
# require "json"
#
# json = JSON.parse("{\"response\":{\"domain_data\":\"somedata\"}}")
# typeof(json)
# # => (Nil | String | Int64 | Float64 | Bool | Hash(String, JSON::Type) | Array(JSON::Type))
# ```
#
# That's why if you're sure about the structure you can cast
#
# ```
# require "json"
#
# json = JSON.parse("{\"response\":{\"domain_data\":\"somedata\"}}")
#
# casted = json as Hash
# casted["response"] # => {"domain_data" => "somedata"}
# ```
#
# If you need to serialize specific JSON type you can use `json_mapping`
# method for creating custom JSON type:
#
# ```
# require "json"
#
# class DomainData
#   json_mapping({
#     domain_data: String
#   })
# end
#
# class Response
#   json_mapping({
#     response: DomainData
#    })
# end
#
# response = Response.from_json("{\"response\":{\"domain_data\":\"somedata\"}}")
# response.response.domain_data # => "somedata"
# ```
#
# Generating JSON
#
# Creating a JSON string for communication or serialization is just as simple.
#
# ```
# require "json"
#
# { hello: "goodbye" }.to_json # => "{\"hello\":\"goodbye\"}"
# ```
module JSON
  class ParseException < Exception
    getter line_number
    getter column_number

    def initialize(message, @line_number, @column_number)
      super "#{message} at #{@line_number}:#{@column_number}"
    end
  end

  alias Type = Nil | Bool | Int64 | Float64 | String | Array(Type) | Hash(String, Type)

  # A `parse` method reads and decodes JSON objects from an input string or any other
  # IO object.
  #
  # ```
  # require "json"
  #
  # hash = JSON.parse("{\"hello\": \"goodbye\"}") as Hash
  # hash["hello"] # => {"hello": "goodbye"}
  # ```
  def self.parse(string_or_io)
    Parser.new(string_or_io).parse
  end
end

require "./*"
