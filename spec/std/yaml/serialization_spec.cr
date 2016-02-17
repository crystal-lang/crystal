require "spec"
require "yaml"

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

    it "does Time::Format#from_yaml" do
      pull = YAML::PullParser.new("--- 2014-01-02\n...\n")
      pull.read_stream do
        pull.read_document do
          Time::Format.new("%F").from_yaml(pull).should eq(Time.new(2014, 1, 2))
        end
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
      Hash(String, Int32).from_yaml({foo: 1, bar: 2}.to_yaml).should eq({"foo" => 1, "bar" => 2})
    end

    it "does for Tuple" do
      Tuple(Int32, String).from_yaml({1, "hello"}.to_yaml).should eq({1, "hello"})
    end

    it "does a full document" do
      data = {
        hello:   "World",
        integer: 2,
        float:   3.5,
        hash:    {
          a: 1,
          b: 2,
        },
        array: [1, 2, 3],
        null:  nil,
      }

      expected = "--- \nhello: World\ninteger: 2\nfloat: 3.5\nhash: \n  a: 1\n  b: 2\narray: \n  - 1\n  - 2\n  - 3\nnull: "

      data.to_yaml.should eq(expected)
    end

    it "writes to a stream" do
      string = String.build do |str|
        %w(a b c).to_yaml(str)
      end
      string.should eq("--- \n- a\n- b\n- c")
    end
  end
end
