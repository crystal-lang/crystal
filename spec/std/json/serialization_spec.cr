require "spec"
require "json"
require "big"
require "big/json"

enum JSONSpecEnum
  Zero
  One
  Two
end

describe "JSON serialization" do
  describe "from_json" do
    it "does Array(Nil)#from_json" do
      Array(Nil).from_json("[null, null]").should eq([nil, nil])
    end

    it "does Array(Bool)#from_json" do
      Array(Bool).from_json("[true, false]").should eq([true, false])
    end

    it "does Array(Int32)#from_json" do
      Array(Int32).from_json("[1, 2, 3]").should eq([1, 2, 3])
    end

    it "does Array(Int64)#from_json" do
      Array(Int64).from_json("[1, 2, 3]").should eq([1, 2, 3])
    end

    it "does Array(Float32)#from_json" do
      Array(Float32).from_json("[1.5, 2, 3.5]").should eq([1.5, 2.0, 3.5])
    end

    it "does Array(Float64)#from_json" do
      Array(Float64).from_json("[1.5, 2, 3.5]").should eq([1.5, 2, 3.5])
    end

    it "does Hash(String, String)#from_json" do
      Hash(String, String).from_json(%({"foo": "x", "bar": "y"})).should eq({"foo" => "x", "bar" => "y"})
    end

    it "does Hash(String, Int32)#from_json" do
      Hash(String, Int32).from_json(%({"foo": 1, "bar": 2})).should eq({"foo" => 1, "bar" => 2})
    end

    it "does Hash(String, Int32)#from_json and skips null" do
      Hash(String, Int32).from_json(%({"foo": 1, "bar": 2, "baz": null})).should eq({"foo" => 1, "bar" => 2})
    end

    it "does for Array(Int32) from IO" do
      io = IO::Memory.new "[1, 2, 3]"
      Array(Int32).from_json(io).should eq([1, 2, 3])
    end

    it "does for Array(Int32) with block" do
      elements = [] of Int32
      ret = Array(Int32).from_json("[1, 2, 3]") do |element|
        elements << element
      end
      ret.should be_nil
      elements.should eq([1, 2, 3])
    end

    it "does for tuple" do
      tuple = Tuple(Int32, String).from_json(%([1, "hello"]))
      tuple.should eq({1, "hello"})
      tuple.should be_a(Tuple(Int32, String))
    end

    it "does for named tuple" do
      tuple = NamedTuple(x: Int32, y: String).from_json(%({"y": "hello", "x": 1}))
      tuple.should eq({x: 1, y: "hello"})
      tuple.should be_a(NamedTuple(x: Int32, y: String))
    end

    it "does for BigInt" do
      big = BigInt.from_json("123456789123456789123456789123456789123456789")
      big.should be_a(BigInt)
      big.should eq(BigInt.new("123456789123456789123456789123456789123456789"))
    end

    it "does for BigFloat" do
      big = BigFloat.from_json("1234.567891011121314")
      big.should be_a(BigFloat)
      big.should eq(BigFloat.new("1234.567891011121314"))
    end

    it "does for BigFloat from int" do
      big = BigFloat.from_json("1234")
      big.should be_a(BigFloat)
      big.should eq(BigFloat.new("1234"))
    end

    it "does for Enum with number" do
      JSONSpecEnum.from_json("1").should eq(JSONSpecEnum::One)

      expect_raises do
        JSONSpecEnum.from_json("3")
      end
    end

    it "does for Enum with string" do
      JSONSpecEnum.from_json(%("One")).should eq(JSONSpecEnum::One)

      expect_raises do
        JSONSpecEnum.from_json(%("Three"))
      end
    end

    it "deserializes with root" do
      Int32.from_json(%({"foo": 1}), root: "foo").should eq(1)
      Array(Int32).from_json(%({"foo": [1, 2]}), root: "foo").should eq([1, 2])
    end

    it "deserializes union" do
      Array(Int32 | String).from_json(%([1, "hello"])).should eq([1, "hello"])
    end

    it "deserializes union with bool (fast path)" do
      Union(Bool, Array(Int32)).from_json(%(true)).should be_true
    end

    {% for type in %w(Int8 Int16 Int32 Int64 UInt8 UInt16 UInt32 UInt64).map(&.id) %}
        it "deserializes union with {{type}} (fast path)" do
          Union({{type}}, Array(Int32)).from_json(%(#{ {{type}}::MAX })).should eq({{type}}::MAX)
        end
      {% end %}

    it "deserializes union with Float32 (fast path)" do
      Union(Float32, Array(Int32)).from_json(%(1)).should eq(1)
      Union(Float32, Array(Int32)).from_json(%(1.23)).should eq(1.23_f32)
    end

    it "deserializes union with Float64 (fast path)" do
      Union(Float64, Array(Int32)).from_json(%(1)).should eq(1)
      Union(Float64, Array(Int32)).from_json(%(1.23)).should eq(1.23)
    end

    it "deserializes Time" do
      Time.from_json(%("2016-11-16T09:55:48-0300")).to_utc.should eq(Time.new(2016, 11, 16, 12, 55, 48, kind: Time::Kind::Utc))
    end

    describe "parse exceptions" do
      it "has correct location when raises in NamedTuple#from_json" do
        ex = expect_raises(JSON::ParseException) do
          Array({foo: Int32, bar: String}).from_json <<-JSON
            [
              {"foo": 1}
            ]
            JSON
        end
        ex.location.should eq({2, 3})
      end

      it "has correct location when raises in Union#from_json" do
        ex = expect_raises(JSON::ParseException) do
          Array(Int32 | Bool).from_json <<-JSON
            [
              {"foo": "bar"}
            ]
            JSON
        end
        ex.location.should eq({2, 3})
      end
    end
  end

  describe "to_json" do
    it "does for Nil" do
      nil.to_json.should eq("null")
    end

    it "does for Bool" do
      true.to_json.should eq("true")
    end

    it "does for Int32" do
      1.to_json.should eq("1")
    end

    it "does for Float64" do
      1.5.to_json.should eq("1.5")
    end

    it "raises if Float is NaN" do
      expect_raises JSON::Error, "NaN not allowed in JSON" do
        (0.0/0.0).to_json
      end
    end

    it "raises if Float is infinity" do
      expect_raises JSON::Error, "Infinity not allowed in JSON" do
        Float64::INFINITY.to_json
      end
    end

    it "does for String" do
      "hello".to_json.should eq("\"hello\"")
    end

    it "does for String with quote" do
      "hel\"lo".to_json.should eq("\"hel\\\"lo\"")
    end

    it "does for String with slash" do
      "hel\\lo".to_json.should eq("\"hel\\\\lo\"")
    end

    it "does for String with control codes" do
      "\b".to_json.should eq("\"\\b\"")
      "\f".to_json.should eq("\"\\f\"")
      "\n".to_json.should eq("\"\\n\"")
      "\r".to_json.should eq("\"\\r\"")
      "\t".to_json.should eq("\"\\t\"")
      "\u{19}".to_json.should eq("\"\\u0019\"")
    end

    it "does for Array" do
      [1, 2, 3].to_json.should eq("[1,2,3]")
    end

    it "does for Set" do
      Set(Int32).new([1, 1, 2]).to_json.should eq("[1,2]")
    end

    it "does for Hash" do
      {"foo" => 1, "bar" => 2}.to_json.should eq(%({"foo":1,"bar":2}))
    end

    it "does for Hash with non-string keys" do
      {:foo => 1, :bar => 2}.to_json.should eq(%({"foo":1,"bar":2}))
    end

    it "does for Hash with newlines" do
      {"foo\nbar" => "baz\nqux"}.to_json.should eq(%({"foo\\nbar":"baz\\nqux"}))
    end

    it "does for Tuple" do
      {1, "hello"}.to_json.should eq(%([1,"hello"]))
    end

    it "does for NamedTuple" do
      {x: 1, y: "hello"}.to_json.should eq(%({"x":1,"y":"hello"}))
    end

    it "does for Enum" do
      JSONSpecEnum::One.to_json.should eq("1")
    end

    it "does for BigInt" do
      big = BigInt.new("123456789123456789123456789123456789123456789")
      big.to_json.should eq("123456789123456789123456789123456789123456789")
    end

    it "does for BigFloat" do
      big = BigFloat.new("1234.567891011121314")
      big.to_json.should eq("1234.567891011121314")
    end
  end

  describe "to_pretty_json" do
    it "does for Nil" do
      nil.to_pretty_json.should eq("null")
    end

    it "does for Bool" do
      true.to_pretty_json.should eq("true")
    end

    it "does for Int32" do
      1.to_pretty_json.should eq("1")
    end

    it "does for Float64" do
      1.5.to_pretty_json.should eq("1.5")
    end

    it "does for String" do
      "hello".to_pretty_json.should eq("\"hello\"")
    end

    it "does for Array" do
      [1, 2, 3].to_pretty_json.should eq("[\n  1,\n  2,\n  3\n]")
    end

    it "does for nested Array" do
      [[1, 2, 3]].to_pretty_json.should eq("[\n  [\n    1,\n    2,\n    3\n  ]\n]")
    end

    it "does for empty Array" do
      ([] of Nil).to_pretty_json.should eq("[]")
    end

    it "does for Hash" do
      {"foo" => 1, "bar" => 2}.to_pretty_json.should eq(%({\n  "foo": 1,\n  "bar": 2\n}))
    end

    it "does for nested Hash" do
      {"foo" => {"bar" => 1}}.to_pretty_json.should eq(%({\n  "foo": {\n    "bar": 1\n  }\n}))
    end

    it "does for empty Hash" do
      ({} of Nil => Nil).to_pretty_json.should eq(%({}))
    end

    it "does for Array with indent" do
      [1, 2, 3].to_pretty_json(indent: " ").should eq("[\n 1,\n 2,\n 3\n]")
    end

    it "does for nested Hash with indent" do
      {"foo" => {"bar" => 1}}.to_pretty_json(indent: " ").should eq(%({\n "foo": {\n  "bar": 1\n }\n}))
    end

    it "does for time" do
      Time.new(2016, 11, 16, 12, 55, 48, kind: Time::Kind::Utc).to_json.should eq(%("2016-11-16T12:55:48+0000"))
    end
  end
end
