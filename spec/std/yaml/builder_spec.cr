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

  it "writes scalar with style" do
    assert_built(%(--- "1"\n)) do
      scalar(1, style: YAML::ScalarStyle::DOUBLE_QUOTED)
    end
  end

  it "writes scalar with tag" do
    assert_built(%(--- !foo 1\n...\n)) do
      scalar(1, tag: "!foo")
    end
  end

  it "writes scalar with anchor" do
    assert_built(%(--- &foo 1\n...\n)) do
      scalar(1, anchor: "foo")
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

  it "writes sequence with tag" do
    assert_built("--- !foo\n- 1\n- 2\n- 3\n") do
      sequence(tag: "!foo") do
        scalar(1)
        scalar(2)
        scalar(3)
      end
    end
  end

  it "writes sequence with anchor" do
    assert_built("--- &foo\n- 1\n- 2\n- 3\n") do
      sequence(anchor: "foo") do
        scalar(1)
        scalar(2)
        scalar(3)
      end
    end
  end

  it "writes sequence with style" do
    assert_built("--- [1, 2, 3]\n") do
      sequence(style: YAML::SequenceStyle::FLOW) do
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

  it "writes mapping with tag" do
    assert_built("--- !foo\nfoo: 1\nbar: 2\n") do
      mapping(tag: "!foo") do
        scalar("foo")
        scalar(1)
        scalar("bar")
        scalar(2)
      end
    end
  end

  it "writes mapping with anchor" do
    assert_built("--- &foo\nfoo: 1\nbar: 2\n") do
      mapping(anchor: "foo") do
        scalar("foo")
        scalar(1)
        scalar("bar")
        scalar(2)
      end
    end
  end

  it "writes mapping with style" do
    assert_built("--- {foo: 1, bar: 2}\n") do
      mapping(style: YAML::MappingStyle::FLOW) do
        scalar("foo")
        scalar(1)
        scalar("bar")
        scalar(2)
      end
    end
  end
end
