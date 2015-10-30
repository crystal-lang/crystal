require "./*"

# The YAML module provides deserialization of YAML to native Crystal data structures.
#
# ### Parsing with `#load` and `#load_all`
#
# Deserializes a YAML document into a `Type`.
# A `Type` is a union of all possible YAML types, so casting to a specific type is necessary
# before the value is practically usable.
#
# ```crystal
# require "yaml"
#
# data = YAML.load("foo: bar")
# (data as Hash)["foo"] # => "bar"
# ```
#
# ### Parsing with `YAML#mapping`
#
# `YAML#mapping` defines how an object is mapped to YAML. Mapped data is accessible
# through generated properties like *Foo#bar*. It is more type-safe and efficient.
#
module YAML
  # Exception thrown on a YAML parse error.
  class ParseException < Exception
    getter line_number
    getter column_number

    def initialize(message, @line_number, @column_number)
      super "#{message} at #{@line_number}:#{@column_number}"
    end
  end

  # All valid YAML types
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
  # ```crystal
  # require "yaml"
  # YAML.load(File.read("./foo.yml"))
  # # => {
  # # => "data" => {
  # # => "string" => "foobar",
  # # => "array" => ["John", "Sarah"],
  # # => "hash" => {"key" => "value"},
  # # => "paragraph" => "foo\nbar\n"
  # # => }
  # ```
  def self.load(data : String)
    parser = YAML::Parser.new(data)
    begin
      parser.parse
    ensure
      parser.close
    end
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
  # ```crystal
  # require "yaml"
  # YAML.load_all(File.read("./foo.yml"))
  # # => [{"foo" => "bar"}, {"hello" => "world"}]
  # ```
  def self.load_all(data : String)
    parser = YAML::Parser.new(data)
    begin
      parser.parse_all
    ensure
      parser.close
    end
  end
end
