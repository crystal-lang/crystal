def Object.from_yaml(string_or_io : String | IO)
  new(YAML::ParseContext.new, parse_yaml(string_or_io))
end

def Array.from_yaml(string_or_io : String | IO)
  new(YAML::ParseContext.new, parse_yaml(string_or_io)) do |element|
    yield element
  end
end

private def parse_yaml(string_or_io)
  document = YAML::Nodes.parse(string_or_io)

  # If the document is empty we simulate an empty scalar with
  # plain style, that parses to Nil
  document.nodes.first? || begin
    scalar = YAML::Nodes::Scalar.new("")
    scalar.style = YAML::ScalarStyle::PLAIN
    scalar
  end
end

private def parse_scalar(ctx, node, type : T.class) forall T
  ctx.read_alias(node, T) do |obj|
    return obj
  end

  if node.is_a?(YAML::Nodes::Scalar)
    value = YAML::Schema::Core.parse_scalar(node)
    if value.is_a?(T)
      ctx.record_anchor(node, value)
      value
    else
      node.raise "Expected #{T}, not #{node.value}"
    end
  else
    node.raise "Expected #{T}, not #{node.class.name}"
  end
end

def Nil.new(ctx : YAML::ParseContext, node : YAML::Nodes::Node)
  parse_scalar(ctx, node, self)
end

def Bool.new(ctx : YAML::ParseContext, node : YAML::Nodes::Node)
  parse_scalar(ctx, node, self)
end

{% for type in %w(Int8 Int16 Int32 Int64 UInt8 UInt16 UInt32 UInt64) %}
  def {{type.id}}.new(ctx : YAML::ParseContext, node : YAML::Nodes::Node)
    {{type.id}}.new! parse_scalar(ctx, node, Int64)
  end
{% end %}

def String.new(ctx : YAML::ParseContext, node : YAML::Nodes::Node)
  ctx.read_alias(node, String) do |obj|
    return obj
  end

  if node.is_a?(YAML::Nodes::Scalar)
    value = node.value
    ctx.record_anchor(node, value)
    value
  else
    node.raise "Expected String, not #{node.class.name}"
  end
end

def Float32.new(ctx : YAML::ParseContext, node : YAML::Nodes::Node)
  parse_scalar(ctx, node, Float64).to_f32!
end

def Float64.new(ctx : YAML::ParseContext, node : YAML::Nodes::Node)
  parse_scalar(ctx, node, self)
end

def Array.new(ctx : YAML::ParseContext, node : YAML::Nodes::Node)
  ctx.read_alias(node, self) do |obj|
    return obj
  end

  ary = new

  ctx.record_anchor(node, ary)

  new(ctx, node) do |element|
    ary << element
  end
  ary
end

def Array.new(ctx : YAML::ParseContext, node : YAML::Nodes::Node)
  unless node.is_a?(YAML::Nodes::Sequence)
    node.raise "Expected sequence, not #{node.class}"
  end

  node.each do |value|
    yield T.new(ctx, value)
  end
end

def Set.new(ctx : YAML::ParseContext, node : YAML::Nodes::Node)
  ctx.read_alias(node, self) do |obj|
    return obj
  end

  ary = new

  ctx.record_anchor(node, ary)

  new(ctx, node) do |element|
    ary << element
  end
  ary
end

def Set.new(ctx : YAML::ParseContext, node : YAML::Nodes::Node)
  unless node.is_a?(YAML::Nodes::Sequence)
    node.raise "Expected sequence, not #{node.class}"
  end

  node.each do |value|
    yield T.new(ctx, value)
  end
end

def Hash.new(ctx : YAML::ParseContext, node : YAML::Nodes::Node)
  ctx.read_alias(node, self) do |obj|
    return obj
  end

  hash = new

  ctx.record_anchor(node, hash)

  new(ctx, node) do |key, value|
    hash[key] = value
  end
  hash
end

def Hash.new(ctx : YAML::ParseContext, node : YAML::Nodes::Node)
  unless node.is_a?(YAML::Nodes::Mapping)
    node.raise "Expected mapping, not #{node.class}"
  end

  YAML::Schema::Core.each(node) do |key, value|
    yield K.new(ctx, key), V.new(ctx, value)
  end
end

def Tuple.new(ctx : YAML::ParseContext, node : YAML::Nodes::Node)
  unless node.is_a?(YAML::Nodes::Sequence)
    node.raise "Expected sequence, not #{node.class}"
  end

  if node.nodes.size != {{T.size}}
    node.raise "Expected #{{{T.size}}} elements, not #{node.nodes.size}"
  end

  {% begin %}
    Tuple.new(
      {% for i in 0...T.size %}
        (self[{{i}}].new(ctx, node.nodes[{{i}}])),
      {% end %}
    )
 {% end %}
end

def NamedTuple.new(ctx : YAML::ParseContext, node : YAML::Nodes::Node)
  unless node.is_a?(YAML::Nodes::Mapping)
    node.raise "Expected mapping, not #{node.class}"
  end

  {% begin %}
    {% for key in T.keys %}
      %var{key.id} = nil
      %found{key.id} = false
    {% end %}

    YAML::Schema::Core.each(node) do |key, value|
      key = String.new(ctx, key)
      case key
        {% for key, type in T %}
          when {{key.stringify}}
            %var{key.id} = {{type}}.new(ctx, value)
            %found{key.id} = true
        {% end %}
      end
    end

    {% for key, type in T %}
      if %var{key.id}.nil? && !%found{key.id} && !{{type.nilable?}}
        node.raise "Missing yaml attribute: {{key}}"
      end
    {% end %}

    {
      {% for key, type in T %}
        {{key}}: (%var{key.id}).as({{type}}),
      {% end %}
    }
  {% end %}
end

def Enum.new(ctx : YAML::ParseContext, node : YAML::Nodes::Node)
  unless node.is_a?(YAML::Nodes::Scalar)
    node.raise "Expected scalar, not #{node.class}"
  end

  string = node.value
  if value = string.to_i64?
    from_value(value)
  else
    parse(string)
  end
end

def Union.new(ctx : YAML::ParseContext, node : YAML::Nodes::Node)
  if node.is_a?(YAML::Nodes::Alias)
    {% for type in T %}
      {% if type < ::Reference %}
        ctx.read_alias?(node, {{type}}) do |obj|
          return obj
        end
      {% end %}
    {% end %}

    node.raise("Error deserailizing alias")
  end

  {% begin %}
    # String must come last because anything can be parsed into a String.
    # So, we give a chance first to types in the union to be parsed.
    {% string_type = T.find { |type| type == ::String } %}

    {% for type in T %}
      {% unless type == string_type %}
        begin
          return {{type}}.new(ctx, node)
        rescue YAML::ParseException
          # Ignore
        end
      {% end %}
    {% end %}

    {% if string_type %}
      begin
        return {{string_type}}.new(ctx, node)
      rescue YAML::ParseException
        # Ignore
      end
    {% end %}
  {% end %}

  node.raise "Couldn't parse #{self}"
end

def Time.new(ctx : YAML::ParseContext, node : YAML::Nodes::Node)
  parse_scalar(ctx, node, Time)
end

struct Time::Format
  def from_yaml(ctx : YAML::ParseContext, node : YAML::Nodes::Node) : Time
    unless node.is_a?(YAML::Nodes::Scalar)
      node.raise "Expected scalar, not #{node.class}"
    end

    parse(node.value, Time::Location::UTC)
  end
end

module Time::EpochConverter
  def self.from_yaml(ctx : YAML::ParseContext, node : YAML::Nodes::Node) : Time
    unless node.is_a?(YAML::Nodes::Scalar)
      node.raise "Expected scalar, not #{node.class}"
    end

    Time.unix(node.value.to_i)
  end
end

module Time::EpochMillisConverter
  def self.from_yaml(ctx : YAML::ParseContext, node : YAML::Nodes::Node) : Time
    unless node.is_a?(YAML::Nodes::Scalar)
      node.raise "Expected scalar, not #{node.class}"
    end

    Time.unix_ms(node.value.to_i64)
  end
end

module YAML::ArrayConverter(Converter)
  def self.from_yaml(ctx : YAML::ParseContext, node : YAML::Nodes::Node) : Array
    unless node.is_a?(YAML::Nodes::Sequence)
      node.raise "Expected sequence, not #{node.class}"
    end

    ary = Array(typeof(Converter.from_yaml(ctx, node))).new

    node.each do |value|
      ary << Converter.from_yaml(ctx, value)
    end

    ary
  end
end

struct Slice
  def self.new(ctx : YAML::ParseContext, node : YAML::Nodes::Node)
    {% if T != UInt8 %}
      {% raise "Can only deserialize Slice(UInt8), not #{@type}}" %}
    {% end %}

    parse_scalar(ctx, node, self)
  end
end
