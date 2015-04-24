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
      expect(string).to eq("one,two\nthree,four\n")
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
      expect(string).to eq("1,2\n3,4\n")
    end

    it "builds with commas" do
      string = CSV.build do |csv|
        csv.row do |row|
          row << %(hello,world)
        end
      end
      expect(string).to eq(%("hello,world"\n))
    end

    it "builds with quotes" do
      string = CSV.build do |csv|
        csv.row do |row|
          row << %(he said "no")
        end
      end
      expect(string).to eq(%("he said ""no"""\n))
    end

    it "builds row from enumerable" do
      string = CSV.build do |csv|
        csv.row [1, 2, 3]
      end
      expect(string).to eq("1,2,3\n")
    end

    it "builds row from splat" do
      string = CSV.build do |csv|
        csv.row 1, 2, 3
      end
      expect(string).to eq("1,2,3\n")
    end

    it "skips inside row" do
      string = CSV.build do |csv|
        csv.row do |row|
          row << 1
          row.skip_cell
          row << 2
        end
      end
      expect(string).to eq("1,,2\n")
    end

    it "concats enumerable to row" do
      string = CSV.build do |csv|
        csv.row do |row|
          row << 1
          row.concat [2, 3, 4]
          row << 5
        end
      end
      expect(string).to eq("1,2,3,4,5\n")
    end

    it "concats splat to row" do
      string = CSV.build do |csv|
        csv.row do |row|
          row << 1
          row.concat 2, 3, 4
          row << 5
        end
      end
      expect(string).to eq("1,2,3,4,5\n")
    end
  end
end
