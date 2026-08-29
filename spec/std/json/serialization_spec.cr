require "../spec_helper"
require "../../support/number"
require "spec/helpers/iterate"
require "json"
require "big"
require "big/json"
require "uuid"
require "uuid/json"

enum JSONSpecEnum
  Zero
  One
  Two
  OneHundred
end

@[Flags]
enum JSONSpecFlagEnum
  One
  Two
  OneHundred
end

private record FooPrivate, x : Int32 do
  def self.new(json : JSON::PullParser)
    new(Int32.new(json))
  end
end

describe "JSON serialization" do
  describe "from_json" do
    it "does String.from_json" do
      String.from_json(%("foo bar")).should eq "foo bar"
    end

    it "does Path.from_json" do
      Path.from_json(%("foo/bar")).should eq(Path.new("foo/bar"))
    end

    it "does Path.from_json_object_key" do
      Hash(Path, String).from_json(%({"foo/bar": "baz"})).should eq({Path.new("foo/bar") => "baz"})
    end

    it "does Time::Location.from_json_object_key" do
      Hash(Time::Location, String).from_json(%({"UTC": "foo"}))
        .should eq({Time::Location::UTC => "foo"})
    end

    {% for int in BUILTIN_INTEGER_TYPES %}
      it "does {{ int }}.from_json" do
        {{ int }}.from_json("0").should(be_a({{ int }})).should eq(0)
        {{ int }}.from_json("123").should(be_a({{ int }})).should eq(123)
        {{ int }}.from_json({{ int }}::MIN.to_s).should(be_a({{ int }})).should eq({{ int }}::MIN)
        {{ int }}.from_json({{ int }}::MAX.to_s).should(be_a({{ int }})).should eq({{ int }}::MAX)
      end

      # NOTE: "Invalid" shows up only for `Int64`
      it "raises if {{ int }}.from_json overflows" do
        expect_raises(JSON::ParseException, /(Can't read|Invalid) {{ int }}/) do
          {{ int }}.from_json(({{ int }}::MIN.to_big_i - 1).to_s)
        end
        expect_raises(JSON::ParseException, /(Can't read|Invalid) {{ int }}/) do
          {{ int }}.from_json(({{ int }}::MAX.to_big_i + 1).to_s)
        end
      end
    {% end %}

    it "errors on non-base-10 ints" do
      expect_raises(JSON::ParseException) { Int32.from_json "0b1" }
      expect_raises(JSON::ParseException) { Int32.from_json "0o1" }
      expect_raises(JSON::ParseException) { Int32.from_json "0x1" }
      expect_raises(JSON::ParseException) { Int32.from_json "01" }
    end

    it "errors on underscores inside ints" do
      expect_raises(JSON::ParseException) { Int32.from_json "1_2" }
    end

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

    it "does Deque(String)#from_json" do
      Deque(String).from_json(%(["a", "b"])).should eq(Deque.new(["a", "b"]))
    end

    it "does Iterator(String)#from_json" do
      assert_iterates_iterator ["a", "b"], Iterator(String).from_json(%(["a", "b"]))
    end

    it "raises an error Iterator(String)#from_json with invalid types" do
      expect_raises(JSON::ParseException) do
        Iterator(String).from_json(%([1, 2])).to_a
      end
    end

    it "raises an error Iterator(String)#from_json with invalid JSON" do
      expect_raises(JSON::ParseException) do
        Iterator(String).from_json(%(["a")).to_a
      end
    end

    it "does Hash(String, String)#from_json" do
      Hash(String, String).from_json(%({"foo": "x", "bar": "y"})).should eq({"foo" => "x", "bar" => "y"})
    end

    it "does Hash(String, Int32)#from_json" do
      Hash(String, Int32).from_json(%({"foo": 1, "bar": 2})).should eq({"foo" => 1, "bar" => 2})
    end

    it "does Hash(Int32, String)#from_json" do
      Hash(Int32, String).from_json(%({"1": "x", "2": "y"})).should eq({1 => "x", 2 => "y"})
    end

    it "does Hash(Float32, String)#from_json" do
      Hash(Float32, String).from_json(%({"1.23": "x", "4.56": "y"})).should eq({1.23_f32 => "x", 4.56_f32 => "y"})
    end

    it "does Hash(Float64, String)#from_json" do
      Hash(Float64, String).from_json(%({"1.23": "x", "4.56": "y"})).should eq({1.23 => "x", 4.56 => "y"})
    end

    it "does Hash(BigInt, String)#from_json" do
      Hash(BigInt, String).from_json(%({"12345678901234567890": "x"})).should eq({"12345678901234567890".to_big_i => "x"})
    end

    it "does Hash(BigFloat, String)#from_json" do
      Hash(BigFloat, String).from_json(%({"1234567890.123456789": "x"})).should eq({"1234567890.123456789".to_big_f => "x"})
    end

    it "does Hash(BigDecimal, String)#from_json" do
      Hash(BigDecimal, String).from_json(%({"1234567890.123456789": "x"})).should eq({"1234567890.123456789".to_big_d => "x"})
    end

    describe "Hash with union key (Union.from_json_object_key?)" do
      it "string deprioritized" do
        Hash(String | Int32, Nil).from_json(%({"1": null})).should eq({1 => nil})
        Hash(String | UInt32, Nil).from_json(%({"1": null})).should eq({1 => nil})
      end

      it "string without alternative" do
        Hash(String | Int32, Nil).from_json(%({"foo": null})).should eq({"foo" => nil})
      end

      it "no match" do
        expect_raises JSON::ParseException, %(Can't convert "foo" into (Float64 | Int32) at line 1, column 2) do
          Hash(Float64 | Int32, Nil).from_json(%({"foo": null}))
        end
      end
    end

    it "raises an error Hash(String, Int32)#from_json with null value" do
      expect_raises(JSON::ParseException, "Expected Int but was Null") do
        Hash(String, Int32).from_json(%({"foo": 1, "bar": 2, "baz": null}))
      end
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
      typeof(tuple).should eq(Tuple(Int32, String))
    end

    it "does for tuple with file-private type" do
      tuple = Tuple(FooPrivate).from_json %([1])
      tuple.should eq({FooPrivate.new(1)})
      typeof(tuple).should eq(Tuple(FooPrivate))
    end

    it "does for empty tuple" do
      typeof(Tuple.new).from_json("[]").should eq(Tuple.new)
    end

    it "does for named tuple" do
      tuple = NamedTuple(x: Int32, y: String).from_json(%({"y": "hello", "x": 1}))
      tuple.should eq({x: 1, y: "hello"})
      typeof(tuple).should eq(NamedTuple(x: Int32, y: String))
    end

    it "does for empty named tuple" do
      tuple = typeof(NamedTuple.new).from_json(%({}))
      tuple.should eq(NamedTuple.new)
      tuple.should be_a(typeof(NamedTuple.new))
    end

    it "does for named tuple with nilable fields (#8089)" do
      tuple = NamedTuple(x: Int32?, y: String).from_json(%({"y": "hello"}))
      tuple.should eq({x: nil, y: "hello"})
      typeof(tuple).should eq(NamedTuple(x: Int32?, y: String))
    end

    it "does for named tuple with nilable fields and null (#8089)" do
      tuple = NamedTuple(x: Int32?, y: String).from_json(%({"y": "hello", "x": null}))
      tuple.should eq({x: nil, y: "hello"})
      typeof(tuple).should eq(NamedTuple(x: Int32?, y: String))
    end

    it "does for named tuple with spaces in key (#10918)" do
      tuple = NamedTuple(a: Int32, "xyz b-23": Int32).from_json %{{"a": 1, "xyz b-23": 2}}
      tuple.should eq({a: 1, "xyz b-23": 2})
      typeof(tuple).should eq(NamedTuple(a: Int32, "xyz b-23": Int32))
    end

    it "does for named tuple with spaces in key and quote char (#10918)" do
      tuple = NamedTuple(a: Int32, "xyz \"foo\" b-23": Int32).from_json %{{"a": 1, "xyz \\"foo\\" b-23": 2}}
      tuple.should eq({a: 1, "xyz \"foo\" b-23": 2})
      typeof(tuple).should eq(NamedTuple(a: Int32, "xyz \"foo\" b-23": Int32))
    end

    it "does for named tuple with file-private type" do
      tuple = NamedTuple(a: FooPrivate).from_json %({"a": 1})
      tuple.should eq({a: FooPrivate.new(1)})
      typeof(tuple).should eq(NamedTuple(a: FooPrivate))
    end

    it "does for BigInt" do
      big = BigInt.from_json("123456789123456789123456789123456789123456789")
      big.should be_a(BigInt)
      big.should eq(BigInt.new("123456789123456789123456789123456789123456789"))
    end

    it "raises for BigInt from unsupported types" do
      expect_raises(JSON::ParseException) { BigInt.from_json("true") }
      expect_raises(JSON::ParseException) { BigInt.from_json("1.23") }
      expect_raises(JSON::ParseException) { BigInt.from_json("[]") }
      expect_raises(JSON::ParseException) { BigInt.from_json("{}") }
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

    it "does for BigFloat from string" do
      big = BigFloat.from_json(%("1234"))
      big.should be_a(BigFloat)
      big.should eq(BigFloat.new("1234"))
    end

    it "raises for BigFloat from unsupported types" do
      expect_raises(JSON::ParseException) { BigFloat.from_json("true") }
      expect_raises(JSON::ParseException) { BigFloat.from_json("[]") }
      expect_raises(JSON::ParseException) { BigFloat.from_json("{}") }
    end

    it "does for UUID (hyphenated)" do
      uuid = UUID.from_json("\"ee843b26-56d8-472b-b343-0b94ed9077ff\"")
      uuid.should be_a(UUID)
      uuid.should eq(UUID.new("ee843b26-56d8-472b-b343-0b94ed9077ff"))
    end

    it "does for UUID (hex)" do
      uuid = UUID.from_json("\"ee843b2656d8472bb3430b94ed9077ff\"")
      uuid.should be_a(UUID)
      uuid.should eq(UUID.new("ee843b26-56d8-472b-b343-0b94ed9077ff"))
    end

    it "does for UUID (urn)" do
      uuid = UUID.from_json("\"urn:uuid:ee843b26-56d8-472b-b343-0b94ed9077ff\"")
      uuid.should be_a(UUID)
      uuid.should eq(UUID.new("ee843b26-56d8-472b-b343-0b94ed9077ff"))
    end

    it "does for BigDecimal from int" do
      big = BigDecimal.from_json("1234")
      big.should be_a(BigDecimal)
      big.should eq(BigDecimal.new("1234"))
    end

    it "does for BigDecimal from float" do
      big = BigDecimal.from_json("1234.05")
      big.should be_a(BigDecimal)
      big.should eq(BigDecimal.new("1234.05"))
    end

    it "does for BigDecimal from string" do
      big = BigDecimal.from_json(%("1234.05"))
      big.should be_a(BigDecimal)
      big.should eq(BigDecimal.new("1234.05"))
    end

    it "raises for BigDecimal from unsupported types" do
      expect_raises(JSON::ParseException) { BigDecimal.from_json("true") }
      expect_raises(JSON::ParseException) { BigDecimal.from_json("[]") }
      expect_raises(JSON::ParseException) { BigDecimal.from_json("{}") }
    end

    describe "Enum" do
      it "normal enum" do
        JSONSpecEnum.from_json(%("one")).should eq(JSONSpecEnum::One)
        JSONSpecEnum.from_json(%("One")).should eq(JSONSpecEnum::One)
        JSONSpecEnum.from_json(%("two")).should eq(JSONSpecEnum::Two)
        JSONSpecEnum.from_json(%("ONE_HUNDRED")).should eq(JSONSpecEnum::OneHundred)
        JSONSpecEnum.from_json(%("ONE-HUNDRED")).should eq(JSONSpecEnum::OneHundred)

        expect_raises(JSON::ParseException, %(Unknown enum JSONSpecEnum value: " one ")) do
          JSONSpecEnum.from_json(%(" one "))
        end

        expect_raises(JSON::ParseException, %(Unknown enum JSONSpecEnum value: "three")) do
          JSONSpecEnum.from_json(%("three"))
        end
        expect_raises(JSON::ParseException, %(Unknown enum JSONSpecEnum value: "three")) do
          NamedTuple(foo: JSONSpecEnum).from_json(%({"foo": "three", "other": 1}))
        end
        expect_raises(JSON::ParseException, %(Expected String but was Int)) do
          JSONSpecEnum.from_json(%(1))
        end
        expect_raises(JSON::ParseException, %(Unknown enum JSONSpecEnum value: "1")) do
          JSONSpecEnum.from_json(%("1"))
        end

        expect_raises(JSON::ParseException, "Expected String but was BeginObject") do
          JSONSpecEnum.from_json(%({}))
        end
        expect_raises(JSON::ParseException, "Expected String but was BeginArray") do
          JSONSpecEnum.from_json(%([]))
        end
      end

      it "flag enum" do
        JSONSpecFlagEnum.from_json(%(["one"])).should eq(JSONSpecFlagEnum::One)
        JSONSpecFlagEnum.from_json(%(["One"])).should eq(JSONSpecFlagEnum::One)
        JSONSpecFlagEnum.from_json(%(["one", "one"])).should eq(JSONSpecFlagEnum::One)
        JSONSpecFlagEnum.from_json(%(["one", "two"])).should eq(JSONSpecFlagEnum::One | JSONSpecFlagEnum::Two)
        JSONSpecFlagEnum.from_json(%(["one", "two", "one_hundred"])).should eq(JSONSpecFlagEnum::All)
        JSONSpecFlagEnum.from_json(%([])).should eq(JSONSpecFlagEnum::None)

        expect_raises(JSON::ParseException, "Expected String but was BeginArray") do
          JSONSpecFlagEnum.from_json(%(["one", ["two"]]))
        end

        expect_raises(JSON::ParseException, %(Unknown enum JSONSpecFlagEnum value: "three")) do
          JSONSpecFlagEnum.from_json(%(["one", "three"]))
        end
        expect_raises(JSON::ParseException, %(Expected String but was Int)) do
          JSONSpecFlagEnum.from_json(%([1, 2]))
        end
        expect_raises(JSON::ParseException, %(Expected String but was Int)) do
          JSONSpecFlagEnum.from_json(%(["one", 2]))
        end
        expect_raises(JSON::ParseException, "Expected BeginArray but was BeginObject") do
          JSONSpecFlagEnum.from_json(%({}))
        end
        expect_raises(JSON::ParseException, "Expected BeginArray but was String") do
          JSONSpecFlagEnum.from_json(%("one"))
        end
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

    {% for type in Int::Primitive.union_types %}
      it "deserializes union with {{ type }} (fast path)" do
        Union({{ type }}, Array(Int32)).from_json({{ type }}::MAX.to_s).should eq({{ type }}::MAX)
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

    it "deserializes union of Int32 and Float64 (#7333)" do
      value = Union(Int32, Float64).from_json("1")
      value.should be_a(Int32)
      value.should eq(1)

      value = Union(Int32, Float64).from_json("1.0")
      value.should be_a(Float64)
      value.should eq(1.0)
    end

    it "deserializes unions of the same kind and remains stable" do
      str = [Int32::MAX, Int64::MAX].to_json
      value = Array(Int32 | Int64).from_json(str)
      value.all?(&.should(be_a(Int64)))
    end

    it "deserializes Time" do
      Time.from_json(%("2016-11-16T09:55:48-03:00")).to_utc.should eq(Time.utc(2016, 11, 16, 12, 55, 48))
      Time.from_json(%("2016-11-16T09:55:48-0300")).to_utc.should eq(Time.utc(2016, 11, 16, 12, 55, 48))
      Time.from_json(%("20161116T095548-03:00")).to_utc.should eq(Time.utc(2016, 11, 16, 12, 55, 48))
    end

    it "deserializes Time::Location" do
      Time::Location.from_json(%("UTC")).should eq(Time::Location.load("UTC"))
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

      it "captures overflows for integer types" do
        ex = expect_raises(JSON::ParseException) do
          Array(Int32).from_json <<-JSON
            [
              #{Int64::MAX.to_json}
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

    it "does for Int128" do
      Int128::MAX.to_json.should eq(Int128::MAX.to_s)
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

    it "does for String with control codes in a few places" do
      "\fab".to_json.should eq(%q("\fab"))
      "ab\f".to_json.should eq(%q("ab\f"))
      "ab\fcd".to_json.should eq(%q("ab\fcd"))
      "ab\fcd\f".to_json.should eq(%q("ab\fcd\f"))
      "ab\fcd\fe".to_json.should eq(%q("ab\fcd\fe"))
      "\u{19}ab".to_json.should eq(%q("\u0019ab"))
      "ab\u{19}".to_json.should eq(%q("ab\u0019"))
      "ab\u{19}cd".to_json.should eq(%q("ab\u0019cd"))
      "ab\u{19}cd\u{19}".to_json.should eq(%q("ab\u0019cd\u0019"))
      "ab\u{19}cd\u{19}e".to_json.should eq(%q("ab\u0019cd\u0019e"))
    end

    it "does for Path" do
      Path.posix("foo", "bar", "baz").to_json.should eq(%("foo/bar/baz"))
      Path.windows("foo", "bar", "baz").to_json.should eq(%("foo\\\\bar\\\\baz"))
    end

    it "does for Array" do
      [1, 2, 3].to_json.should eq("[1,2,3]")
    end

    it "does for StaticArray" do
      StaticArray[1, 2, 3].to_json.should eq("[1,2,3]")
    end

    it "does for Deque" do
      Deque.new([1, 2, 3]).to_json.should eq("[1,2,3]")
    end

    it "does for Set" do
      Set(Int32).new([1, 1, 2]).to_json.should eq("[1,2]")
    end

    it "does for Iterator" do
      (1..3).each.to_json.should eq("[1,2,3]")
    end

    it "does for Hash" do
      {"foo" => 1, "bar" => 2}.to_json.should eq(%({"foo":1,"bar":2}))
    end

    it "does for Hash with symbol keys" do
      {:foo => 1, :bar => 2}.to_json.should eq(%({"foo":1,"bar":2}))
    end

    it "does for Hash with int keys" do
      {1 => 2, 3 => 6}.to_json.should eq(%({"1":2,"3":6}))
    end

    it "does for Hash with Float32 keys" do
      {1.2_f32 => 2, 3.4_f32 => 6}.to_json.should eq(%({"1.2":2,"3.4":6}))
    end

    it "does for Hash with Float64 keys" do
      {1.2 => 2, 3.4 => 6}.to_json.should eq(%({"1.2":2,"3.4":6}))
    end

    it "does for Hash with BigInt keys" do
      {123.to_big_i => 2}.to_json.should eq(%({"123":2}))
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

    describe "Enum" do
      it "normal enum" do
        JSONSpecEnum::One.to_json.should eq %("one")
        JSONSpecEnum.from_json(JSONSpecEnum::One.to_json).should eq(JSONSpecEnum::One)

        JSONSpecEnum::OneHundred.to_json.should eq %("one_hundred")
        JSONSpecEnum.from_json(JSONSpecEnum::OneHundred.to_json).should eq(JSONSpecEnum::OneHundred)

        # undefined members can't be parsed back because the standard converter only accepts named
        # members
        JSONSpecEnum.new(42).to_json.should eq %("42")
      end

      it "flag enum" do
        JSONSpecFlagEnum::One.to_json.should eq %(["one"])
        JSONSpecFlagEnum.from_json(JSONSpecFlagEnum::One.to_json).should eq(JSONSpecFlagEnum::One)

        JSONSpecFlagEnum::OneHundred.to_json.should eq %(["one_hundred"])
        JSONSpecFlagEnum.from_json(JSONSpecFlagEnum::OneHundred.to_json).should eq(JSONSpecFlagEnum::OneHundred)

        combined = JSONSpecFlagEnum::OneHundred | JSONSpecFlagEnum::One
        combined.to_json.should eq %(["one","one_hundred"])
        JSONSpecFlagEnum.from_json(combined.to_json).should eq(combined)

        JSONSpecFlagEnum::None.to_json.should eq %([])
        JSONSpecFlagEnum.from_json(JSONSpecFlagEnum::None.to_json).should eq(JSONSpecFlagEnum::None)

        JSONSpecFlagEnum::All.to_json.should eq %(["one","two","one_hundred"])
        JSONSpecFlagEnum.from_json(JSONSpecFlagEnum::All.to_json).should eq(JSONSpecFlagEnum::All)

        JSONSpecFlagEnum.new(42).to_json.should eq %(["two"])
      end
    end

    it "does for BigInt" do
      big = BigInt.new("123456789123456789123456789123456789123456789")
      big.to_json.should eq("123456789123456789123456789123456789123456789")
    end

    it "does for BigFloat" do
      big = BigFloat.new("1234.567891011121314")
      big.to_json.should eq("1234.567891011121314")
    end

    it "does for BigDecimal" do
      big = BigDecimal.new("1234.567891011121314")
      big.to_json.should eq("1234.567891011121314")
    end

    it "does for UUID" do
      uuid = UUID.new("ee843b26-56d8-472b-b343-0b94ed9077ff")
      uuid.to_json.should eq("\"ee843b26-56d8-472b-b343-0b94ed9077ff\"")
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

    describe "Time" do
      it "#to_json" do
        Time.utc(2016, 11, 16, 12, 55, 48).to_json.should eq(%("2016-11-16T12:55:48Z"))
        Time.local(2016, 11, 16, 12, 55, 48, location: Time::Location.fixed(7200)).to_json.should eq(%("2016-11-16T12:55:48+02:00"))
      end

      it "omit sub-second precision" do
        Time.utc(2016, 11, 16, 12, 55, 48, nanosecond: 123456789).to_json.should eq(%("2016-11-16T12:55:48Z"))
      end
    end
  end

  describe "Time::Location" do
    it "#to_json" do
      Time::Location.load("UTC").to_json.should eq(%("UTC"))
    end
  end

  it "provide symmetric encoding and decoding for Union types" do
    a = 1.as(Float64 | Int32)
    b = (Float64 | Int32).from_json(a.to_json)
    a.class.should eq(Int32)
    a.class.should eq(b.class)

    c = 1.0.as(Float64 | Int32)
    d = (Float64 | Int32).from_json(c.to_json)
    c.class.should eq(Float64)
    c.class.should eq(d.class)
  end
end
