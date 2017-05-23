require "spec"
require "yaml"

private def assert_built(expected)
  string = YAML.build do |yaml|
    with yaml yield yaml
  end
  string.should eq(expected)
end

describe YAML::Builder do
  it "writes scalar" do
    assert_built("--- 1\n...\n") do
      scalar(1)
    end
  end

  it "writes sequence" do
    assert_built("---\n- 1\n- 2\n- 3\n") do
      sequence do
        scalar(1)
        scalar(2)
        scalar(3)
      end
    end
  end

  it "writes mapping" do
    assert_built("---\nfoo: 1\nbar: 2\n") do
      mapping do
        scalar("foo")
        scalar(1)
        scalar("bar")
        scalar(2)
      end
    end
  end
end
