require "spec"
require "json"

class JSON::PullParser
  def assert(event_kind : Kind)
    kind.should eq(event_kind)
    read_next
  end

  def assert(value : Nil)
    kind.should eq(JSON::PullParser::Kind::Null)
    read_next
  end

  def assert(value : Int)
    kind.should eq(JSON::PullParser::Kind::Int)
    int_value.should eq(value)
    read_next
  end

  def assert(value : Float)
    kind.should eq(JSON::PullParser::Kind::Float)
    float_value.should eq(value)
    read_next
  end

  def assert(value : Bool)
    kind.should eq(JSON::PullParser::Kind::Bool)
    bool_value.should eq(value)
    read_next
  end

  def assert(value : String)
    kind.should eq(JSON::PullParser::Kind::String)
    string_value.should eq(value)
    read_next
  end

  def assert(value : String, &)
    kind.should eq(JSON::PullParser::Kind::String)
    string_value.should eq(value)
    read_next
    yield
  end

  def assert(array : Array)
    assert_array do
      array.each do |x|
        assert x.raw
      end
    end
  end

  def assert(hash : Hash)
    assert_object do
      hash.each do |key, value|
        assert(key) do
          assert value.raw
        end
      end
    end
  end

  def assert_array(&)
    kind.should eq(JSON::PullParser::Kind::BeginArray)
    read_next
    yield
    kind.should eq(JSON::PullParser::Kind::EndArray)
    read_next
  end

  def assert_array
    assert_array { }
  end

  def assert_object(&)
    kind.should eq(JSON::PullParser::Kind::BeginObject)
    read_next
    yield
    kind.should eq(JSON::PullParser::Kind::EndObject)
    read_next
  end

  def assert_object
    assert_object { }
  end

  def assert_error
    expect_raises JSON::ParseException do
      read_next
    end
  end
end

private def assert_pull_parse(string)
  it "parses #{string}" do
    parser = JSON::PullParser.new string
    parser.assert JSON.parse(string).raw
    parser.kind.should eq(JSON::PullParser::Kind::EOF)
  end
end

private def assert_pull_parse_error(string)
  it "errors on #{string}" do
    expect_raises JSON::ParseException do
      parser = JSON::PullParser.new string
      until parser.kind.eof?
        parser.read_next
      end
    end
  end
end

private def assert_raw(string, file = __FILE__, line = __LINE__)
  it "parses raw #{string.inspect}", file, line do
    pull = JSON::PullParser.new(string)
    pull.read_raw.should eq(string)
  end
end

private def it_reads(value, file = __FILE__, line = __LINE__)
  type = value.class
  it "reads #{type}: #{value.to_json}", file: file, line: line do
    pull = JSON::PullParser.new(value.to_json)
    pull.read?(type).should eq(value)
  end
end

describe JSON::PullParser do
  assert_pull_parse "null"
  assert_pull_parse "false"
  assert_pull_parse "true"
  assert_pull_parse "1"
  assert_pull_parse "1.5"
  assert_pull_parse %("hello")
  assert_pull_parse "[]"
  assert_pull_parse "[[]]"
  assert_pull_parse "[1]"
  assert_pull_parse "[1.5]"
  assert_pull_parse "[null]"
  assert_pull_parse "[true]"
  assert_pull_parse "[false]"
  assert_pull_parse %(["hello"])
  assert_pull_parse "[1, 2]"
  assert_pull_parse "{}"
  assert_pull_parse %({"foo": 1})
  assert_pull_parse %({"foo": "bar"})
  assert_pull_parse %({"foo": [1, 2]})
  assert_pull_parse %({"foo": 1, "bar": 2})
  assert_pull_parse %({"foo": "foo1", "bar": "bar1"})

  assert_pull_parse_error "[null 2]"
  assert_pull_parse_error "[false 2]"
  assert_pull_parse_error "[true 2]"
  assert_pull_parse_error "[1 2]"
  assert_pull_parse_error "[1.5 2]"
  assert_pull_parse_error %(["hello" 2])
  assert_pull_parse_error "[,1]"
  assert_pull_parse_error "[}]"
  assert_pull_parse_error "["
  assert_pull_parse_error %({,"foo": 1})
  assert_pull_parse_error "[]]"
  assert_pull_parse_error "{}}"
  assert_pull_parse_error %({"foo",1})
  assert_pull_parse_error %({"foo"::1})
  assert_pull_parse_error %(["foo":1])
  assert_pull_parse_error %({"foo": []:1})
  assert_pull_parse_error "[[]"
  assert_pull_parse_error %({"foo": {})
  assert_pull_parse_error %({"name": "John", "age", 1})
  assert_pull_parse_error %({"name": "John", "age": "foo", "bar"})

  it "parses when the input IO is already empty" do
    JSON::PullParser.new(IO::Memory.new).kind.should eq JSON::PullParser::Kind::EOF
  end

  it "prevents stack overflow for arrays" do
    parser = JSON::PullParser.new(("[" * 513) + ("]" * 513))
    expect_raises JSON::ParseException, "Nesting of 513 is too deep" do
      while true
        break if parser.kind.eof?
        parser.read_next
      end
    end
  end

  it "prevents stack overflow for hashes" do
    parser = JSON::PullParser.new((%({"x": ) * 513) + ("}" * 513))
    expect_raises JSON::ParseException, "Nesting of 513 is too deep" do
      while true
        break if parser.kind.eof?
        parser.read_next
      end
    end
  end

  # Prevent too deep nesting (prevents stack overflow)
  assert_pull_parse_error(("[" * 513) + ("]" * 513))
  assert_pull_parse_error(("{" * 513) + ("}" * 513))

  describe "skip" do
    [
      {"null", "null"},
      {"bool", "false"},
      {"int", "3"},
      {"float", "3.5"},
      {"string", %("hello")},
      {"array", %([10, 20, [30], [40]])},
      {"object", %({"foo": [1, 2], "bar": {"baz": [3]}})},
    ].each do |(desc, obj)|
      it "skips #{desc}" do
        pull = JSON::PullParser.new("[1, #{obj}, 2]")
        pull.read_array do
          pull.read_int.should eq(1)
          pull.skip
          pull.read_int.should eq(2)
        end
      end
    end
  end

  it "reads bool or null" do
    JSON::PullParser.new("null").read_bool_or_null.should be_nil
    JSON::PullParser.new("false").read_bool_or_null.should be_false
  end

  it "reads int or null" do
    JSON::PullParser.new("null").read_int_or_null.should be_nil
    JSON::PullParser.new("1").read_int_or_null.should eq(1)
  end

  it "reads float or null" do
    JSON::PullParser.new("null").read_float_or_null.should be_nil
    JSON::PullParser.new("1.5").read_float_or_null.should eq(1.5)
  end

  it "reads string or null" do
    JSON::PullParser.new("null").read_string_or_null.should be_nil
    JSON::PullParser.new(%("hello")).read_string_or_null.should eq("hello")
  end

  it "reads array or null" do
    JSON::PullParser.new("null").read_array_or_null { fail "expected block not to be called" }

    pull = JSON::PullParser.new(%([1]))
    pull.read_array_or_null do
      pull.read_int.should eq(1)
    end
  end

  it "reads object or null" do
    JSON::PullParser.new("null").read_object_or_null { fail "expected block not to be called" }

    pull = JSON::PullParser.new(%({"foo": 1}))
    pull.read_object_or_null do |key|
      key.should eq("foo")
      pull.read_int.should eq(1)
    end
  end

  describe "on key" do
    it "finds key" do
      pull = JSON::PullParser.new(%({"foo": 1, "bar": 2}))

      bar = nil
      pull.on_key("bar") do
        bar = pull.read_int
      end

      bar.should eq(2)
    end

    it "yields parser" do
      pull = JSON::PullParser.new(%({"foo": 1, "bar": 2}))

      pull.on_key("bar", &.read_int).should eq(2)
    end

    it "doesn't find key" do
      pull = JSON::PullParser.new(%({"foo": 1, "baz": 2}))

      bar = nil
      pull.on_key("bar") do
        bar = pull.read_int
      end

      bar.should be_nil
    end

    it "finds key with bang" do
      pull = JSON::PullParser.new(%({"foo": 1, "bar": 2}))

      bar = nil
      pull.on_key!("bar") do
        bar = pull.read_int
      end

      bar.should eq(2)
    end

    it "yields parser with bang" do
      pull = JSON::PullParser.new(%({"foo": 1, "bar": 2}))

      pull.on_key!("bar", &.read_int).should eq(2)
    end

    it "doesn't find key with bang" do
      pull = JSON::PullParser.new(%({"foo": 1, "baz": 2}))

      expect_raises Exception, "JSON key not found: bar" do
        pull.on_key!("bar") do
        end
      end
    end

    it "reads float when it is an int" do
      pull = JSON::PullParser.new(%(1))
      f = pull.read_float
      f.should be_a(Float64)
      f.should eq(1.0)
    end

    ["1", "[1]", %({"x": [1]})].each do |value|
      it "yields all keys when skipping #{value}" do
        pull = JSON::PullParser.new(%({"foo": #{value}, "bar": 2}))
        pull.read_object do |key|
          key.should_not eq("")
          pull.skip
        end
      end
    end
  end

  describe "raw" do
    assert_raw "null"
    assert_raw "true"
    assert_raw "false"
    assert_raw "1234"
    assert_raw "1234.5678"
    assert_raw %("hello")
    assert_raw %([1,"hello",true,false,null,[1,2,3]])
    assert_raw %({"foo":[1,2,{"bar":[1,"hello",true,false,1.5]}]})
    assert_raw %({"foo":"bar"})
  end

  describe "#read?" do
    {% for pair in [[Int8, 1_i8],
                    [Int16, 1_i16],
                    [Int32, 1_i32],
                    [Int64, 1_i64],
                    [Int128, "Int128.new(1)".id],
                    [UInt8, 1_u8],
                    [UInt16, 1_u16],
                    [UInt32, 1_u32],
                    [UInt64, 1_u64],
                    [UInt128, "UInt128.new(1)".id],
                    [Float32, 1.0_f32],
                    [Float64, 1.0],
                    [String, "foo"],
                    [Bool, true]] %}
      {% type = pair[0] %}
      {% value = pair[1] %}

      it "reads {{ type }} when the token is a compatible kind" do
        pull = JSON::PullParser.new({{ value }}.to_json)
        pull.read?({{ type }}).should eq({{ value }})
      end

      it "returns nil instead of {{ type }} when the token is not compatible" do
        pull = JSON::PullParser.new(%({"foo": "bar"}))
        pull.read?({{ type }}).should be_nil
      end
    {% end %}

    {% for num in Int::Primitive.union_types %}
      it_reads {{ num }}::MIN
      {% unless num < Int::Unsigned %}
        it_reads {{ num }}.new(-10)
        it_reads {{ num }}.zero
      {% end %}
      it_reads {{ num }}.new(10)
      it_reads {{ num }}::MAX
    {% end %}

    {% for i in [8, 16, 32, 64, 128] %}
      it "returns nil in place of Int{{ i }} when an overflow occurs" do
        JSON::PullParser.new(Int{{ i }}::MAX.to_s + "0").read?(Int{{ i }}).should be_nil
        JSON::PullParser.new(Int{{ i }}::MIN.to_s + "0").read?(Int{{ i }}).should be_nil
      end

      it "returns nil in place of UInt{{ i }} when an overflow occurs" do
        JSON::PullParser.new(UInt{{ i }}::MAX.to_s + "0").read?(UInt{{ i }}).should be_nil
        JSON::PullParser.new("-1").read?(UInt{{ i }}).should be_nil
      end
    {% end %}

    it "reads > Float32::MAX" do
      pull = JSON::PullParser.new(Float64::MAX.to_s)
      pull.read?(Float32).should be_nil
    end

    it "reads < Float32::MIN" do
      pull = JSON::PullParser.new(Float64::MIN.to_s)
      pull.read?(Float32).should be_nil
    end

    it "reads > Float64::MAX" do
      pull = JSON::PullParser.new("1" + Float64::MAX.to_s)
      pull.read?(Float64).should be_nil
    end

    it "reads < Float64::MIN" do
      pull = JSON::PullParser.new("-1" + Float64::MAX.to_s)
      pull.read?(Float64).should be_nil
    end

    it "doesn't accept nan or infinity" do
      pull = JSON::PullParser.new(%("nan"))
      pull.read?(Float64).should be_nil

      pull = JSON::PullParser.new(%("infinity"))
      pull.read?(Float64).should be_nil

      pull = JSON::PullParser.new(%("+infinity"))
      pull.read?(Float64).should be_nil

      pull = JSON::PullParser.new(%("-infinity"))
      pull.read?(Float64).should be_nil
    end
  end

  it "#raise" do
    pull = JSON::PullParser.new("[1, 2, 3]")
    expect_raises(JSON::ParseException, "foo bar at line 1, column 2") do
      pull.raise "foo bar"
    end
    pull.read_begin_array
    expect_raises(JSON::ParseException, "foo bar at line 1, column 3") do
      pull.raise "foo bar"
    end
  end
end
