require "spec"
require "csv"
require "spec/helpers/string"

describe CSV do
  describe "build" do
    it "builds two rows" do
      assert_prints(CSV.build do |csv|
        csv.row do |row|
          row << "one"
          row << "two"
        end
        csv.row do |row|
          row << "three"
          row << "four"
        end
      end, "one,two\nthree,four\n")
    end

    it "builds with numbers" do
      assert_prints(CSV.build do |csv|
        csv.row do |row|
          row << 1
          row << 2
        end
        csv.row do |row|
          row << 3
          row << 4
        end
      end, "1,2\n3,4\n")
    end

    it "builds with commas" do
      assert_prints(CSV.build do |csv|
        csv.row do |row|
          row << %(hello,world)
        end
      end, %("hello,world"\n))
    end

    it "builds with custom separator" do
      assert_prints(CSV.build(separator: ';') do |csv|
        csv.row do |row|
          row << "one"
          row << "two"
          row << "thr;ee"
        end
      end, %(one;two;"thr;ee"\n))
    end

    it "builds with quotes" do
      assert_prints(CSV.build do |csv|
        csv.row do |row|
          row << %(he said "no")
        end
      end, %("he said ""no"""\n))
    end

    it "builds with custom quote character" do
      assert_prints(CSV.build(quote_char: '\'') do |csv|
        csv.row do |row|
          row << %(he said 'no')
        end
      end, %('he said ''no'''\n))
    end

    it "builds row from enumerable" do
      assert_prints(CSV.build do |csv|
        csv.row [1, 2, 3]
      end, "1,2,3\n")
    end

    it "builds row from splat" do
      assert_prints(CSV.build do |csv|
        csv.row 1, 2, 3
      end, "1,2,3\n")
    end

    it "skips inside row" do
      assert_prints(CSV.build do |csv|
        csv.row do |row|
          row << 1
          row.skip_cell
          row << 2
        end
      end, "1,,2\n")
    end

    it "concats enumerable to row" do
      assert_prints(CSV.build do |csv|
        csv.row do |row|
          row << 1
          row.concat [2, 3, 4]
          row << 5
        end
      end, "1,2,3,4,5\n")
    end

    it "concats splat to row" do
      assert_prints(CSV.build do |csv|
        csv.row do |row|
          row << 1
          row.concat 2, 3, 4
          row << 5
        end
      end, "1,2,3,4,5\n")
    end

    it "builds with commas" do
      assert_prints(CSV.build do |csv|
        csv.row do |row|
          row << " , "
          row << " , "
        end
      end, %(" , "," , "\n))
    end

    it "builds with quoting" do
      assert_prints(CSV.build(quoting: CSV::Builder::Quoting::NONE) do |csv|
        csv.row 1, "doesn't", " , ", %(he said "no")
      end, %(1,doesn't, , ,he said "no"\n))

      assert_prints(CSV.build(quoting: CSV::Builder::Quoting::RFC) do |csv|
        csv.row 1, "doesn't", " , ", %(he said "no")
      end, %(1,doesn't," , ","he said ""no"""\n))

      assert_prints(CSV.build(quoting: CSV::Builder::Quoting::ALL) do |csv|
        csv.row 1, "doesn't", " , ", %(he said "no")
      end, %("1","doesn't"," , ","he said ""no"""\n))
    end

    it "builds with inside quoted chars and symbols" do
      assert_prints(CSV.build(quoting: CSV::Builder::Quoting::NONE) do |csv|
        csv.row 'c', '\'', '"', :sym, :"s'm", :"s\"m"
      end, %(c,',",sym,s'm,s"m\n))

      assert_prints(CSV.build(quoting: CSV::Builder::Quoting::RFC) do |csv|
        csv.row 'c', '\'', '"', :sym, :"s'm", :"s\"m"
      end, %(c,',"""",sym,s'm,"s""m"\n))

      assert_prints(CSV.build(quoting: CSV::Builder::Quoting::ALL) do |csv|
        csv.row 'c', '\'', '"', :sym, :"s'm", :"s\"m"
      end, %("c","'","""","sym","s'm","s""m"\n))
    end
  end
end
