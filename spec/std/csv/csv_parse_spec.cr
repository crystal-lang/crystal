require "spec"
require "csv"

describe CSV do
  describe "parse" do
    it "parses empty string" do
      expect(CSV.parse("")).to eq([] of String)
    end

    it "parses one simple row" do
      expect(CSV.parse("hello,world")).to eq([["hello", "world"]])
    end

    it "parses one row with spaces" do
      expect(CSV.parse("   hello   ,   world  ")).to eq([["   hello   ", "   world  "]])
    end

    it "parses two rows" do
      expect(CSV.parse("hello,world\ngood,bye")).to eq([
        ["hello", "world"],
        ["good", "bye"],
        ])
    end

    it "parses two rows with the last one having a newline" do
      expect(CSV.parse("hello,world\ngood,bye\n")).to eq([
        ["hello", "world"],
        ["good", "bye"],
        ])
    end

    it "parses with quote" do
      expect(CSV.parse(%("hello","world"))).to eq([["hello", "world"]])
    end

    it "parses with quote and newline" do
      expect(CSV.parse(%("hello","world"\nfoo))).to eq([["hello", "world"], ["foo"]])
    end

    it "parses with double quote" do
      expect(CSV.parse(%("hel""lo","wor""ld"))).to eq([[%(hel"lo), %(wor"ld)]])
    end

    it "parses some commas" do
      expect(CSV.parse(%(,,))).to eq([["", "", ""]])
    end

    it "parses empty quoted string" do
      expect(CSV.parse(%("",""))).to eq([["", ""]])
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
      expect(CSV.parse(StringIO.new(%("hel""lo",world)))).to eq([[%(hel"lo), %(world)]])
    end
  end

  it "parses row by row" do
    parser = CSV::Parser.new("hello,world\ngood,bye\n")
    expect(parser.next_row).to eq(%w(hello world))
    expect(parser.next_row).to eq(%w(good bye))
    expect(parser.next_row).to be_nil
  end
end
