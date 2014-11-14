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
end
