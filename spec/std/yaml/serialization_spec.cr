require "../spec_helper"
require "../../support/number"
require "yaml"
require "big"
require "big/yaml"

enum YAMLSpecEnum
  Zero
  One
  Two
  OneHundred
end

@[Flags]
enum YAMLSpecFlagEnum
  One
  Two
  OneHundred
end

private record FooPrivate, x : Int32 do
  def self.new(ctx : YAML::ParseContext, node : YAML::Nodes::Node)
    new(Int32.new(ctx, node))
  end
end

alias YamlRec = Int32 | Array(YamlRec) | Hash(YamlRec, YamlRec)

puts YAML.libyaml_version

# libyaml 0.2.1 removed the erroneously written document end marker (`...`) after some scalars in root context (see https://github.com/yaml/libyaml/pull/18).
# Earlier libyaml releases still write the document end marker and this is hard to fix on Crystal's side.
# So we just ignore it and adopt the specs accordingly to coincide with the used libyaml version.
private def assert_yaml_document_end(actual, expected, file = __FILE__, line = __LINE__)
  actual.rchop("...\n").should eq(expected), file: file, line: line
end

describe "YAML serialization" do
  describe "from_yaml" do
    it "does Nil#from_yaml" do
      %w(~ null Null NULL).each do |string|
        Nil.from_yaml(string).should be_nil
      end
      Nil.from_yaml("--- \n...\n").should be_nil
    end

    it "does Bool#from_yaml" do
      %w(yes Yes YES true True TRUE on On ON).each do |string|
        Bool.from_yaml(string).should be_true
      end

      %w(no No NO false False FALSE off Off OFF).each do |string|
        Bool.from_yaml(string).should be_false
      end
    end

    {% for int in BUILTIN_INTEGER_TYPES %}
      it "does {{ int }}.from_yaml" do
        {{ int }}.from_yaml("0").should(be_a({{ int }})).should eq(0)
        {{ int }}.from_yaml("123").should(be_a({{ int }})).should eq(123)
        {{ int }}.from_yaml({{ int }}::MIN.to_s).should(be_a({{ int }})).should eq({{ int }}::MIN)
        {{ int }}.from_yaml({{ int }}::MAX.to_s).should(be_a({{ int }})).should eq({{ int }}::MAX)
      end

      it "raises if {{ int }}.from_yaml overflows" do
        expect_raises(YAML::ParseException, "Can't read {{ int }}") do
          {{ int }}.from_yaml(({{ int }}::MIN.to_big_i - 1).to_s)
        end
        expect_raises(YAML::ParseException, "Can't read {{ int }}") do
          {{ int }}.from_yaml(({{ int }}::MAX.to_big_i + 1).to_s)
        end
      end
    {% end %}

    it "does Int.from_yaml with prefixes" do
      Int32.from_yaml("0xabc").should eq(0xabc)
      Int32.from_yaml("0b10110").should eq(0b10110)
      Int32.from_yaml("0777").should eq(0o777)
    end

    it "does Int.from_yaml with underscores" do
      Int32.from_yaml("1_2_34").should eq(1_2_34)
    end

    it "does String#from_yaml" do
      String.from_yaml("hello").should eq("hello")
    end

    it "does String#from_yaml (empty string)" do
      String.from_yaml("").should eq("")
    end

    it "can parse string that looks like a number" do
      String.from_yaml(%(1.2)).should eq("1.2")
    end

    it "does Path.from_yaml" do
      Path.from_yaml(%("foo/bar")).should eq(Path.new("foo/bar"))
    end

    it "does Float32#from_yaml" do
      Float32.from_yaml("1.5").should eq(1.5_f32)
      Float32.from_yaml(".nan").nan?.should be_true
      Float32.from_yaml(".inf").should eq(Float32::INFINITY)
      Float32.from_yaml("-.inf").should eq(-Float32::INFINITY)
    end

    it "does Float64#from_yaml" do
      value = Float64.from_yaml("1.5")
      value.should eq(1.5)
      value.should be_a(Float64)

      Float64.from_yaml(".nan").nan?.should be_true
      Float64.from_yaml(".inf").should eq(Float64::INFINITY)
      Float64.from_yaml("-.inf").should eq(-Float64::INFINITY)
    end

    it "does Array#from_yaml" do
      Array(Int32).from_yaml("---\n- 1\n- 2\n- 3\n").should eq([1, 2, 3])
    end

    it "does Set#from_yaml" do
      Set(Int32).from_yaml("---\n- 1\n- 2\n- 2\n").should eq(Set.new([1, 2]))
    end

    it "does Array#from_yaml from IO" do
      io = IO::Memory.new "---\n- 1\n- 2\n- 3\n"
      Array(Int32).from_yaml(io).should eq([1, 2, 3])
    end

    it "does Array#from_yaml with block" do
      elements = [] of Int32
      Array(Int32).from_yaml("---\n- 1\n- 2\n- 3\n") do |element|
        elements << element
      end
      elements.should eq([1, 2, 3])
    end

    it "does Hash#from_yaml" do
      Hash(Int32, Bool).from_yaml("---\n1: true\n2: false\n").should eq({1 => true, 2 => false})
    end

    it "does Hash#from_yaml with merge" do
      yaml = <<-YAML
        - &foo
          bar: 1
          baz: 2
        -
          <<: *foo
        YAML

      array = Array(Hash(String, Int32)).from_yaml(yaml)
      array[1].should eq(array[0])
    end

    it "does Hash#from_yaml with merge (recursive)" do
      yaml = <<-YAML
        - &foo
          foo: 1

        - &bar
          bar: 2
          <<: *foo
        -
          <<: *bar
        YAML

      array = Array(Hash(String, Int32)).from_yaml(yaml)
      array[2].should eq({"foo" => 1, "bar" => 2})
    end

    it "does for tuple" do
      tuple = Tuple(Int32, String, Bool).from_yaml("---\n- 1\n- foo\n- true\n")
      tuple.should eq({1, "foo", true})
      typeof(tuple).should eq(Tuple(Int32, String, Bool))
    end

    it "does for tuple with file-private type" do
      tuple = Tuple(FooPrivate).from_yaml %([1])
      tuple.should eq({FooPrivate.new(1)})
      typeof(tuple).should eq(Tuple(FooPrivate))
    end

    it "does for empty tuple" do
      typeof(Tuple.new).from_yaml("[]").should eq(Tuple.new)
    end

    it "does for named tuple" do
      tuple = NamedTuple(x: Int32, y: String).from_yaml(%({"y": "hello", "x": 1}))
      tuple.should eq({x: 1, y: "hello"})
      typeof(tuple).should eq(NamedTuple(x: Int32, y: String))
    end

    it "does for empty named tuple" do
      tuple = typeof(NamedTuple.new).from_yaml(%({}))
      tuple.should eq(NamedTuple.new)
      tuple.should be_a(typeof(NamedTuple.new))
    end

    it "does for named tuple with nilable fields (#8089)" do
      tuple = NamedTuple(x: Int32?, y: String).from_yaml(%({"y": "hello"}))
      tuple.should eq({x: nil, y: "hello"})
      typeof(tuple).should eq(NamedTuple(x: Int32?, y: String))
    end

    it "does for named tuple with nilable fields and null (#8089)" do
      tuple = NamedTuple(x: Int32?, y: String).from_yaml(%({"y": "hello", "x": null}))
      tuple.should eq({x: nil, y: "hello"})
      typeof(tuple).should eq(NamedTuple(x: Int32?, y: String))
    end

    it "does for named tuple with spaces in key (#10918)" do
      tuple = NamedTuple(a: Int32, "xyz b-23": Int32).from_yaml %{{"a": 1, "xyz b-23": 2}}
      tuple.should eq({a: 1, "xyz b-23": 2})
      typeof(tuple).should eq(NamedTuple(a: Int32, "xyz b-23": Int32))
    end

    it "does for named tuple with spaces in key and quote char (#10918)" do
      tuple = NamedTuple(a: Int32, "xyz \"foo\" b-23": Int32).from_yaml %{{"a": 1, "xyz \\"foo\\" b-23": 2}}
      tuple.should eq({a: 1, "xyz \"foo\" b-23": 2})
      typeof(tuple).should eq(NamedTuple(a: Int32, "xyz \"foo\" b-23": Int32))
    end

    it "does for named tuple with file-private type" do
      tuple = NamedTuple(a: FooPrivate).from_yaml %({"a": 1})
      tuple.should eq({a: FooPrivate.new(1)})
      typeof(tuple).should eq(NamedTuple(a: FooPrivate))
    end

    it "does for BigInt" do
      big = BigInt.from_yaml("123456789123456789123456789123456789123456789")
      big.should be_a(BigInt)
      big.should eq(BigInt.new("123456789123456789123456789123456789123456789"))
    end

    it "does for BigFloat" do
      big = BigFloat.from_yaml("1234.567891011121314")
      big.should be_a(BigFloat)
      big.should eq(BigFloat.new("1234.567891011121314"))
    end

    it "does for BigDecimal" do
      big = BigDecimal.from_yaml("1234.567891011121314")
      big.should be_a(BigDecimal)
      big.should eq(BigDecimal.new("1234.567891011121314"))
    end

    describe "Enum" do
      it "normal enum" do
        YAMLSpecEnum.from_yaml(%("one")).should eq(YAMLSpecEnum::One)
        YAMLSpecEnum.from_yaml(%("One")).should eq(YAMLSpecEnum::One)
        YAMLSpecEnum.from_yaml(%("two")).should eq(YAMLSpecEnum::Two)
        YAMLSpecEnum.from_yaml(%("ONE_HUNDRED")).should eq(YAMLSpecEnum::OneHundred)
        YAMLSpecEnum.from_yaml(%("ONE-HUNDRED")).should eq(YAMLSpecEnum::OneHundred)

        expect_raises(YAML::ParseException, %(Unknown enum YAMLSpecEnum value: " one ")) do
          YAMLSpecEnum.from_yaml(%(" one "))
        end

        expect_raises(YAML::ParseException, %(Unknown enum YAMLSpecEnum value: "three")) do
          YAMLSpecEnum.from_yaml(%("three"))
        end
        expect_raises(YAML::ParseException, %(Expected String, not "1")) do
          YAMLSpecEnum.from_yaml(%(1))
        end
        expect_raises(YAML::ParseException, %(Unknown enum YAMLSpecEnum value: "1")) do
          YAMLSpecEnum.from_yaml(%("1"))
        end

        expect_raises(YAML::ParseException, "Expected scalar, not mapping") do
          YAMLSpecEnum.from_yaml(%({}))
        end
        expect_raises(YAML::ParseException, "Expected scalar, not sequence") do
          YAMLSpecEnum.from_yaml(%([]))
        end
      end

      it "flag enum" do
        YAMLSpecFlagEnum.from_yaml(%(["one"])).should eq(YAMLSpecFlagEnum::One)
        YAMLSpecFlagEnum.from_yaml(%(["One"])).should eq(YAMLSpecFlagEnum::One)
        YAMLSpecFlagEnum.from_yaml(%([one])).should eq(YAMLSpecFlagEnum::One)
        YAMLSpecFlagEnum.from_yaml(%(["one", "one"])).should eq(YAMLSpecFlagEnum::One)
        YAMLSpecFlagEnum.from_yaml(%(["one", "two"])).should eq(YAMLSpecFlagEnum::One | YAMLSpecFlagEnum::Two)
        YAMLSpecFlagEnum.from_yaml(%([one, two])).should eq(YAMLSpecFlagEnum::One | YAMLSpecFlagEnum::Two)
        YAMLSpecFlagEnum.from_yaml(%(["one", "two", "one_hundred"])).should eq(YAMLSpecFlagEnum::All)
        YAMLSpecFlagEnum.from_yaml(%([])).should eq(YAMLSpecFlagEnum::None)

        expect_raises(YAML::ParseException, "Expected scalar, not sequence") do
          YAMLSpecFlagEnum.from_yaml(%(["one", ["two"]]))
        end

        expect_raises(YAML::ParseException, %(Unknown enum YAMLSpecFlagEnum value: "three")) do
          YAMLSpecFlagEnum.from_yaml(%(["one", "three"]))
        end
        expect_raises(YAML::ParseException, %(Expected String, not "1")) do
          YAMLSpecFlagEnum.from_yaml(%([1, 2]))
        end
        expect_raises(YAML::ParseException, %(Expected String, not "2")) do
          YAMLSpecFlagEnum.from_yaml(%(["one", 2]))
        end
        expect_raises(YAML::ParseException, "Expected sequence, not mapping") do
          YAMLSpecFlagEnum.from_yaml(%({}))
        end
        expect_raises(YAML::ParseException, "Expected sequence, not scalar") do
          YAMLSpecFlagEnum.from_yaml(%("one"))
        end
      end
    end

    describe "Enum::ValueConverter.from_yaml" do
      it "normal enum" do
        Enum::ValueConverter(YAMLSpecEnum).from_yaml("0").should eq(YAMLSpecEnum::Zero)
        Enum::ValueConverter(YAMLSpecEnum).from_yaml("1").should eq(YAMLSpecEnum::One)
        Enum::ValueConverter(YAMLSpecEnum).from_yaml("2").should eq(YAMLSpecEnum::Two)
        Enum::ValueConverter(YAMLSpecEnum).from_yaml("3").should eq(YAMLSpecEnum::OneHundred)

        expect_raises(YAML::ParseException, %(Expected Int64, not "3")) do
          Enum::ValueConverter(YAMLSpecEnum).from_yaml(%("3"))
        end

        expect_raises(YAML::ParseException, %(Unknown enum YAMLSpecEnum value: 4)) do
          Enum::ValueConverter(YAMLSpecEnum).from_yaml("4")
        end
        expect_raises(YAML::ParseException, %(Unknown enum YAMLSpecEnum value: -1)) do
          Enum::ValueConverter(YAMLSpecEnum).from_yaml("-1")
        end
        expect_raises(YAML::ParseException, %(Expected Int64, not )) do
          Enum::ValueConverter(YAMLSpecEnum).from_yaml("")
        end

        expect_raises(YAML::ParseException, %(Expected Int64, not "one")) do
          Enum::ValueConverter(YAMLSpecEnum).from_yaml(%("one"))
        end

        expect_raises(YAML::ParseException, "Expected scalar, not mapping") do
          Enum::ValueConverter(YAMLSpecEnum).from_yaml(%({}))
        end
        expect_raises(YAML::ParseException, "Expected scalar, not sequence") do
          Enum::ValueConverter(YAMLSpecEnum).from_yaml(%([]))
        end
      end

      it "flag enum" do
        Enum::ValueConverter(YAMLSpecFlagEnum).from_yaml("0").should eq(YAMLSpecFlagEnum::None)
        Enum::ValueConverter(YAMLSpecFlagEnum).from_yaml("1").should eq(YAMLSpecFlagEnum::One)
        Enum::ValueConverter(YAMLSpecFlagEnum).from_yaml("2").should eq(YAMLSpecFlagEnum::Two)
        Enum::ValueConverter(YAMLSpecFlagEnum).from_yaml("4").should eq(YAMLSpecFlagEnum::OneHundred)
        Enum::ValueConverter(YAMLSpecFlagEnum).from_yaml("5").should eq(YAMLSpecFlagEnum::OneHundred | YAMLSpecFlagEnum::One)
        Enum::ValueConverter(YAMLSpecFlagEnum).from_yaml("7").should eq(YAMLSpecFlagEnum::All)

        expect_raises(YAML::ParseException, %(Unknown enum YAMLSpecFlagEnum value: 8)) do
          Enum::ValueConverter(YAMLSpecFlagEnum).from_yaml("8")
        end
        expect_raises(YAML::ParseException, %(Unknown enum YAMLSpecFlagEnum value: -1)) do
          Enum::ValueConverter(YAMLSpecFlagEnum).from_yaml("-1")
        end
        expect_raises(YAML::ParseException, %(Expected Int64, not "")) do
          Enum::ValueConverter(YAMLSpecFlagEnum).from_yaml("")
        end

        expect_raises(YAML::ParseException, %(Expected Int64, not "one")) do
          Enum::ValueConverter(YAMLSpecFlagEnum).from_yaml(%("one"))
        end

        expect_raises(YAML::ParseException, "Expected scalar, not mapping") do
          Enum::ValueConverter(YAMLSpecFlagEnum).from_yaml(%({}))
        end
        expect_raises(YAML::ParseException, "Expected scalar, not sequence") do
          Enum::ValueConverter(YAMLSpecFlagEnum).from_yaml(%([]))
        end
      end
    end

    it "does Time::Format#from_yaml" do
      ctx = YAML::ParseContext.new
      nodes = YAML::Nodes.parse("--- 2014-01-02\n...\n").nodes.first
      value = Time::Format.new("%F").from_yaml(ctx, nodes)
      value.should eq(Time.utc(2014, 1, 2))
    end

    it "deserializes union with nil, string and int (#7936)" do
      Array(Int32 | String | Nil).from_yaml(%([1, "hello", null])).should eq([1, "hello", nil])
    end

    it "deserializes time" do
      Time.from_yaml("2010-11-12").should eq(Time.utc(2010, 11, 12))
    end

    it "deserializes bytes" do
      Bytes.from_yaml("!!binary aGVsbG8=").should eq("hello".to_slice)
    end

    describe "parse exceptions" do
      it "has correct location when raises in Nil#from_yaml" do
        ex = expect_raises(YAML::ParseException) do
          Array(Nil).from_yaml <<-YAML
            [
              1
            ]
            YAML
        end
        ex.message.should eq(%(Expected Nil, not "1" at line 2, column 3))
        ex.location.should eq({2, 3})
      end

      it "has correct location when raises in Int32#from_yaml" do
        ex = expect_raises(YAML::ParseException) do
          Array(Int32).from_yaml <<-YAML
            [
              "hello"
            ]
            YAML
        end
        ex.location.should eq({2, 3})
      end

      it "has correct location when raises in NamedTuple#from_yaml" do
        ex = expect_raises(YAML::ParseException) do
          Array({foo: Int32, bar: String}).from_yaml <<-YAML
            [
              {"foo": 1}
            ]
            YAML
        end
        ex.location.should eq({2, 3})
      end

      it "has correct location when raises in Union#from_yaml" do
        ex = expect_raises(YAML::ParseException) do
          Array(Int32 | Bool).from_yaml <<-YAML
            [
              {"foo": "bar"}
            ]
            YAML
        end
        ex.location.should eq({2, 3})
      end
    end
  end

  describe "to_yaml" do
    it "does for Nil" do
      Nil.from_yaml(nil.to_yaml).should eq(nil)
    end

    it "does for Nil (empty string)" do
      Nil.from_yaml("").should eq(nil)
    end

    it "does for Bool" do
      Bool.from_yaml(true.to_yaml).should eq(true)
      Bool.from_yaml(false.to_yaml).should eq(false)
    end

    it "does for Int32" do
      Int32.from_yaml(1.to_yaml).should eq(1)
    end

    it "does for Float32" do
      Float32.from_yaml(1.5_f32.to_yaml).should eq(1.5_f32)
    end

    it "does for Float32 (infinity)" do
      Float32.from_yaml(Float32::INFINITY.to_yaml).should eq(Float32::INFINITY)
    end

    it "does for Float32 (-infinity)" do
      Float32.from_yaml((-Float32::INFINITY).to_yaml).should eq(-Float32::INFINITY)
    end

    it "does for Float32 (nan)" do
      Float32.from_yaml(Float32::NAN.to_yaml).nan?.should be_true
    end

    it "does for Float64" do
      Float64.from_yaml(1.5.to_yaml).should eq(1.5)
    end

    it "does for Float64 (infinity)" do
      Float64.from_yaml(Float64::INFINITY.to_yaml).should eq(Float64::INFINITY)
    end

    it "does for Float64 (-infinity)" do
      Float64.from_yaml((-Float64::INFINITY).to_yaml).should eq(-Float64::INFINITY)
    end

    it "does for Float64 (nan)" do
      Float64.from_yaml(Float64::NAN.to_yaml).nan?.should be_true
    end

    it "does for String" do
      String.from_yaml("hello".to_yaml).should eq("hello")
    end

    it "does for String with stars (#3353)" do
      String.from_yaml("***".to_yaml).should eq("***")
    end

    it "does for String with quote" do
      String.from_yaml("hel\"lo".to_yaml).should eq("hel\"lo")
    end

    it "does for String with slash" do
      String.from_yaml("hel\\lo".to_yaml).should eq("hel\\lo")
    end

    it "does for String with unicode characters (#8131)" do
      "你好".to_yaml.should contain("你好")
    end

    it "quotes string if reserved" do
      ["1", "1.2", "true", "2010-11-12"].each do |string|
        string.to_yaml.should eq(%(--- "#{string}"\n))
      end
    end

    it "does for Path" do
      Path.from_yaml(Path.new("foo", "bar", "baz").to_yaml).should eq(Path.new("foo", "bar", "baz"))
    end

    it "does for Array" do
      Array(Int32).from_yaml([1, 2, 3].to_yaml).should eq([1, 2, 3])
    end

    it "does for Set" do
      Array(Int32).from_yaml(Set(Int32).new([1, 1, 2]).to_yaml).should eq([1, 2])
    end

    it "does for Hash" do
      Hash(String, Int32).from_yaml({"foo" => 1, "bar" => 2}.to_yaml).should eq({"foo" => 1, "bar" => 2})
    end

    it "does for Hash with symbol keys" do
      Hash(String, Int32).from_yaml({:foo => 1, :bar => 2}.to_yaml).should eq({"foo" => 1, "bar" => 2})
    end

    it "does for Tuple" do
      Tuple(Int32, String).from_yaml({1, "hello"}.to_yaml).should eq({1, "hello"})
    end

    it "does for NamedTuple" do
      {x: 1, y: "hello"}.to_yaml.should eq({:x => 1, :y => "hello"}.to_yaml)
    end

    it "does for BigInt" do
      big = BigInt.new("123456789123456789123456789123456789123456789")
      BigInt.from_yaml(big.to_yaml).should eq(big)
    end

    it "does for BigFloat" do
      big = BigFloat.new("1234.567891011121314")
      BigFloat.from_yaml(big.to_yaml).should eq(big)
    end

    it "does for BigDecimal" do
      big = BigDecimal.new("1234.567891011121314")
      BigDecimal.from_yaml(big.to_yaml).should eq(big)
    end

    describe "Enum" do
      it "normal enum" do
        assert_yaml_document_end(YAMLSpecEnum::One.to_yaml, "--- one\n")
        YAMLSpecEnum.from_yaml(YAMLSpecEnum::One.to_yaml).should eq(YAMLSpecEnum::One)

        assert_yaml_document_end(YAMLSpecEnum::OneHundred.to_yaml, "--- one_hundred\n")
        YAMLSpecEnum.from_yaml(YAMLSpecEnum::OneHundred.to_yaml).should eq(YAMLSpecEnum::OneHundred)

        # undefined members can't be parsed back because the standard converter only accepts named
        # members
        assert_yaml_document_end(YAMLSpecEnum.new(42).to_yaml, %(--- "42"\n))
      end

      it "flag enum" do
        assert_yaml_document_end(YAMLSpecFlagEnum::One.to_yaml, %(--- [one]\n))
        YAMLSpecFlagEnum.from_yaml(YAMLSpecFlagEnum::One.to_yaml).should eq(YAMLSpecFlagEnum::One)

        assert_yaml_document_end(YAMLSpecFlagEnum::OneHundred.to_yaml, %(--- [one_hundred]\n))
        YAMLSpecFlagEnum.from_yaml(YAMLSpecFlagEnum::OneHundred.to_yaml).should eq(YAMLSpecFlagEnum::OneHundred)

        combined = YAMLSpecFlagEnum::OneHundred | YAMLSpecFlagEnum::One
        assert_yaml_document_end(combined.to_yaml, %(--- [one, one_hundred]\n))
        YAMLSpecFlagEnum.from_yaml(combined.to_yaml).should eq(combined)

        assert_yaml_document_end(YAMLSpecFlagEnum::None.to_yaml, %(--- []\n))
        YAMLSpecFlagEnum.from_yaml(YAMLSpecFlagEnum::None.to_yaml).should eq(YAMLSpecFlagEnum::None)

        assert_yaml_document_end(YAMLSpecFlagEnum::All.to_yaml, %(--- [one, two, one_hundred]\n))
        YAMLSpecFlagEnum.from_yaml(YAMLSpecFlagEnum::All.to_yaml).should eq(YAMLSpecFlagEnum::All)

        assert_yaml_document_end(YAMLSpecFlagEnum.new(42).to_yaml, "--- [two]\n")
      end
    end

    describe "Enum::ValueConverter" do
      it "normal enum" do
        converter = Enum::ValueConverter(YAMLSpecEnum)
        assert_yaml_document_end(converter.to_yaml(YAMLSpecEnum::One), "--- 1\n")
        converter.from_yaml(converter.to_yaml(YAMLSpecEnum::One)).should eq(YAMLSpecEnum::One)

        assert_yaml_document_end(converter.to_yaml(YAMLSpecEnum::OneHundred), "--- 3\n")
        converter.from_yaml(converter.to_yaml(YAMLSpecEnum::OneHundred)).should eq(YAMLSpecEnum::OneHundred)

        # undefined members can't be parsed back because the standard converter only accepts named
        # members
        assert_yaml_document_end(converter.to_yaml(YAMLSpecEnum.new(42)), %(--- 42\n))
      end

      it "flag enum" do
        converter = Enum::ValueConverter(YAMLSpecFlagEnum)
        assert_yaml_document_end(converter.to_yaml(YAMLSpecFlagEnum::One), %(--- 1\n))
        converter.from_yaml(converter.to_yaml(YAMLSpecFlagEnum::One)).should eq(YAMLSpecFlagEnum::One)

        assert_yaml_document_end(converter.to_yaml(YAMLSpecFlagEnum::OneHundred), %(--- 4\n))
        converter.from_yaml(converter.to_yaml(YAMLSpecFlagEnum::OneHundred)).should eq(YAMLSpecFlagEnum::OneHundred)

        combined = YAMLSpecFlagEnum::OneHundred | YAMLSpecFlagEnum::One
        assert_yaml_document_end(converter.to_yaml(combined), %(--- 5\n))
        converter.from_yaml(converter.to_yaml(combined)).should eq(combined)

        assert_yaml_document_end(converter.to_yaml(YAMLSpecFlagEnum::None), %(--- 0\n))
        converter.from_yaml(converter.to_yaml(YAMLSpecFlagEnum::None)).should eq(YAMLSpecFlagEnum::None)

        assert_yaml_document_end(converter.to_yaml(YAMLSpecFlagEnum::All), %(--- 7\n))
        converter.from_yaml(converter.to_yaml(YAMLSpecFlagEnum::All)).should eq(YAMLSpecFlagEnum::All)

        assert_yaml_document_end(converter.to_yaml(YAMLSpecFlagEnum.new(42)), "--- 42\n")
      end
    end

    it "does for utc time" do
      time = Time.utc(2010, 11, 12, 1, 2, 3)
      assert_yaml_document_end(time.to_yaml, "--- 2010-11-12 01:02:03.000000000\n")
    end

    it "does for time at date" do
      time = Time.utc(2010, 11, 12)
      assert_yaml_document_end(time.to_yaml, "--- 2010-11-12\n")
    end

    it "does for utc time with nanoseconds" do
      time = Time.utc(2010, 11, 12, 1, 2, 3, nanosecond: 456_000_000)
      assert_yaml_document_end(time.to_yaml, "--- 2010-11-12 01:02:03.456000000\n")
    end

    it "does for bytes" do
      yaml = "hello".to_slice.to_yaml

      if YAML.libyaml_version < SemanticVersion.new(0, 2, 2)
        yaml.should eq("--- !!binary 'aGVsbG8=\n\n'\n")
      else
        yaml.should eq("--- !!binary 'aGVsbG8=\n\n  '\n")
      end
    end

    it "does a full document" do
      data = {
        :hello   => "World",
        :integer => 2,
        :float   => 3.5,
        :hash    => {
          :a => 1,
          :b => 2,
        },
        :array => [1, 2, 3],
        :null  => nil,
      }

      expected = /\A---\nhello: World\ninteger: 2\nfloat: 3.5\nhash:\n  a: 1\n  b: 2\narray:\n- 1\n- 2\n- 3\nnull: ?\n\z/

      data.to_yaml.should match(expected)
    end

    it "writes to a stream" do
      string = String.build do |str|
        %w(a b c).to_yaml(str)
      end
      string.should eq("---\n- a\n- b\n- c\n")
    end

    it "serializes recursive data structures" do
      a = [] of YamlRec
      a << 1
      a << a

      a.to_yaml.should eq("--- &1\n- 1\n- *1\n")

      h = {} of YamlRec => YamlRec
      h[1] = 2
      h[h] = h

      h.to_yaml.should match(/\A--- &1\n1: 2\n\*1 ?: \*1\n\z/)
    end
  end
end
