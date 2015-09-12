def Object.from_yaml(string : String)
  parser = YAML::PullParser.new(string)
  parser.read_stream do
    parser.read_document do
      new parser
    end
  end
end

def Array.from_yaml(string : String)
  parser = YAML::PullParser.new(string)
  parser.read_stream do
    parser.read_document do
      new(parser) do |element|
        yield element
      end
    end
  end
end

def Nil.new(pull : YAML::PullParser)
  pull.read_scalar
  nil
end

def Bool.new(pull : YAML::PullParser)
  pull.read_scalar == "true"
end

def Int32.new(pull : YAML::PullParser)
  pull.read_scalar.to_i
end

def Int64.new(pull : YAML::PullParser)
  pull.read_scalar.to_i64
end

def String.new(pull : YAML::PullParser)
  pull.read_scalar
end

def Float32.new(pull : YAML::PullParser)
  pull.read_scalar.to_f32
end

def Float64.new(pull : YAML::PullParser)
  pull.read_scalar.to_f64
end

def Array.new(pull : YAML::PullParser)
  ary = new
  new(pull) do |element|
    ary << element
  end
  ary
end

def Array.new(pull : YAML::PullParser)
  pull.read_sequence_start
  while pull.kind != YAML::EventKind::SEQUENCE_END
    yield T.new(pull)
  end
  pull.read_next
end

def Hash.new(pull : YAML::PullParser)
  hash = new
  new(pull) do |key, value|
    hash[key] = value
  end
  hash
end

def Hash.new(pull : YAML::PullParser)
  pull.read_mapping_start
  while pull.kind != YAML::EventKind::MAPPING_END
    yield K.new(pull), V.new(pull)
  end
  pull.read_next
end

def Tuple.new(pull : YAML::PullParser)
  {% if true %}
    pull.read_sequence_start
    value = Tuple.new(
      {% for i in 0 ... @type.length %}
        (self[{{i}}].new(pull)),
      {% end %}
    )
    pull.read_sequence_end
    value
 {% end %}
end

struct TimeFormat
  def from_yaml(pull : YAML::PullParser)
    string = pull.read_scalar
    parse(string)
  end
end
