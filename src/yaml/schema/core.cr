# Provides utility methods for the YAML 1.1 core schema
# with the additional independent types specified in http://yaml.org/type/
module YAML::Schema::Core
  # Deserializes a YAML document.
  #
  # Same as `YAML.parse`.
  def self.parse(data : String | IO)
    Parser.new data, &.parse
  end

  # Deserializes multiple YAML documents.
  #
  # Same as `YAML.parse_all`.
  def self.parse_all(data : String | IO)
    Parser.new data, &.parse_all
  end

  # Assuming the *pull_parser* is positioned in a scalar,
  # parses it according to the core schema, taking the
  # scalar's style and tag into account, then advances
  # the pull parser.
  def self.parse_scalar(pull_parser : YAML::PullParser) : Type
    string = pull_parser.value

    # Check for core schema tags
    process_scalar_tag(pull_parser, pull_parser.tag) do |value|
      return value
    end

    # Non-plain scalar is always a string
    unless pull_parser.scalar_style.plain?
      return string
    end

    parse_scalar(string)
  end

  # Parses a scalar value from the given *node*.
  def self.parse_scalar(node : YAML::Nodes::Scalar) : Type
    string = node.value

    # Check for core schema tags
    process_scalar_tag(node) do |value|
      return value
    end

    # Non-plain scalar is always a string
    unless node.style.plain?
      return string
    end

    parse_scalar(string)
  end

  # Parses a string according to the core schema, assuming
  # the string had a plain style.
  #
  # ```
  # YAML::Schema::Core.parse_scalar("hello") # => "hello"
  # YAML::Schema::Core.parse_scalar("1.2")   # => 1.2
  # YAML::Schema::Core.parse_scalar("false") # => false
  # ```
  def self.parse_scalar(string : String) : Type
    if parse_null?(string)
      return nil
    end

    value = parse_bool?(string)
    return value unless value.nil?

    value = parse_float_infinity_and_nan?(string)
    return value if value

    # Optimizations for prefixes that either parse to
    # a number or are strings otherwise
    case string
    when .starts_with?("0x"),
         .starts_with?("+0x"),
         .starts_with?("-0x")
      value = string.to_i64?(base: 16, prefix: true)
      return value || string
    when .starts_with?('0')
      value = string.to_i64?(base: 8, prefix: true)
      return value || string
    when .starts_with?('-'),
         .starts_with?('+')
      value = parse_number?(string)
      return value || string
    end

    if string[0].ascii_number?
      value = parse_number?(string)
      return value if value

      value = parse_time?(string)
      return value if value
    end

    string
  end

  # Returns whether a string is reserved and must non be output
  # with a plain style, according to the core schema.
  #
  # ```
  # YAML::Schema::Core.reserved_string?("hello") # => false
  # YAML::Schema::Core.reserved_string?("1.2")   # => true
  # YAML::Schema::Core.reserved_string?("false") # => true
  # ```
  def self.reserved_string?(string) : Bool
    # There's simply no other way than parsing the string and
    # checking what we got.
    #
    # The performance loss is minimal because `parse_scalar`
    # doesn't allocate memory: it can only return primitive
    # types, or `Time`, which is a struct.
    !parse_scalar(string).is_a?(String)
  end

  # If `node` parses to a null value, returns `nil`, otherwise
  # invokes the given block.
  def self.parse_null_or(node : YAML::Nodes::Node)
    if node.is_a?(YAML::Nodes::Scalar) && parse_null?(node.value)
      nil
    else
      yield
    end
  end

  # Invokes the block for each of the given *node*s keys and
  # values, resolving merge keys (<<) when found (keys and
  # values of the resolved merge mappings are yielded,
  # recursively).
  def self.each(node : YAML::Nodes::Mapping)
    # We can't just traverse the nodes and invoke yield because
    # yield can't recurse. So, we use a stack of {Mapping, index}.
    # We pop from the stack and traverse the mapping values.
    # When we find a merge, we stop (put back in the stack with
    # that mapping and next index) and add solved mappings from
    # the merge to the stack, and continue processing.

    stack = [{node, 0}]

    # Mappings that we already visited. In case of a recursion
    # we want to stop. For example:
    #
    # foo: &foo
    #   <<: *foo
    #
    # When we traverse &foo we'll put it in visited,
    # and when we find it in *foo we'll skip it.
    #
    # This has no use case, but we don't want to hang the program.
    visited = Set(YAML::Nodes::Mapping).new

    until stack.empty?
      mapping, index = stack.pop

      visited << mapping

      while index < mapping.nodes.size
        key = mapping.nodes[index]
        index += 1

        value = mapping.nodes[index]
        index += 1

        if key.is_a?(YAML::Nodes::Scalar) &&
           key.value == "<<" &&
           key.tag != "tag:yaml.org,2002:str" &&
           solve_merge(stack, mapping, index, value, visited)
          break
        else
          yield({key, value})
        end
      end
    end
  end

  private def self.solve_merge(stack, mapping, index, value, visited)
    value = value.value if value.is_a?(YAML::Nodes::Alias)

    case value
    when YAML::Nodes::Mapping
      stack.push({mapping, index})

      unless visited.includes?(value)
        stack.push({value, 0})
      end

      true
    when YAML::Nodes::Sequence
      all_mappings = value.nodes.all? do |elem|
        elem = elem.value if elem.is_a?(YAML::Nodes::Alias)
        elem.is_a?(YAML::Nodes::Mapping)
      end

      if all_mappings
        stack.push({mapping, index})

        value.each do |elem|
          elem = elem.value if elem.is_a?(YAML::Nodes::Alias)
          mapping = elem.as(YAML::Nodes::Mapping)

          unless visited.includes?(mapping)
            stack.push({mapping, 0})
          end
        end

        true
      else
        false
      end
    else
      false
    end
  end

  protected def self.parse_binary(string, location) : Bytes
    Base64.decode(string)
  rescue ex : Base64::Error
    raise YAML::ParseException.new("Error decoding Base64: #{ex.message}", *location)
  end

  protected def self.parse_bool(string, location) : Bool
    value = parse_bool?(string)
    unless value.nil?
      return value
    end

    raise YAML::ParseException.new("Invalid bool", *location)
  end

  protected def self.parse_int(string, location) : Int64
    string.to_i64?(underscore: true, prefix: true) ||
      raise(YAML::ParseException.new("Invalid int", *location))
  end

  protected def self.parse_float(string, location) : Float64
    parse_float_infinity_and_nan?(string) ||
      parse_float?(string) ||
      raise(YAML::ParseException.new("Invalid float", *location))
  end

  protected def self.parse_null(string, location) : Nil
    if parse_null?(string)
      return nil
    end

    raise YAML::ParseException.new("Invalid null", *location)
  end

  protected def self.parse_time(string, location) : Time
    parse_time?(string) ||
      raise(YAML::ParseException.new("Invalid timestamp", *location))
  end

  protected def self.process_scalar_tag(scalar)
    process_scalar_tag(scalar, scalar.tag) do |value|
      yield value
    end
  end

  protected def self.process_scalar_tag(source, tag)
    case tag
    when "tag:yaml.org,2002:binary"
      yield parse_binary(source.value, source.location)
    when "tag:yaml.org,2002:bool"
      yield parse_bool(source.value, source.location)
    when "tag:yaml.org,2002:float"
      yield parse_float(source.value, source.location)
    when "tag:yaml.org,2002:int"
      yield parse_int(source.value, source.location)
    when "tag:yaml.org,2002:null"
      yield parse_null(source.value, source.location)
    when "tag:yaml.org,2002:str"
      yield source.value
    when "tag:yaml.org,2002:timestamp"
      yield parse_time(source.value, source.location)
    end
  end

  private def self.parse_null?(string)
    case string
    when .empty?, "~", "null", "Null", "NULL"
      true
    else
      false
    end
  end

  private def self.parse_bool?(string)
    case string
    when "yes", "Yes", "YES", "true", "True", "TRUE", "on", "On", "ON"
      true
    when "no", "No", "NO", "false", "False", "FALSE", "off", "Off", "OFF"
      false
    else
      nil
    end
  end

  private def self.parse_number?(string)
    parse_int?(string) || parse_float?(string)
  end

  private def self.parse_int?(string)
    string.to_i64?(underscore: true)
  end

  private def self.parse_float?(string)
    string = string.delete('_') if string.includes?('_')
    string.to_f64?
  end

  private def self.parse_float_infinity_and_nan?(string)
    case string
    when ".inf", ".Inf", ".INF", "+.inf", "+.Inf", "+.INF"
      Float64::INFINITY
    when "-.inf", "-.Inf", "-.INF"
      -Float64::INFINITY
    when ".nan", ".NaN", ".NAN"
      Float64::NAN
    else
      nil
    end
  end

  private def self.parse_time?(string)
    # Minimum length is that of YYYY-M-D
    return nil if string.size < 8

    TimeParser.new(string).parse
  end
end
