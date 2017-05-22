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
      expect_raises CSV::MalformedCSVError, "Unexpected quote at 1:4" do
        CSV.parse(%(hel"lo))
      end
    end

    it "raises if command, newline or end doesn't follow quote" do
      expect_raises CSV::MalformedCSVError, "Expecting comma, newline or end, not 'a' at 2:6" do
        CSV.parse(%(foo\n"hel"a))
      end
    end

    it "raises if command, newline or end doesn't follow quote (2)" do
      expect_raises CSV::MalformedCSVError, "Expecting comma, newline or end, not 'a' at 2:6" do
        CSV.parse(%(\n"hel"a))
      end
    end

    it "parses from IO" do
      CSV.parse(IO::Memory.new(%("hel""lo",world))).should eq([[%(hel"lo), %(world)]])
    end

    it "takes an optional separator argument" do
      CSV.parse("foo;bar", separator: ';').should eq([["foo", "bar"]])
    end

    it "takes an optional quote char argument" do
      CSV.parse("'foo,bar'", quote_char: '\'').should eq([["foo,bar"]])
    end
  end

  it "parses row by row" do
    parser = CSV::Parser.new("hello,world\ngood,bye\n")
    parser.next_row.should eq(%w(hello world))
    parser.next_row.should eq(%w(good bye))
    parser.next_row.should be_nil
  end

  it "does CSV.each_row" do
    sum = 0
    CSV.each_row("1,2\n3,4\n") do |row|
      sum += row.map(&.to_i).sum
    end.should be_nil
    sum.should eq(10)
  end

  it "does CSV.each_row with separator and quotes" do
    sum = 0
    CSV.each_row("1\t'2'\n3\t4\n", '\t', '\'') do |row|
      sum += row.map(&.to_i).sum
    end.should be_nil
    sum.should eq(10)
  end

  it "gets row iterator" do
    iter = CSV.each_row("1,2\n3,4\n")
    iter.next.should eq(["1", "2"])
    iter.next.should eq(["3", "4"])
    iter.next.should be_a(Iterator::Stop)

    iter.rewind
    iter.next.should eq(["1", "2"])
  end
end
