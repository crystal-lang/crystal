require "spec"
require "yaml"

describe "YAML" do
  describe "parser" do
    assert { YAML.load("foo").should eq("foo") }
    assert { YAML.load("- foo\n- bar").should eq(["foo", "bar"]) }
    assert { YAML.load_all("---\nfoo\n---\nbar\n").should eq(["foo", "bar"]) }
    assert { YAML.load("foo: bar").should eq({"foo" => "bar"}) }
    assert { YAML.load("--- []\n").should eq([] of YAML::Type) }
    assert { YAML.load("---\n...").should eq("") }

    it "parses recursive sequence" do
      doc = YAML.load("--- &foo\n- *foo\n") as Array
      doc[0].should be(doc)
    end

    it "parses alias to scalar" do
      doc = YAML.load("---\n- &x foo\n- *x\n") as Array
      doc.should eq(["foo", "foo"])
      doc[0].should be(doc[1])
    end
  end
end
