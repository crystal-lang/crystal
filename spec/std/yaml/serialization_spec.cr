require "spec"
require "yaml"
require "big"
require "big/yaml"

enum YAMLSpecEnum
  Zero
  One
  Two
end

alias YamlRec = Int32 | Array(YamlRec) | Hash(YamlRec, YamlRec)

# libyaml 0.2.1 removed the errorneously written document end marker (`...`) after some scalars in root context (see https://github.com/yaml/libyaml/pull/18).
# Earlier libyaml releases still write the document end marker and this is hard to fix on Crystal's side.
# So we just ignore it and adopt the specs accordingly to coincide with the used libyaml version.
private def assert_yaml_document_end(actual, expected)
  if YAML.libyaml_version < SemanticVersion.new(0, 2, 1)
    expected += "...\n"
  end

  actual.should eq(expected)
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

    it "does Int32#from_yaml" do
      Int32.from_yaml("123").should eq(123)
      Int32.from_yaml("0xabc").should eq(0xabc)
      Int32.from_yaml("0b10110").should eq(0b10110)
    end

    it "does Int64#from_yaml" do
      Int64.from_yaml("123456789123456789").should eq(123456789123456789)
    end

    it "does String#from_yaml" do
      String.from_yaml("hello").should eq("hello")
    end

    it "raises on reserved string" do
      expect_raises(YAML::ParseException) do
        String.from_yaml(%(1.2))
      end
    end

    it "does Float32#from_yaml" do
      Float32.from_yaml("1.5").should eq(1.5_f32)
      Float32.from_yaml(".inf").should eq(Float32::INFINITY)
    end

    it "does Float64#from_yaml" do
      value = Float64.from_yaml("1.5")
      value.should eq(1.5)
      value.should be_a(Float64)
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

    it "does Tuple#from_yaml" do
      Tuple(Int32, String, Bool).from_yaml("---\n- 1\n- foo\n- true\n").should eq({1, "foo", true})
    end

    it "does for named tuple" do
      tuple = NamedTuple(x: Int32, y: String).from_yaml(%({"y": "hello", "x": 1}))
      tuple.should eq({x: 1, y: "hello"})
      tuple.should be_a(NamedTuple(x: Int32, y: String))
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

    it "does for Enum with number" do
      YAMLSpecEnum.from_yaml(%("1")).should eq(YAMLSpecEnum::One)

      expect_raises(Exception, "Unknown enum YAMLSpecEnum value: 3") do
        YAMLSpecEnum.from_yaml(%("3"))
      end
    end

    it "does for Enum with string" do
      YAMLSpecEnum.from_yaml(%("One")).should eq(YAMLSpecEnum::One)

      expect_raises(ArgumentError, "Unknown enum YAMLSpecEnum value: Three") do
        YAMLSpecEnum.from_yaml(%("Three"))
      end
    end

    it "does Time::Format#from_yaml" do
      ctx = YAML::ParseContext.new
      nodes = YAML::Nodes.parse("--- 2014-01-02\n...\n").nodes.first
      value = Time::Format.new("%F").from_yaml(ctx, nodes)
      value.should eq(Time.utc(2014, 1, 2))
    end

    it "deserializes union" do
      Array(Int32 | String).from_yaml(%([1, "hello"])).should eq([1, "hello"])
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
        ex.message.should eq("Expected Nil, not 1 at line 2, column 3")
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

    it "does for Bool" do
      Bool.from_yaml(true.to_yaml).should eq(true)
      Bool.from_yaml(false.to_yaml).should eq(false)
    end

    it "does for Int32" do
      Int32.from_yaml(1.to_yaml).should eq(1)
    end

    it "does for Float64" do
      Float64.from_yaml(1.5.to_yaml).should eq(1.5)
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

    it "quotes string if reserved" do
      ["1", "1.2", "true", "2010-11-12"].each do |string|
        string.to_yaml.should eq(%(--- "#{string}"\n))
      end
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

    it "does for Enum" do
      YAMLSpecEnum.from_yaml(YAMLSpecEnum::One.to_yaml).should eq(YAMLSpecEnum::One)
    end

    it "does for utc time" do
      time = Time.utc(2010, 11, 12, 1, 2, 3)
      assert_yaml_document_end(time.to_yaml, "--- 2010-11-12 01:02:03\n")
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

      expected = "---\nhello: World\ninteger: 2\nfloat: 3.5\nhash:\n  a: 1\n  b: 2\narray:\n- 1\n- 2\n- 3\nnull: \n"

      data.to_yaml.should eq(expected)
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

      h.to_yaml.should eq("--- &1\n1: 2\n*1: *1\n")
    end
  end
end
