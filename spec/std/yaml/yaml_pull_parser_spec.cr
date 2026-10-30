require "spec"
require "yaml"

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

    describe "skip" do
      it "scalar" do
        parser = PullParser.new("[1, 2]")
        parser.read_stream do
          parser.read_document do
            parser.read_sequence do
              parser.skip
              parser.read_scalar.should eq("2")
            end
          end
        end
      end

      it "alias" do
        parser = PullParser.new(<<-YAML)
          - &value 1
          - *value
          - 2
          YAML
        parser.read_stream do
          parser.read_document do
            parser.read_sequence do
              parser.read_scalar.should eq("1")
              parser.skip
              parser.read_scalar.should eq("2")
            end
          end
        end
      end

      it "sequence" do
        parser = PullParser.new("[[1, [2]], 3]")
        parser.read_stream do
          parser.read_document do
            parser.read_sequence do
              parser.skip
              parser.read_scalar.should eq("3")
            end
          end
        end
      end

      it "mapping" do
        parser = PullParser.new(%([{"foo": [1, 2]}, 3]))
        parser.read_stream do
          parser.read_document do
            parser.read_sequence do
              parser.skip
              parser.read_scalar.should eq("3")
            end
          end
        end
      end

      it "stream" do
        parser = PullParser.new("[1]")
        parser.skip
        parser.read_next.should eq(EventKind::NONE)
      end

      it "document" do
        parser = PullParser.new("[1]")
        parser.read_stream do
          parser.skip
        end
        parser.read_next.should eq(EventKind::NONE)
      end

      it "skips event in other cases" do
        parser = PullParser.new(%([ {"foo": 1}]))
        parser.kind.should eq(EventKind::STREAM_START)
        parser.read_next.should eq(EventKind::DOCUMENT_START)
        parser.read_next.should eq(EventKind::SEQUENCE_START)
        parser.read_next.should eq(EventKind::MAPPING_START)
        parser.read_next.should eq(EventKind::SCALAR)
        parser.read_next.should eq(EventKind::SCALAR)
        parser.skip
        parser.kind.should eq(EventKind::MAPPING_END)
        parser.skip
        parser.kind.should eq(EventKind::SEQUENCE_END)
        parser.skip
        parser.kind.should eq(EventKind::DOCUMENT_END)
        parser.skip
        parser.kind.should eq(EventKind::STREAM_END)
        parser.skip
        parser.kind.should eq(EventKind::NONE)
      end
    end

    describe "budget" do
      it_raises = ->(parser : PullParser, msg : String) {
        expect_raises(ParseException, msg) do
          until parser.read_next == EventKind::NONE
          end
        end
      }

      it "limits maximum number of events" do
        parser = PullParser.new("- 1\n" * 1001, Options.new(max_events: 1_000))
        it_raises.call(parser, "Exceeded maximum number of events")
      end

      it "limits maximum number of documents" do
        parser = PullParser.new("---\n" * 1001)
        it_raises.call(parser, "Exceeded maximum number of documents")
      end

      it "limits maximum number of nodes" do
        parser = PullParser.new("- lol\n" * 1001, Options.new(max_nodes: 1_000))
        it_raises.call(parser, "Exceeded maximum number of nodes")
      end

      it "limits maximum number of aliases" do
        yaml = String.build do |str|
          str << %(x: &x lol\n)
          50_001.times { |i| str << "a" << i << ": *x\n" }
        end
        parser = PullParser.new(yaml, Options.new(enforce_alias_anchor_ratio: false))
        it_raises.call(parser, "Exceeded maximum number of aliases")
      end

      it "limits maximum number of anchors" do
        yaml = String.build do |str|
          50_001.times { |i| str << "a" << i << ": &a" << i << " lol\n" }
        end
        parser = PullParser.new(yaml, Options.new(enforce_alias_anchor_ratio: false))
        it_raises.call(parser, "Exceeded maximum number of anchors")
      end

      it "limits maximum depth to prevent stack overflows (sequence)" do
        parser = PullParser.new("x: " + ("[" * 1000))
        it_raises.call(parser, "Exceeded maximum depth")
      end

      it "limits maximum depth to prevent stack overflows (mapping)" do
        parser = PullParser.new "x: " + ("{" * 1000)
        it_raises.call(parser, "Exceeded maximum depth")
      end

      it "prevents excessive node expansions (billion-laugh attacks)" do
        parser = PullParser.new(<<-YAML)
        a: &a ["lol","lol","lol","lol","lol","lol","lol","lol","lol"]
        b: &b [*a,*a,*a,*a,*a,*a,*a,*a,*a]
        c: &c [*b,*b,*b,*b,*b,*b,*b,*b,*b]
        d: &d [*c,*c,*c,*c,*c,*c,*c,*c,*c]
        e: &e [*d,*d,*d,*d,*d,*d,*d,*d,*d]
        f: &f [*e,*e,*e,*e,*e,*e,*e,*e,*e]
        g: &g [*f,*f,*f,*f,*f,*f,*f,*f,*f]
        h: &h [*g,*g,*g,*g,*g,*g,*g,*g,*g]
        i: &i [*h,*h,*h,*h,*h,*h,*h,*h,*h]
        YAML
        it_raises.call(parser, "Document contains excessive aliasing")
      end
    end
  end
end
