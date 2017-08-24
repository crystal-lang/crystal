require "./yaml/*"

# The YAML module provides serialization and deserialization of YAML to/from native Crystal data structures.
#
# ### Parsing with `#parse` and `#parse_all`
#
# `YAML#parse` will return an `Any`, which is a convenient wrapper around all possible YAML types,
# making it easy to traverse a complex YAML structure but requires some casts from time to time,
# mostly via some method invocations.
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
# ### Parsing with `YAML#mapping`
#
# `YAML#mapping` defines how an object is mapped to YAML. Mapped data is accessible
# through generated properties like *Foo#bar*. It is more type-safe and efficient.
#
# ### Generating with `YAML.build`
#
# Use `YAML.build`, which uses `YAML::Builder`, to generate YAML
# by emitting scalars, sequences and mappings:
#
# ```
# require "yaml"
#
# string = YAML.build do |yaml|
#   yaml.mapping do
#     yaml.scalar "foo"
#     yaml.sequence do
#       yaml.scalar 1
#       yaml.scalar 2
#     end
#   end
# end
# string # => "---\nfoo:\n- 1\n- 2\n"
# ```
#
# ### Dumping with `YAML.dump` or `#to_yaml`
#
# `YAML.dump` generates the YAML representation for an object. An `IO` can be passed and it will be written there,
# otherwise it will be returned as a string. Similarly, `#to_yaml` (with or without an `IO`) on any object does the same.
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

  # All valid YAML types.
  alias Type = String | Hash(Type, Type) | Array(Type) | Nil
  alias EventKind = LibYAML::EventType

  # Deserializes a YAML document.
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
    YAML::Parser.new data, &.parse
  end

  # Deserializes multiple YAML documents.
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
    YAML::Parser.new data, &.parse_all
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
