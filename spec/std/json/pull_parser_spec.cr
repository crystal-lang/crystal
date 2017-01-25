require "spec"
require "json"

class JSON::PullParser
  def assert(event_kind : Symbol)
    kind.should eq(event_kind)
    read_next
  end

  def assert(value : Nil)
    kind.should eq(:null)
    read_next
  end

  def assert(value : Int)
    kind.should eq(:int)
    int_value.should eq(value)
    read_next
  end

  def assert(value : Float)
    kind.should eq(:float)
    float_value.should eq(value)
    read_next
  end

  def assert(value : Bool)
    kind.should eq(:bool)
    bool_value.should eq(value)
    read_next
  end

  def assert(value : String)
    kind.should eq(:string)
    string_value.should eq(value)
    read_next
  end

  def assert(value : String)
    kind.should eq(:string)
    string_value.should eq(value)
    read_next
    yield
  end

  def assert(array : Array)
    assert_array do
      array.each do |x|
        assert x
      end
    end
  end

  def assert(hash : Hash)
    assert_object do
      hash.each do |key, value|
        assert(key.as(String)) do
          assert value
        end
      end
    end
  end

  def assert_array
    kind.should eq(:begin_array)
    read_next
    yield
    kind.should eq(:end_array)
    read_next
  end

  def assert_array
    assert_array { }
  end

  def assert_object
    kind.should eq(:begin_object)
    read_next
    yield
    kind.should eq(:end_object)
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
    parser.kind.should eq(:EOF)
  end
end

private def assert_pull_parse_error(string)
  it "errors on #{string}" do
    expect_raises JSON::ParseException do
      parser = JSON::PullParser.new string
      while parser.kind != :EOF
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

  it "prevents stack overflow for arrays" do
    parser = JSON::PullParser.new(("[" * 513) + ("]" * 513))
    expect_raises JSON::ParseException, "Nesting of 513 is too deep" do
      while true
        break if parser.kind == :EOF
        parser.read_next
      end
    end
  end

  it "prevents stack overflow for hashes" do
    parser = JSON::PullParser.new((%({"x": ) * 513) + ("}" * 513))
    expect_raises JSON::ParseException, "Nesting of 513 is too deep" do
      while true
        break if parser.kind == :EOF
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

    it "finds key" do
      pull = JSON::PullParser.new(%({"foo": 1, "bar": 2}))

      bar = nil
      pull.on_key("bar") do
        bar = pull.read_int
      end

      bar.should eq(2)
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
end
