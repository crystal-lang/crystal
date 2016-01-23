require "./*"

# The YAML module provides serialization and deserialization of YAML to/from native Crystal data structures.
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
# ### Dumping with `YAML.dump` or `#to_yaml`
#
# `YAML.dump` generates the YAML representation for an object. An `IO` can be passed and it will be written there,
# otherwise it will be returned as a string. Similarly, `#to_yaml` (with or without an `IO`) on any object does the same.
#
# ```crystal
# yaml = YAML.dump({hello: "world"})                                # => "--- \nhello: world"
# File.open("file.yml", "w") { |f| YAML.dump({hello: "world"}, f) } # => writes it to the file
# # or:
# yaml = {hello: "world"}.to_yaml                                # => "--- \nhello: world"
# File.open("file.yml", "w") { |f| {hello: "world"}.to_yaml(f) } # => writes it to the file
# ```
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

  # Serializes an object to YAML, returning it as a string.
  def self.dump(object)
    object.to_yaml
  end

  # Serializes an object to YAML, writing it to `io`.
  def self.dump(object, io : IO)
    object.to_yaml(io)
  end
end
