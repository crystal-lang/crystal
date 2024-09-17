require "spec"
require "uri/params/serializable"

private enum Color
  Red
  Green
  Blue
end

describe ".from_www_form" do
  it Array do
    Array(Int32).from_www_form(URI::Params.new({"values" => ["1", "2"]}), "values").should eq [1, 2]
    Array(Int32).from_www_form(URI::Params.new({"values[]" => ["1", "2"]}), "values").should eq [1, 2]
    Array(String).from_www_form(URI::Params.new({"values" => ["", ""]}), "values").should eq ["", ""]
  end

  describe Bool do
    it "a truthy value" do
      Bool.from_www_form("true").should be_true
      Bool.from_www_form("on").should be_true
      Bool.from_www_form("yes").should be_true
      Bool.from_www_form("1").should be_true
    end

    it "a falsey value" do
      Bool.from_www_form("false").should be_false
      Bool.from_www_form("off").should be_false
      Bool.from_www_form("no").should be_false
      Bool.from_www_form("0").should be_false
    end

    it "any other value" do
      Bool.from_www_form("foo").should be_nil
      Bool.from_www_form("").should be_nil
    end
  end

  describe String do
    it "scalar string" do
      String.from_www_form("John Doe").should eq "John Doe"
    end

    it "with key" do
      String.from_www_form(URI::Params.new({"name" => ["John Doe"]}), "name").should eq "John Doe"
    end

    it "with missing key" do
      String.from_www_form(URI::Params.new({"" => ["John Doe"]}), "name").should be_nil
    end

    it "with alternate casing" do
      String.from_www_form(URI::Params.new({"Name" => ["John Doe"]}), "name").should be_nil
    end

    it "empty value" do
      String.from_www_form(URI::Params.new({"name" => [""]}), "name").should eq ""
    end
  end

  describe Enum do
    it "valid value" do
      Color.from_www_form("green").should eq Color::Green
    end

    it "invalid value" do
      expect_raises ArgumentError do
        Color.from_www_form ""
      end
    end
  end

  describe Time do
    it "valid value" do
      Time.from_www_form("2016-11-16T09:55:48-03:00").to_utc.should eq(Time.utc(2016, 11, 16, 12, 55, 48))
      Time.from_www_form("2016-11-16T09:55:48-0300").to_utc.should eq(Time.utc(2016, 11, 16, 12, 55, 48))
      Time.from_www_form("20161116T095548-03:00").to_utc.should eq(Time.utc(2016, 11, 16, 12, 55, 48))
    end

    it "invalid value" do
      expect_raises Time::Format::Error do
        Time.from_www_form ""
      end
    end
  end

  describe Nil do
    it "valid values" do
      Nil.from_www_form("").should be_nil
    end

    it "invalid value" do
      expect_raises ArgumentError do
        Nil.from_www_form "null"
      end
    end
  end

  describe Number do
    describe Int do
      it "valid numbers" do
        Int64.from_www_form("123").should eq 123_i64
        UInt8.from_www_form("7").should eq 7_u8
        Int64.from_www_form("-12").should eq -12_i64
      end

      it "with whitespace" do
        expect_raises ArgumentError do
          Int32.from_www_form(" 123")
        end
      end

      it "empty value" do
        expect_raises ArgumentError do
          Int16.from_www_form ""
        end
      end
    end

    describe Float do
      it "valid numbers" do
        Float32.from_www_form("123.0").should eq 123_f32
        Float64.from_www_form("123.0").should eq 123_f64
      end

      it "with whitespace" do
        expect_raises ArgumentError do
          Float64.from_www_form(" 123.0")
        end
      end

      it "empty value" do
        expect_raises Exception do
          Float64.from_www_form ""
        end
      end
    end
  end

  describe Union do
    it "valid" do
      String?.from_www_form(URI::Params.parse("name=John Doe"), "name").should eq "John Doe"
      String?.from_www_form(URI::Params.parse("name="), "name").should eq ""
    end

    it "invalid" do
      expect_raises ArgumentError do
        (Int32 | Float64).from_www_form(URI::Params.parse("name=John Doe"), "name")
      end
    end
  end
end
