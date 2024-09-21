require "spec"
require "yaml"
require "spec/helpers/string"

private def assert_built(expected, expect_document_end = false, *, file = __FILE__, line = __LINE__, &)
  # libyaml 0.2.1 removed the erroneously written document end marker (`...`) after some scalars in root context (see https://github.com/yaml/libyaml/pull/18).
  # Earlier libyaml releases still write the document end marker and this is hard to fix on Crystal's side.
  # So we just ignore it and adopt the specs accordingly to coincide with the used libyaml version.
  if expect_document_end
    if YAML.libyaml_version < SemanticVersion.new(0, 2, 1)
      expected += "...\n"
    end
  end

  assert_prints YAML.build { |yaml| with yaml yield yaml }, expected, file: file, line: line
end

describe YAML::Builder do
  it "writes scalar" do
    assert_built("--- 1\n", expect_document_end: true) do
      scalar(1)
    end
  end

  it "writes alias" do
    assert_built("--- *key\n") do
      itself.alias "key"
    end
  end

  it "writes scalar with style" do
    assert_built(%(--- "1"\n)) do
      scalar(1, style: YAML::ScalarStyle::DOUBLE_QUOTED)
    end
  end

  it "writes scalar with tag" do
    assert_built(%(--- !foo 1\n), expect_document_end: true) do
      scalar(1, tag: "!foo")
    end
  end

  it "writes scalar with anchor" do
    assert_built(%(--- &foo 1\n), expect_document_end: true) do
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

  it "writes mapping with alias" do
    assert_built("---\nfoo: *bar\n") do
      mapping do
        scalar "foo"
        itself.alias "bar"
      end
    end
  end

  it "writes mapping with merge" do
    assert_built("---\n<<: *key\n") do
      mapping do
        merge "key"
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

  it "errors on max nesting (sequence)" do
    io = IO::Memory.new
    builder = YAML::Builder.new(io)
    builder.max_nesting = 3
    builder.start_stream
    builder.start_document
    3.times do
      builder.start_sequence
    end

    expect_raises(YAML::Error, "Nesting of 4 is too deep") do
      builder.start_sequence
    end
  end

  it "errors on max nesting (mapping)" do
    io = IO::Memory.new
    builder = YAML::Builder.new(io)
    builder.max_nesting = 3
    builder.start_stream
    builder.start_document
    3.times do
      builder.start_mapping
    end

    expect_raises(YAML::Error, "Nesting of 4 is too deep") do
      builder.start_mapping
    end
  end

  it ".build (with block)" do
    String.build do |io|
      YAML::Builder.build(io) do |builder|
        builder.stream do
          builder.document do
            builder.scalar(1)
          end
        end
      end
    end.should eq 1.to_yaml
  end
end
