require "spec"
require "json"

class Json::PullParser
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
    kind.should eq(:object_key)
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
        assert(key as String) do
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
    assert_array {}
  end

  def assert_object
    kind.should eq(:begin_object)
    read_next
    yield
    kind.should eq(:end_object)
    read_next
  end

  def assert_object
    assert_object {}
  end

  def assert_error
    read_next
    fail "expected to raise"
  rescue Json::ParseException
  end
end

def assert_pull_parse(string)
  it "parses #{string}" do
    parser = Json::PullParser.new string
    parser.assert Json.parse(string)
    parser.kind.should eq(:EOF)
  end
end

def assert_pull_parse_error(string)
  it "errors on #{string}" do
    begin
      parser = Json::PullParser.new string
      while parser.kind != :EOF
        parser.read_next
      end
      fail "expected to raise"
    rescue Json::ParseException
    end
  end
end

describe "Json::PullParser" do
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

  assert_pull_parse_error "null"
  assert_pull_parse_error "false"
  assert_pull_parse_error "true"
  assert_pull_parse_error %("hello")
  assert_pull_parse_error "1"
  assert_pull_parse_error "1.5"
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
end
