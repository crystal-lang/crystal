require "spec"
require "yaml"

describe "YAML" do
  describe "parser" do
    assert { expect(YAML.load("foo")).to eq("foo") }
    assert { expect(YAML.load("- foo\n- bar")).to eq(["foo", "bar"]) }
    assert { expect(YAML.load_all("---\nfoo\n---\nbar\n")).to eq(["foo", "bar"]) }
    assert { expect(YAML.load("foo: bar")).to eq({"foo" => "bar"}) }
    assert { expect(YAML.load("--- []\n")).to eq([] of YAML::Type) }
    assert { expect(YAML.load("---\n...")).to eq("") }

    it "parses recursive sequence" do
      doc = YAML.load("--- &foo\n- *foo\n") as Array
      expect(doc[0].object_id).to eq(doc.object_id)
    end

    it "parses alias to scalar" do
      doc = YAML.load("---\n- &x foo\n- *x\n") as Array
      expect(doc).to eq(["foo", "foo"])
      expect(doc[0].object_id).to eq(doc[1].object_id)
    end
  end
end
