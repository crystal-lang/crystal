require "spec"
require "csv"

describe CSV do
  describe "parse" do
    it "parses empty string" do
      CSV.parse("").should eq([] of String)
    end

    it "parses one simple row" do
      CSV.parse("hello,world").should eq([["hello", "world"]])
    end

    it "parses one row with spaces" do
      CSV.parse("   hello   ,   world  ").should eq([["   hello   ", "   world  "]])
    end

    it "parses two rows" do
      CSV.parse("hello,world\ngood,bye").should eq([
        ["hello", "world"],
        ["good", "bye"],
        ])
    end

    it "parses two rows with the last one having a newline" do
      CSV.parse("hello,world\ngood,bye\n").should eq([
        ["hello", "world"],
        ["good", "bye"],
        ])
    end

    it "parses with quote" do
      CSV.parse(%("hello","world")).should eq([["hello", "world"]])
    end

    it "parses with quote and newline" do
      CSV.parse(%("hello","world"\nfoo)).should eq([["hello", "world"], ["foo"]])
    end

    it "parses with double quote" do
      CSV.parse(%("hel""lo","wor""ld")).should eq([[%(hel"lo), %(wor"ld)]])
    end

    it "parses some commas" do
      CSV.parse(%(,,)).should eq([["", "", ""]])
    end

    it "parses empty quoted string" do
      CSV.parse(%("","")).should eq([["", ""]])
    end

    it "raises if single quote in the middle" do
      expect_raises CSV::MalformedCSVError, "unexpected quote at 1:4" do
        CSV.parse(%(hel"lo))
      end
    end

    it "raises if command, newline or end doesn't follow quote" do
      expect_raises CSV::MalformedCSVError, "expecting comma, newline or end, not 'a' at 2:6" do
        CSV.parse(%(foo\n"hel"a))
      end
    end

    it "raises if command, newline or end doesn't follow quote (2)" do
      expect_raises CSV::MalformedCSVError, "expecting comma, newline or end, not 'a' at 2:6" do
        CSV.parse(%(\n"hel"a))
      end
    end

    it "parses from IO" do
      CSV.parse(StringIO.new(%("hel""lo",world))).should eq([[%(hel"lo), %(world)]])
    end
  end
end
