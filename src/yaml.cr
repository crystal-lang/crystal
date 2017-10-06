require "./yaml/**"
require "base64"

# The YAML module provides serialization and deserialization of YAML
# version 1.1 to/from native Crystal data structures, with the additional
# independent types specified in http://yaml.org/type/
#
# ### Parsing with `#parse` and `#parse_all`
#
# `YAML#parse` will return an `Any`, which is a convenient wrapper around all possible
# YAML core types, making it easy to traverse a complex YAML structure but requires
# some casts from time to time, mostly via some method invocations.
#
# ```
# require "yaml"
#
# data = YAML.parse <<-END
#          ---
#          foo:
#            bar:
#              baz:
#                - qux
#                - fox
#          END
# data["foo"]["bar"]["baz"][1].as_s # => "fox"
# ```
#
# ### Parsing with `from_yaml`
#
# A type `T` can be deserialized from YAML by invoking `T.from_yaml(string_or_io)`.
# For this to work, `T` must implement
# `new(ctx : YAML::PullParser, node : YAML::Nodes::Node)` and decode
# a value from the given *node*, using *ctx* to store and retrieve
# anchored values (see `YAML::PullParser` for an explanation of this).
#
# Crystal primitive types, `Time`, `Bytes` and `Union` implement
# this method. `YAML.mapping` can be used to implement this method
# for user types.
#
# ### Dumping with `YAML.dump` or `#to_yaml`
#
# `YAML.dump` generates the YAML representation for an object.
# An `IO` can be passed and it will be written there,
# otherwise it will be returned as a string. Similarly, `#to_yaml`
# (with or without an `IO`) on any object does the same.
#
# For this to work, the type given to `YAML.dump` must implement
# `to_yaml(builder : YAML::Nodes::Builder`).
#
# Crystal primitive types, `Time` and `Bytes` implement
# this method. `YAML.mapping` can be used to implement this method
# for user types.
#
# ```
# yaml = YAML.dump({hello: "world"})                               # => "---\nhello: world\n"
# File.open("foo.yml", "w") { |f| YAML.dump({hello: "world"}, f) } # writes it to the file
# # or:
# yaml = {hello: "world"}.to_yaml                               # => "---\nhello: world\n"
# File.open("foo.yml", "w") { |f| {hello: "world"}.to_yaml(f) } # writes it to the file
# ```
module YAML
  class Error < Exception
  end

  # Exception thrown on a YAML parse error.
  class ParseException < Error
    getter line_number : Int32
    getter column_number : Int32

    def initialize(message, line_number, column_number, context_info = nil)
      @line_number = line_number.to_i
      @column_number = column_number.to_i
      if context_info
        context_msg, context_line, context_column = context_info
        super("#{message} at line #{line_number}, column #{column_number}, #{context_msg} at line #{context_line}, column #{context_column}")
      else
        super("#{message} at line #{line_number}, column #{column_number}")
      end
    end

    def location
      {line_number, column_number}
    end
  end

  # All valid YAML core schema types.
  alias Type = Nil | Bool | Int64 | Float64 | String | Time | Bytes | Array(Type) | Hash(Type, Type) | Set(Type)

  # Deserializes a YAML document according to the core schema.
  #
  # ```yaml
  # # ./foo.yml
  # data:
  #   string: "foobar"
  #   array:
  #     - John
  #     - Sarah
  #   hash: {key: value}
  #   paragraph: |
  #     foo
  #     bar
  # ```
  #
  # ```
  # require "yaml"
  #
  # YAML.parse(File.read("./foo.yml"))
  # # => {
  # # => "data" => {
  # # => "string" => "foobar",
  # # => "array" => ["John", "Sarah"],
  # # => "hash" => {"key" => "value"},
  # # => "paragraph" => "foo\nbar\n"
  # # => }
  # ```
  def self.parse(data : String | IO) : Any
    YAML::Schema::Core.parse(data)
  end

  # Deserializes multiple YAML documents according to the core schema.
  #
  # ```yaml
  # # ./foo.yml
  # foo: bar
  # ---
  # hello: world
  # ```
  #
  # ```
  # require "yaml"
  #
  # YAML.parse_all(File.read("./foo.yml"))
  # # => [{"foo" => "bar"}, {"hello" => "world"}]
  # ```
  def self.parse_all(data : String) : Array(Any)
    YAML::Schema::Core.parse_all(data)
  end

  # Serializes an object to YAML, returning it as a `String`.
  def self.dump(object) : String
    object.to_yaml
  end

  # Serializes an object to YAML, writing it to *io*.
  def self.dump(object, io : IO)
    object.to_yaml(io)
  end
end
