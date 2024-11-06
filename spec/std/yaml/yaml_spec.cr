require "spec"
require "yaml"

describe "YAML" do
  describe "parser" do
    it { YAML.parse("foo").should eq("foo") }
    it { YAML.parse("- foo\n- bar").should eq(["foo", "bar"]) }
    it { YAML.parse_all("---\nfoo\n---\nbar\n").should eq(["foo", "bar"]) }
    it { YAML.parse("foo: bar").should eq({"foo" => "bar"}) }
    it { YAML.parse("--- []\n").should eq([] of YAML::Any) }
    it { YAML.parse("---\n...").should eq nil }

    it "parses recursive sequence" do
      doc = YAML.parse("--- &foo\n- *foo\n")
      doc[0].as_a.should be(doc.raw.as(Array))
    end

    it "parses recursive mapping" do
      doc = YAML.parse(%(--- &1
        friends:
        - *1
        ))
      doc["friends"][0].as_h.should be(doc.as_h)
    end

    it "parses alias to scalar" do
      doc = YAML.parse("---\n- &x foo\n- *x\n")
      doc.should eq(["foo", "foo"])
      doc[0].as_s.should be(doc[1].as_s)
    end

    describe "merging with << key" do
      it "merges other mapping" do
        doc = YAML.parse(%(---
          foo: bar
          <<:
            baz: foobar
          ))
        doc["baz"]?.should eq("foobar")
      end

      it "raises if merging with missing alias" do
        expect_raises(YAML::ParseException, "Unknown anchor 'bar'") do
          YAML.parse(%(---
            foo:
              <<: *bar
          ))
        end
      end

      it "merges other mapping with alias" do
        doc = YAML.parse(%(---
          foo: &x
            bar: 1
            baz: 2
          bar:
            <<: *x
          ))
        doc["bar"].should eq({"bar" => 1, "baz" => 2})
      end

      it "merges other mapping with array of alias" do
        doc = YAML.parse(%(---
          foo: &x
            bar: 1
          bar: &y
            baz: 2
          bar:
            <<: [*x, *y]
          ))
        doc["bar"].should eq({"bar" => 1, "baz" => 2})
      end

      it "doesn't merge explicit string key <<" do
        doc = YAML.parse(%(---
          foo: &foo
            hello: world
          bar:
            !!str '<<': *foo
        ))
        doc.should eq({"foo" => {"hello" => "world"}, "bar" => {"<<" => {"hello" => "world"}}})
      end

      it "doesn't merge empty mapping" do
        doc = YAML.parse(%(---
          foo: &foo
          bar:
            <<: *foo
        ))
        doc["bar"].should eq({"<<" => nil})
      end

      it "doesn't merge arrays" do
        doc = YAML.parse(%(---
          foo: &foo
            - 1
          bar:
            <<: *foo
        ))
        doc["bar"].should eq({"<<" => [1]})
      end

      it "has correct line/number info (#2585)" do
        begin
          YAML.parse <<-YAML
            ---
            level_one:
            - name: "test"
               attributes:
                 one: "broken"
            YAML
          fail "expected YAML.parse to raise"
        rescue ex : YAML::ParseException
          ex.line_number.should eq(4)
          ex.column_number.should eq(4)
        end
      end

      it "has correct line/number info (2)" do
        begin
          parser = YAML::PullParser.new <<-MSG

              authors:
                - [foo] bar
            MSG

          parser.read_stream do
            parser.read_document do
              parser.read_scalar
            end
          end
        rescue ex : YAML::ParseException
          ex.line_number.should eq(2)
          ex.column_number.should eq(3)
        end
      end

      it "has correct message (#4006)" do
        expect_raises YAML::ParseException, "could not find expected ':' at line 4, column 1, while scanning a simple key at line 3, column 5" do
          YAML.parse <<-YAML
            a:
              - "b": >
                c
            YAML
        end
      end

      it "parses from IO" do
        YAML.parse(IO::Memory.new("- foo\n- bar")).should eq(["foo", "bar"])
      end
    end
  end

  describe "dump" do
    it "returns YAML as a string" do
      YAML.dump(%w(1 2 3)).should eq(%(---\n- "1"\n- "2"\n- "3"\n))
    end

    it "writes YAML to a stream" do
      string = String.build do |str|
        YAML.dump(%w(1 2 3), str)
      end
      string.should eq(%(---\n- "1"\n- "2"\n- "3"\n))
    end
  end
end
