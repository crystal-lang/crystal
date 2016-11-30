require "spec"
require "yaml"
require "big"
require "big/yaml"

enum YAMLSpecEnum
  Zero
  One
  Two
end

class YAMLScalarTester
  @val : String
  @tag : String?
  @style : LibYAML::ScalarStyle?

  def initialize(value, tag : String? = nil, style : LibYAML::ScalarStyle? = nil)
    @val = value
    @tag = tag
    @style = style
  end

  def to_yaml(emitter : YAML::Emitter, tag : String? = nil, style : LibYAML::ScalarStyle? = nil)
    @val.to_yaml(emitter, tag: tag || @tag, style: style || @style)
  end
end

describe "YAML serialization" do
  describe "from_yaml" do
    it "does Nil#from_yaml" do
      Nil.from_yaml("--- \n...\n").should be_nil
    end

    it "does Bool#from_yaml" do
      Bool.from_yaml("true").should be_true
      Bool.from_yaml("false").should be_false
    end

    it "does Int32#from_yaml" do
      Int32.from_yaml("123").should eq(123)
    end

    it "does Int64#from_yaml" do
      Int64.from_yaml("123456789123456789").should eq(123456789123456789)
    end

    it "does String#from_yaml" do
      String.from_yaml("hello").should eq("hello")
    end

    it "does Float32#from_yaml" do
      Float32.from_yaml("1.5").should eq(1.5)
    end

    it "does Float64#from_yaml" do
      value = Float64.from_yaml("1.5")
      value.should eq(1.5)
      value.should be_a(Float64)
    end

    it "does Array#from_yaml" do
      Array(Int32).from_yaml("---\n- 1\n- 2\n- 3\n").should eq([1, 2, 3])
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

    it "does for Enum with number" do
      YAMLSpecEnum.from_yaml(%("1")).should eq(YAMLSpecEnum::One)

      expect_raises do
        YAMLSpecEnum.from_yaml(%("3"))
      end
    end

    it "does for Enum with string" do
      YAMLSpecEnum.from_yaml(%("One")).should eq(YAMLSpecEnum::One)

      expect_raises do
        YAMLSpecEnum.from_yaml(%("Three"))
      end
    end

    it "does Time::Format#from_yaml" do
      pull = YAML::PullParser.new("--- 2014-01-02\n...\n")
      pull.read_stream do
        pull.read_document do
          Time::Format.new("%F").from_yaml(pull).should eq(Time.new(2014, 1, 2))
        end
      end
    end

    it "deserializes union" do
      Array(Int32 | String).from_yaml(%([1, "hello"])).should eq([1, "hello"])
    end

    it "deserializes time" do
      Time.from_yaml(%(2016-11-16T09:55:48-0300)).to_utc.should eq(Time.new(2016, 11, 16, 12, 55, 48, kind: Time::Kind::Utc))
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

    it "does for time" do
      Time.new(2016, 11, 16, 12, 55, 48, kind: Time::Kind::Utc).to_yaml.should eq("--- 2016-11-16T12:55:48+0000\n...\n")
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
  end

  describe "emits custom tag" do
    describe "for class" do
      it "String" do
        s = "HELLO"
        r = s.to_yaml("!custom")
        r.should eq("--- !custom HELLO\n...\n")
      end

      it "Symbol" do
        s = :HELLO
        r = s.to_yaml("!custom")
        r.should eq("--- !custom HELLO\n...\n")
      end

      it "Int" do
        x = 10
        r = x.to_yaml("!custom")
        r.should eq("--- !custom 10\n...\n")
      end

      it "Array" do
        a = [10, 11]
        r = a.to_yaml(tag: "!custom")
        r.should eq("--- !custom\n- 10\n- 11\n")
      end

      it "Hash" do
        h = {"a" => "b"}
        r = h.to_yaml(tag: "!custom")
        r.should eq("--- !custom\na: b\n")
      end

      it "Tuple" do
        t = {"a", "b"}
        r = t.to_yaml(tag: "!custom")
        r.should eq("--- !custom\n- a\n- b\n")
      end

      it "NamedTuple" do
        n = {a: "b"}
        r = n.to_yaml(tag: "!custom")
        r.should eq("--- !custom\na: b\n")
      end

      it "Time" do
        t = Time.now
        r = t.to_yaml(tag: "!mytime")
        r.starts_with?("--- !mytime").should eq(true)
      end
    end

    describe "but not for core tag" do
      it "!!str" do
        x = "HELLO"
        r = x.to_yaml("tag:yaml.org,2002:str")
        r.should eq("--- HELLO\n...\n")
      end

      it "!!int" do
        x = 10
        r = x.to_yaml("tag:yaml.org,2002:int")
        r.should eq("--- 10\n...\n")
      end

      it "!!float" do
        x = 10.5
        r = x.to_yaml("tag:yaml.org,2002:float")
        r.should eq("--- 10.5\n...\n")
      end

      it "!!null" do
        x = nil
        r = x.to_yaml("tag:yaml.org,2002:null")
        r.should eq("--- \n...\n")
      end

      it "!!bool" do
        x = true
        r = x.to_yaml("tag:yaml.org,2002:bool")
        r.should eq("--- true\n...\n")

        x = false
        r = x.to_yaml("tag:yaml.org,2002:bool")
        r.should eq("--- false\n...\n")
      end

      it "!!seq" do
        x = ["A"]
        r = x.to_yaml("tag:yaml.org,2002:seq")
        r.should eq("---\n- A\n")
      end

      it "!!map" do
        x = {"A" => "X"}
        r = x.to_yaml("tag:yaml.org,2002:map")
        r.should eq("---\nA: X\n")
      end
    end

    describe "miscellaneous" do
      it "core tag" do
        x = "A"
        r = x.to_yaml("tag:yaml.org,2002:foo")
        r.should eq("--- !!foo A\n...\n")
      end

      it "full tag" do
        x = "A"
        r = x.to_yaml("tag:foo.org,2002:bar")
        r.should eq("--- !<tag:foo.org,2002:bar> A\n...\n")
      end

      it "for array element" do
        x = YAMLScalarTester.new("10", "!custom")
        a = [x]
        r = a.to_yaml
        r.should eq("---\n- !custom 10\n")
      end
    end
  end

  describe "emits specified style" do
    describe "scalar style" do
      # TODO: Output seems incorrect, but it has to be something with LibYAML.
      pending "PLAIN" do
        s = "ABC\nXYZ"
        r = s.to_yaml(style: LibYAML::ScalarStyle::PLAIN)
        r.should eq("---\n  ABC\n\n  XYZ\n")
      end

      pending "PLAIN as array element" do
        s = YAMLScalarTester.new("ABC\nXYZ", style: LibYAML::ScalarStyle::PLAIN)
        r = [s].to_yaml
        r.should eq("---\n- ABC\n\n  XYZ\n")
      end

      it "SINGLE_QUOTED" do
        s = "ABC"
        r = s.to_yaml(style: LibYAML::ScalarStyle::SINGLE_QUOTED)
        r.should eq("--- 'ABC'\n")
      end

      it "DOUBLE_QUOTED" do
        s = "ABC"
        r = s.to_yaml(style: LibYAML::ScalarStyle::DOUBLE_QUOTED)
        r.should eq("--- \"ABC\"\n")
      end

      it "LITERAL" do
        s = "ABC\nXYZ\n"
        r = s.to_yaml(style: LibYAML::ScalarStyle::LITERAL)
        r.should eq("--- |\n  ABC\n  XYZ\n")
      end

      it "FOLDED" do
        s = "ABC\nXYZ\n"
        r = s.to_yaml(style: LibYAML::ScalarStyle::FOLDED)
        r.should eq("--- >\n  ABC\n\n  XYZ\n")
      end
    end

    describe "sequence style" do
      it "BLOCK" do
        a = ["A", "B", "C"]
        r = a.to_yaml(style: LibYAML::SequenceStyle::BLOCK)
        r.should eq("---\n- A\n- B\n- C\n")
      end

      it "FLOW" do
        a = ["A", "B", "C"]
        r = a.to_yaml(style: LibYAML::SequenceStyle::FLOW)
        r.should eq("--- [A, B, C]\n")
      end
    end

    describe "mapping style" do
      it "BLOCK" do
        h = {"A" => "X", "B" => "Y", "C" => "Z"}
        r = h.to_yaml(style: LibYAML::MappingStyle::BLOCK)
        r.should eq("---\nA: X\nB: Y\nC: Z\n")
      end

      it "FLOW" do
        h = {"A" => "X", "B" => "Y", "C" => "Z"}
        r = h.to_yaml(style: LibYAML::MappingStyle::FLOW)
        r.should eq("--- {A: X, B: Y, C: Z}\n")
      end
    end
  end

  describe "with custom tag and specified style" do
    it "single quoted" do
      s = "ABC"
      r = s.to_yaml("!custom", LibYAML::ScalarStyle::SINGLE_QUOTED)
      r.should eq("--- !custom 'ABC'\n")
    end

    it "single quoted using named arguments" do
      i = 10
      r = i.to_yaml(tag: "!custom", style: LibYAML::ScalarStyle::SINGLE_QUOTED)
      r.should eq("--- !custom '10'\n")
    end

    it "double quoted symbol" do
      s = :ABC
      r = s.to_yaml("!custom", LibYAML::ScalarStyle::DOUBLE_QUOTED)
      r.should eq("--- !custom \"ABC\"\n")
    end
  end

  describe "complex example with custom tags and style" do
    yaml = <<-YAML
    --- !x
    - !a A
    - !b 'B'
    - !c "C"
    - !a A: !b 'B'
      !b 'B': !c "C"\n
    YAML

    a1 = YAMLScalarTester.new("A", "!a")
    a2 = YAMLScalarTester.new("B", "!b", LibYAML::ScalarStyle::SINGLE_QUOTED)
    a3 = YAMLScalarTester.new("C", "!c", LibYAML::ScalarStyle::DOUBLE_QUOTED)
    h = {a1 => a2, a2 => a3}

    x = [a1, a2, a3, h]

    r = x.to_yaml("!x", LibYAML::SequenceStyle::BLOCK)
    r.should eq(yaml)
  end
end
