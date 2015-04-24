require "spec"
require "json"

class JSON::PullParser
  def assert(event_kind : Symbol)
    expect(kind).to eq(event_kind)
    read_next
  end

  def assert(value : Nil)
    expect(kind).to eq(:null)
    read_next
  end

  def assert(value : Int)
    expect(kind).to eq(:int)
    expect(int_value).to eq(value)
    read_next
  end

  def assert(value : Float)
    expect(kind).to eq(:float)
    expect(float_value).to eq(value)
    read_next
  end

  def assert(value : Bool)
    expect(kind).to eq(:bool)
    expect(bool_value).to eq(value)
    read_next
  end

  def assert(value : String)
    expect(kind).to eq(:string)
    expect(string_value).to eq(value)
    read_next
  end

  def assert(value : String)
    expect(kind).to eq(:object_key)
    expect(string_value).to eq(value)
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
        assert(key as String) do
          assert value
        end
      end
    end
  end

  def assert_array
    expect(kind).to eq(:begin_array)
    read_next
    yield
    expect(kind).to eq(:end_array)
    read_next
  end

  def assert_array
    assert_array {}
  end

  def assert_object
    expect(kind).to eq(:begin_object)
    read_next
    yield
    expect(kind).to eq(:end_object)
    read_next
  end

  def assert_object
    assert_object {}
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
    parser.assert JSON.parse(string)
    expect(parser.kind).to eq(:EOF)
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

describe "JSON::PullParser" do
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

  describe "skip" do
    [
      {"null", "null"},
      {"bool", "false"},
      {"int", "3"},
      {"float", "3.5"},
      {"string", %("hello")},
      {"array", %([10, 20, [30], [40]])},
      {"object", %({"foo": [1, 2], "bar": {"baz": [3]}})},
    ].each do |tuple|
      it "skips #{tuple[0]}" do
        pull = JSON::PullParser.new("[1, #{tuple[1]}, 2]")
        pull.read_array do
          expect(pull.read_int).to eq(1)
          pull.skip
          expect(pull.read_int).to eq(2)
        end
      end
    end
  end

  it "reads bool or null" do
    expect(JSON::PullParser.new("null").read_bool_or_null).to be_nil
    expect(JSON::PullParser.new("false").read_bool_or_null).to be_false
  end

  it "reads int or null" do
    expect(JSON::PullParser.new("null").read_int_or_null).to be_nil
    expect(JSON::PullParser.new("1").read_int_or_null).to eq(1)
  end

  it "reads float or null" do
    expect(JSON::PullParser.new("null").read_float_or_null).to be_nil
    expect(JSON::PullParser.new("1.5").read_float_or_null).to eq(1.5)
  end

  it "reads string or null" do
    expect(JSON::PullParser.new("null").read_string_or_null).to be_nil
    expect(JSON::PullParser.new(%("hello")).read_string_or_null).to eq("hello")
  end

  it "reads array or null" do
    JSON::PullParser.new("null").read_array_or_null { fail "expected block not to be called" }

    pull = JSON::PullParser.new(%([1]))
    pull.read_array_or_null do
      expect(pull.read_int).to eq(1)
    end
  end

  it "reads object or null" do
    JSON::PullParser.new("null").read_object_or_null { fail "expected block not to be called" }

    pull = JSON::PullParser.new(%({"foo": 1}))
    pull.read_object_or_null do |key|
      expect(key).to eq("foo")
      expect(pull.read_int).to eq(1)
    end
  end

  describe "on key" do
    it "finds key" do
      pull = JSON::PullParser.new(%({"foo": 1, "bar": 2}))

      bar = nil
      pull.on_key("bar") do
        bar = pull.read_int
      end

      expect(bar).to eq(2)
    end

    it "finds key" do
      pull = JSON::PullParser.new(%({"foo": 1, "bar": 2}))

      bar = nil
      pull.on_key("bar") do
        bar = pull.read_int
      end

      expect(bar).to eq(2)
    end

    it "doesn't find key" do
      pull = JSON::PullParser.new(%({"foo": 1, "baz": 2}))

      bar = nil
      pull.on_key("bar") do
        bar = pull.read_int
      end

      expect(bar).to be_nil
    end

    it "finds key with bang" do
      pull = JSON::PullParser.new(%({"foo": 1, "bar": 2}))

      bar = nil
      pull.on_key!("bar") do
        bar = pull.read_int
      end

      expect(bar).to eq(2)
    end

    it "doesn't find key with bang" do
      pull = JSON::PullParser.new(%({"foo": 1, "baz": 2}))

      expect_raises Exception, "json key not found: bar" do
        pull.on_key!("bar") do
        end
      end
    end

    it "reads float when it is an int" do
      pull = JSON::PullParser.new(%(1))
      f = pull.read_float
      expect(f).to be_a(Float64)
      expect(f).to eq(1.0)
    end

    ["1", "[1]", %({"x": [1]})].each do |value|
      it "yields all keys when skipping #{value}" do
        pull = JSON::PullParser.new(%({"foo": #{value}, "bar": 2}))
        pull.read_object do |key|
          expect(key).to_not eq("")
          pull.skip
        end
      end
    end
  end
end
