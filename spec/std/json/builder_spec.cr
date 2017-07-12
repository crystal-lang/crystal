require "spec"
require "json"

private def assert_built(expected)
  string = JSON.build do |json|
    with json yield json
  end
  string.should eq(expected)
end

private class TestObject
  def to_json(builder)
    {"int" => 12}.to_json(builder)
  end
end

describe JSON::Builder do
  it "writes null" do
    assert_built("null") do
      null
    end
  end

  it "writes bool" do
    assert_built("true") do
      bool(true)
    end
  end

  it "writes integer" do
    assert_built("123") do
      number(123)
    end
  end

  it "writes float" do
    assert_built("123.45") do
      number(123.45)
    end
  end

  it "errors on nan" do
    json = JSON::Builder.new(IO::Memory.new)
    json.start_document
    expect_raises JSON::Error, "NaN not allowed in JSON" do
      json.number(0.0/0.0)
    end
  end

  it "errors on infinity" do
    json = JSON::Builder.new(IO::Memory.new)
    json.start_document
    expect_raises JSON::Error, "Infinity not allowed in JSON" do
      json.number(1.0/0.0)
    end
  end

  it "writes string" do
    assert_built(%<"hello">) do
      string("hello")
    end
  end

  it "writes string with controls and slashes " do
    assert_built("\" \\\" \\\\ \\b \\f \\n \\r \\t \\u0019 \"") do
      string(" \" \\ \b \f \n \r \t \u{19} ")
    end
  end

  it "errors if writing before document start" do
    json = JSON::Builder.new(IO::Memory.new)
    expect_raises JSON::Error, "Write before start_document" do
      json.number(1)
    end
  end

  it "errors if writing two scalars" do
    json = JSON::Builder.new(IO::Memory.new)
    json.start_document
    json.number(1)
    expect_raises JSON::Error, "Write past end_document and before start_document" do
      json.number(2)
    end
  end

  it "writes array" do
    assert_built(%<[1,"hello",true]>) do
      array do
        number(1)
        string("hello")
        bool(true)
      end
    end
  end

  it "writes nested array" do
    assert_built(%<[1,["hello",true],2]>) do
      array do
        number(1)
        array do
          string("hello")
          bool(true)
        end
        number(2)
      end
    end
  end

  it "writes object" do
    assert_built(%<{"foo":1,"bar":2}>) do
      object do
        string("foo")
        number(1)
        string("bar")
        number(2)
      end
    end
  end

  it "writes nested object" do
    assert_built(%<{"foo":{"bar":2,"baz":3},"another":{"baz":3}}>) do
      object do
        string("foo")
        object do
          string("bar")
          number(2)
          string("baz")
          number(3)
        end
        string("another")
        object do
          string("baz")
          number(3)
        end
      end
    end
  end

  it "writes array with indent level" do
    assert_built(%<[\n  1,\n  2,\n  3\n]>) do |json|
      json.indent = 2
      array do
        number(1)
        number(2)
        number(3)
      end
    end
  end

  it "writes array with indent string" do
    assert_built(%<[\n\t1,\n\t2,\n\t3\n]>) do |json|
      json.indent = "\t"
      array do
        number(1)
        number(2)
        number(3)
      end
    end
  end

  it "writes object with indent level" do
    assert_built(%<{\n  "foo": 1,\n  "bar": 2\n}>) do |json|
      json.indent = 2
      object do
        string "foo"
        number(1)
        string "bar"
        number(2)
      end
    end
  end

  it "writes empty array with indent level" do
    assert_built(%<[]>) do |json|
      json.indent = 2
      array do
      end
    end
  end

  it "writes empty object with indent level" do
    assert_built(%<{}>) do |json|
      json.indent = 2
      object do
      end
    end
  end

  it "writes nested array" do
    assert_built(%<[\n  []\n]>) do |json|
      json.indent = 2
      array do
        array do
        end
      end
    end
  end

  it "writes object with scalar and indent" do
    assert_built(%<{\n  "foo": 1\n}>) do |json|
      json.indent = 2
      object do
        string "foo"
        number 1
      end
    end
  end

  it "writes object with array and scalar and indent" do
    assert_built(%<{\n  "foo": [\n    1\n  ]\n}>) do |json|
      json.indent = 2
      object do
        string "foo"
        array do
          number 1
        end
      end
    end
  end

  it "writes raw" do
    assert_built(%<{\n  "foo": [1, 2, 3],\n  "bar": [\n    [4, 5, 6]\n  ]\n}>) do |json|
      json.indent = 2
      object do
        string "foo"
        raw "[1, 2, 3]"
        string "bar"
        array do
          raw "[4, 5, 6]"
        end
      end
    end
  end

  it "raises if nothing written" do
    json = JSON::Builder.new(IO::Memory.new)
    json.start_document
    expect_raises JSON::Error, "Empty JSON" do
      json.end_document
    end
  end

  it "raises if array is left open" do
    json = JSON::Builder.new(IO::Memory.new)
    json.start_document
    json.start_array
    expect_raises JSON::Error, "Unterminated JSON array" do
      json.end_document
    end
  end

  it "raises if object is left open" do
    json = JSON::Builder.new(IO::Memory.new)
    json.start_document
    json.start_object
    expect_raises JSON::Error, "Unterminated JSON object" do
      json.end_document
    end
  end

  it "writes field with scalar in object" do
    assert_built(%<{"int":42,"float":0.815,"null":null,"bool":true,"string":"string"}>) do
      object do
        field "int", 42
        field "float", 0.815
        field "null", nil
        field "bool", true
        field "string", "string"
      end
    end
  end

  it "writes field with arbitrary value in object" do
    assert_built(%<{"hash":{"hash":"value"},"object":{"int":12}}>) do
      object do
        field "hash", {"hash" => "value"}
        field "object", TestObject.new
      end
    end
  end
end
