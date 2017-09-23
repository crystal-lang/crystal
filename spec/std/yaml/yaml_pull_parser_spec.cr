require "spec"
require "yaml"

private def assert_raw(string, expected = string, file = __FILE__, line = __LINE__)
  it "parses raw #{string.inspect}", file, line do
    pull = YAML::PullParser.new(string)
    pull.read_stream do
      pull.read_document do
        pull.read_raw.should eq(expected)
      end
    end
  end
end

module YAML
  describe PullParser do
    it "reads empty stream" do
      parser = PullParser.new("")
      parser.kind.should eq(EventKind::STREAM_START)
      parser.read_next.should eq(EventKind::STREAM_END)
      parser.kind.should eq(EventKind::STREAM_END)
    end

    it "reads an empty document" do
      parser = PullParser.new("---\n...\n")
      parser.read_stream do
        parser.read_document do
          parser.read_scalar.should eq("")
        end
      end
    end

    it "reads a scalar" do
      parser = PullParser.new("--- foo\n...\n")
      parser.read_stream do
        parser.read_document do
          parser.read_scalar.should eq("foo")
        end
      end
    end

    it "reads a scalar having a null character" do
      parser = PullParser.new(%(--- "foo\\0bar"\n...\n))
      parser.read_stream do
        parser.read_document do
          parser.read_scalar.should eq("foo\0bar")
        end
      end
    end

    it "reads a sequence" do
      parser = PullParser.new("---\n- 1\n- 2\n- 3\n")
      parser.read_stream do
        parser.read_document do
          parser.read_sequence do
            parser.read_scalar.should eq("1")
            parser.read_scalar.should eq("2")
            parser.read_scalar.should eq("3")
          end
        end
      end
    end

    it "reads a scalar with an anchor" do
      parser = PullParser.new("--- &foo bar\n...\n")
      parser.read_stream do
        parser.read_document do
          parser.anchor.should eq("foo")
          parser.read_scalar.should eq("bar")
        end
      end
    end

    it "reads a sequence with an anchor" do
      parser = PullParser.new("--- &foo []\n")
      parser.read_stream do
        parser.read_document do
          parser.anchor.should eq("foo")
          parser.read_sequence do
          end
        end
      end
    end

    it "reads a mapping" do
      parser = PullParser.new(%(---\nfoo: 1\nbar: 2\n))
      parser.read_stream do
        parser.read_document do
          parser.read_mapping do
            parser.read_scalar.should eq("foo")
            parser.read_scalar.should eq("1")
            parser.read_scalar.should eq("bar")
            parser.read_scalar.should eq("2")
          end
        end
      end
    end

    it "reads a mapping with an anchor" do
      parser = PullParser.new(%(---\n&lala {}\n))
      parser.read_stream do
        parser.read_document do
          parser.anchor.should eq("lala")
          parser.read_mapping do
          end
        end
      end
    end

    it "parses alias" do
      parser = PullParser.new("--- *foo\n")
      parser.read_stream do
        parser.read_document do
          parser.read_alias.should eq("foo")
        end
      end
    end

    assert_raw %(hello)
    assert_raw %("hello"), %(hello)
    assert_raw %(["hello"])
    assert_raw %(["hello","world"])
    assert_raw %({"hello":"world"})

    it "raises exception at correct location" do
      parser = PullParser.new("[1]")
      parser.read_stream do
        parser.read_document do
          parser.read_sequence do
            ex = expect_raises(YAML::ParseException) do
              parser.read_mapping do
              end
            end
            ex.location.should eq({1, 2})

            parser.read_scalar
          end
        end
      end
    end
  end
end
