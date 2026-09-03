require "spec"
require "yaml"

private def assert_built(expected, expect_document_end = false, &)
  # libyaml 0.2.1 removed the erroneously written document end marker (`...`) after some scalars in root context (see https://github.com/yaml/libyaml/pull/18).
  # Earlier libyaml releases still write the document end marker and this is hard to fix on Crystal's side.
  # So we just ignore it and adopt the specs accordingly to coincide with the used libyaml version.
  if expect_document_end
    if YAML.libyaml_version < SemanticVersion.new(0, 2, 1)
      expected += "...\n"
    end
  end

  nodes_builder = YAML::Nodes::Builder.new

  with nodes_builder yield nodes_builder

  string = YAML.build do |builder|
    nodes_builder.document.to_yaml builder
  end
  string.should eq(expected)
end

describe YAML::Nodes::Builder do
  describe "#alias" do
    describe "as a scalar value" do
      it "writes correctly" do
        assert_built("--- *key\n") do
          itself.alias "key"
        end
      end
    end

    describe "within a mapping" do
      it "writes correctly" do
        assert_built("---\nfoo: *bar\n") do
          mapping do
            scalar "foo"
            itself.alias "bar"
          end
        end
      end
    end
  end

  describe "#merge" do
    describe "within a mapping" do
      it "writes correctly" do
        assert_built("---\n<<: *bar\n") do
          mapping do
            merge "bar"
          end
        end
      end
    end
  end
end
