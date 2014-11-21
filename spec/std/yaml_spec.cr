require "spec"
require "yaml"

describe "Yaml" do
  describe "parser" do
    assert { Yaml.load("foo").should eq("foo") }
    assert { Yaml.load("- foo\n- bar").should eq(["foo", "bar"]) }
    assert { Yaml.load_all("---\nfoo\n---\nbar\n").should eq(["foo", "bar"]) }
    assert { Yaml.load("foo: bar").should eq({"foo" => "bar"}) }
    assert { Yaml.load("--- []\n").should eq([] of Yaml::Type) }
    assert { Yaml.load("---\n...").should eq("") }

    it "parses recursive sequence" do
      doc = Yaml.load("--- &foo\n- *foo\n") as Array
      doc[0].object_id.should eq(doc.object_id)
    end

    it "parses alias to scalar" do
      doc = Yaml.load("---\n- &x foo\n- *x\n") as Array
      doc.should eq(["foo", "foo"])
      doc[0].object_id.should eq(doc[1].object_id)
    end
  end
end
