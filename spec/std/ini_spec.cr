require "./spec_helper"
require "ini"

describe "INI" do
  describe "parse" do
    context "from String" do
      it "fails on malformed section" do
        expect_raises(INI::ParseException, "Unterminated section") do
          INI.parse("[section")
        end
      end

      it "fails on data after section" do
        expect_raises(INI::ParseException, "Data after section") do
          INI.parse("[section] foo  ")
        end
      end

      it "fails on malformed declaration" do
        expect_raises(INI::ParseException, "Expected declaration") do
          INI.parse("foobar")
        end

        expect_raises(INI::ParseException, "Expected declaration") do
          INI.parse("foo: bar")
        end
      end

      it "parses key = value" do
        INI.parse("key = value").should eq({"" => {"key" => "value"}})
      end

      it "parses empty values" do
        INI.parse("key = ").should eq({"" => {"key" => ""}})
      end

      it "ignores whitespaces" do
        INI.parse("   key   =   value  ").should eq({"" => {"key" => "value"}})
        INI.parse("  [foo]").should eq({"foo" => Hash(String, String).new})
      end

      it "ignores comments" do
        INI.parse("; foo\n# bar\nkey = value").should eq({"" => {"key" => "value"}})
      end

      it "parses sections" do
        INI.parse("[section]\na = 1").should eq({"section" => {"a" => "1"}})
      end

      it "parses a reopened section" do
        INI.parse("[foo]\na=1\n[foo]\nb=2").should eq({"foo" => {"a" => "1", "b" => "2"}})
      end

      it "parses empty section" do
        INI.parse("[section]").should eq({"section" => Hash(String, String).new})
      end
    end

    context "from IO" do
      it "parses a file" do
        File.open datapath("test_file.ini") do |file|
          INI.parse(file).should eq({
            "general" => {
              "log_level" => "D",
            },
            "section1" => {
              "foo" => "1.1",
              "bar" => "2",
            },
            "section2" => {
              "x.y.z" => "coco lala",
            },
          })
        end
      end
    end
  end

  describe "build to an INI-formatted output" do
    it "builds from a Hash" do
      INI.build({
        "general" => {
          "log_level" => 'D',
        },
        "section1" => {
          "foo" => 1.1,
          "bar" => 2,
        },
        "section2" => {
          "x.y.z" => "coco lala",
        },
      }, true).should eq(File.read datapath("test_file.ini"))
    end
    it "builds from a NamedTuple" do
      INI.build({
        "general": {
          "log_level": 'D',
        },
        "section1": {
          "foo": 1.1,
          "bar": 2,
        },
        "section2": {
          "x.y.z": "coco lala",
        },
      }, true).should eq(File.read datapath("test_file.ini"))
    end

    it "builds with no spaces around `=`" do
      INI.build({"foo" => {"a" => "1"}}, false).should eq("[foo]\na=1\n\n")
    end

    it "builds with no sections" do
      INI.build({"" => {"a" => "1"}}, false).should eq("a=1\n")
    end

    it "builds an empty section before non-empty sections" do
      INI.build({"foo" => {"a" => "1"}, "" => {"b" => "2"}}, false).should eq("b=2\n[foo]\na=1\n\n")
    end
  end
end
