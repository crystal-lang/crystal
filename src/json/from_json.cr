def Object.from_json(string_or_io)
  parser = JSON::PullParser.new(string_or_io)
  new parser
end

def Array.from_json(string_or_io)
  parser = JSON::PullParser.new(string_or_io)
  new(parser) do |element|
    yield element
  end
end

def Nil.new(pull : JSON::PullParser)
  pull.read_null
end

def Bool.new(pull : JSON::PullParser)
  pull.read_bool
end

def Int32.new(pull : JSON::PullParser)
  pull.read_int.to_i
end

def Int64.new(pull : JSON::PullParser)
  pull.read_int.to_i64
end

def Float32.new(pull : JSON::PullParser)
  case pull.kind
  when :int
    value = pull.int_value.to_f32
    pull.read_next
    value
  else
    pull.read_float.to_f32
  end
end

def Float64.new(pull : JSON::PullParser)
  case pull.kind
  when :int
    value = pull.int_value.to_f
    pull.read_next
    value
  else
    pull.read_float.to_f
  end
end

def String.new(pull : JSON::PullParser)
  pull.read_string
end

def Array.new(pull : JSON::PullParser)
  ary = new
  new(pull) do |element|
    ary << element
  end
  ary
end

def Array.new(pull : JSON::PullParser)
  pull.read_array do
    yield T.new(pull)
  end
end

def Set.new(pull : JSON::PullParser)
  set = new
  pull.read_array do
    set << T.new(pull)
  end
  set
end

def Hash.new(pull : JSON::PullParser)
  hash = new
  pull.read_object do |key|
    if pull.kind == :null
      pull.read_next
    else
      hash[key] = V.new(pull)
    end
  end
  hash
end

def Tuple.new(pull : JSON::PullParser)
  {% if true %}
    pull.read_begin_array
    value = Tuple.new(
      {% for i in 0...@type.size %}
        (self[{{i}}].new(pull)),
      {% end %}
    )
    pull.read_end_array
    value
 {% end %}
end

struct Time::Format
  def from_json(pull : JSON::PullParser)
    string = pull.read_string
    parse(string)
  end
end
