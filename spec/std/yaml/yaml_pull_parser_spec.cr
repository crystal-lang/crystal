require "spec"
require "yaml"

class YAML::PullParser
  def assert_stream
    kind.should eq(EventKind::STREAM_START)
    yield read_next
    kind.should eq(EventKind::STREAM_END)
  end

  def assert_document
    kind.should eq(EventKind::DOCUMENT_START)
    read_next
    yield
    kind.should eq(EventKind::DOCUMENT_END)
    read_next
  end

  def assert_sequence(anchor = nil)
    kind.should eq(EventKind::SEQUENCE_START)
    assert_anchor anchor
    read_next
    yield
    kind.should eq(EventKind::SEQUENCE_END)
    read_next
  end

  def assert_mapping(anchor = nil)
    kind.should eq(EventKind::MAPPING_START)
    assert_anchor anchor
    read_next
    yield
    kind.should eq(EventKind::MAPPING_END)
    read_next
  end

  def assert_scalar(value, anchor = nil)
    kind.should eq(EventKind::SCALAR)
    value.should eq(value)
    assert_anchor anchor
    read_next
  end

  def assert_alias(value)
    kind.should eq(EventKind::ALIAS)
    value.should eq(value)
    read_next
  end

  def assert_anchor(anchor)
    self.anchor.should eq(anchor) if anchor
  end
end

module YAML
  describe PullParser do
    it "reads empty stream" do
      parser = PullParser.new("")
      parser.assert_stream { |kind| kind.should eq(EventKind::STREAM_END) }
    end

    it "reads an empty document" do
      parser = PullParser.new("---\n...\n")
      parser.assert_stream do
        parser.assert_document do
          parser.assert_scalar ""
        end
      end
    end

    it "reads a scalar" do
      parser = PullParser.new("--- foo\n...\n")
      parser.assert_stream do
        parser.assert_document do
          parser.assert_scalar "foo"
        end
      end
    end

    it "reads a sequence" do
      parser = PullParser.new("---\n- 1\n- 2\n- 3\n")
      parser.assert_stream do
        parser.assert_document do
          parser.assert_sequence do
            parser.assert_scalar "1"
            parser.assert_scalar "2"
            parser.assert_scalar "3"
          end
        end
      end
    end

    it "reads a scalar with an anchor" do
      parser = PullParser.new("--- &foo bar\n...\n")
      parser.assert_stream do
        parser.assert_document do
          parser.assert_scalar "bar", anchor: "foo"
        end
      end
    end

    it "reads a sequence with an anchor" do
      parser = PullParser.new("--- &foo []\n")
      parser.assert_stream do
        parser.assert_document do
          parser.assert_sequence(anchor: "foo") do
          end
        end
      end
    end

    it "reads a mapping" do
      parser = PullParser.new(%(---\nfoo: 1\nbar: 2\n))
      parser.assert_stream do
        parser.assert_document do
          parser.assert_mapping do
            parser.assert_scalar "foo"
            parser.assert_scalar "1"
            parser.assert_scalar "bar"
            parser.assert_scalar "2"
          end
        end
      end
    end

    it "reads a mapping with an anchor" do
      parser = PullParser.new(%(---\n&lala {}\n))
      parser.assert_stream do
        parser.assert_document do
          parser.assert_mapping(anchor: "lala") do
          end
        end
      end
    end

    it "parses alias" do
      parser = PullParser.new("--- *foo\n")
      parser.assert_stream do
        parser.assert_document do
          parser.assert_alias "foo"
        end
      end
    end

    it "parses alias with anchor" do
      parser = PullParser.new("--- *foo\n")
      parser.assert_stream do
        parser.assert_document do
          parser.assert_alias "foo"
        end
      end
    end
  end
end
