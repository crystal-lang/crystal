require "spec"
require "csv"

describe CSV do
  describe "build" do
    it "builds two rows" do
      string = CSV.build do |csv|
        csv.row do |row|
          row << "one"
          row << "two"
        end
        csv.row do |row|
          row << "three"
          row << "four"
        end
      end
      string.should eq("one,two\nthree,four\n")
    end

    it "builds with numbers" do
      string = CSV.build do |csv|
        csv.row do |row|
          row << 1
          row << 2
        end
        csv.row do |row|
          row << 3
          row << 4
        end
      end
      string.should eq("1,2\n3,4\n")
    end

    it "builds with commas" do
      string = CSV.build do |csv|
        csv.row do |row|
          row << %(hello,world)
        end
      end
      string.should eq(%("hello,world"\n))
    end

    it "builds with quotes" do
      string = CSV.build do |csv|
        csv.row do |row|
          row << %(he said "no")
        end
      end
      string.should eq(%("he said ""no"""\n))
    end

    it "builds row from enumerable" do
      string = CSV.build do |csv|
        csv.row [1, 2, 3]
      end
      string.should eq("1,2,3\n")
    end

    it "builds row from splat" do
      string = CSV.build do |csv|
        csv.row 1, 2, 3
      end
      string.should eq("1,2,3\n")
    end

    it "skips inside row" do
      string = CSV.build do |csv|
        csv.row do |row|
          row << 1
          row.skip_cell
          row << 2
        end
      end
      string.should eq("1,,2\n")
    end

    it "appends enumerable to row" do
      string = CSV.build do |csv|
        csv.row do |row|
          row << 1
          row.append [2, 3, 4]
          row << 5
        end
      end
      string.should eq("1,2,3,4,5\n")
    end

    it "appends splat to row" do
      string = CSV.build do |csv|
        csv.row do |row|
          row << 1
          row.append 2, 3, 4
          row << 5
        end
      end
      string.should eq("1,2,3,4,5\n")
    end
  end

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
      expect_raises CSV::MalformedCSVError, "expecting comma, newline or end, not 'a' at 1:6" do
        CSV.parse(%("hel"a))
      end
    end
  end
end
