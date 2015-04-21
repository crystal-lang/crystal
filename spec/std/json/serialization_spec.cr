require "spec"
require "json"

describe "JSON serialization" do
  describe "from_json" do
    it "does Array(Nil)#from_json" do
      expect(Array(Nil).from_json("[null, null]")).to eq([nil, nil])
    end

    it "does Array(Bool)#from_json" do
      expect(Array(Bool).from_json("[true, false]")).to eq([true, false])
    end

    it "does Array(Int32)#from_json" do
      expect(Array(Int32).from_json("[1, 2, 3]")).to eq([1, 2, 3])
    end

    it "does Array(Int64)#from_json" do
      expect(Array(Int64).from_json("[1, 2, 3]")).to eq([1, 2, 3])
    end

    it "does Array(Float32)#from_json" do
      expect(Array(Float32).from_json("[1.5, 2, 3.5]")).to eq([1.5, 2.0, 3.5])
    end

    it "does Array(Float64)#from_json" do
      expect(Array(Float64).from_json("[1.5, 2, 3.5]")).to eq([1.5, 2, 3.5])
    end

    it "does Hash(String, String)#from_json" do
      expect(Hash(String, String).from_json(%({"foo": "x", "bar": "y"}))).to eq({"foo" => "x", "bar" => "y"})
    end

    it "does Hash(String, Int32)#from_json" do
      expect(Hash(String, Int32).from_json(%({"foo": 1, "bar": 2}))).to eq({"foo" => 1, "bar" => 2})
    end

    it "does Hash(String, Int32)#from_json and skips null" do
      expect(Hash(String, Int32).from_json(%({"foo": 1, "bar": 2, "baz": null}))).to eq({"foo" => 1, "bar" => 2})
    end

    it "does for Array(Int32) from IO" do
      io = StringIO.new "[1, 2, 3]"
      expect(Array(Int32).from_json(io)).to eq([1, 2, 3])
    end

    it "does for Array(Int32) with block" do
      elements = [] of Int32
      Array(Int32).from_json("[1, 2, 3]") do |element|
        elements << element
      end
      expect(elements).to eq([1, 2, 3])
    end
  end

  describe "to_json" do
    it "does for Nil" do
      expect(nil.to_json).to eq("null")
    end

    it "does for Bool" do
      expect(true.to_json).to eq("true")
    end

    it "does for Int32" do
      expect(1.to_json).to eq("1")
    end

    it "does for Float64" do
      expect(1.5.to_json).to eq("1.5")
    end

    it "does for String" do
      expect("hello".to_json).to eq("\"hello\"")
    end

    it "does for String with quote" do
      expect("hel\"lo".to_json).to eq("\"hel\\\"lo\"")
    end

    it "does for String with slash" do
      expect("hel\\lo".to_json).to eq("\"hel\\\\lo\"")
    end

    it "does for String with control codes" do
      expect("\b".to_json).to eq("\"\\b\"")
      expect("\f".to_json).to eq("\"\\f\"")
      expect("\n".to_json).to eq("\"\\n\"")
      expect("\r".to_json).to eq("\"\\r\"")
      expect("\t".to_json).to eq("\"\\t\"")
      expect("\u{19}".to_json).to eq("\"\\u0019\"")
    end

    it "does for Array" do
      expect([1, 2, 3].to_json).to eq("[1,2,3]")
    end

    it "does for Hash" do
      expect({"foo" => 1, "bar" => 2}.to_json).to eq(%({"foo":1,"bar":2}))
    end

    it "does for Hash with non-string keys" do
      expect({foo: 1, bar: 2}.to_json).to eq(%({"foo":1,"bar":2}))
    end
  end

  describe "to_pretty_json" do
    it "does for Nil" do
      expect(nil.to_pretty_json).to eq("null")
    end

    it "does for Bool" do
      expect(true.to_pretty_json).to eq("true")
    end

    it "does for Int32" do
      expect(1.to_pretty_json).to eq("1")
    end

    it "does for Float64" do
      expect(1.5.to_pretty_json).to eq("1.5")
    end

    it "does for String" do
      expect("hello".to_pretty_json).to eq("\"hello\"")
    end

    it "does for Array" do
      expect([1, 2, 3].to_pretty_json).to eq("[\n  1,\n  2,\n  3\n]")
    end

    it "does for nested Array" do
      expect([[1, 2, 3]].to_pretty_json).to eq("[\n  [\n    1,\n    2,\n    3\n  ]\n]")
    end

    it "does for empty Array" do
      expect(([] of Nil).to_pretty_json).to eq("[]")
    end

    it "does for Hash" do
      expect({"foo" => 1, "bar" => 2}.to_pretty_json).to eq(%({\n  "foo": 1,\n  "bar": 2\n}))
    end

    it "does for nested Hash" do
      expect({"foo" => {"bar" => 1} }.to_pretty_json).to eq(%({\n  "foo": {\n    "bar": 1\n  }\n}))
    end

    it "does for empty Hash" do
      expect(({} of Nil => Nil).to_pretty_json).to eq(%({}))
    end
  end
end
