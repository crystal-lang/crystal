require "spec"
require "uri/params/serializable"

private enum Color
  Red
  Green
  Blue
end

describe ".from_form_data" do
  it Array do
    Array(Int32).from_form_data(URI::Params.new({"values" => ["1", "2"]}), "values").should eq [1, 2]
    Array(Int32).from_form_data(URI::Params.new({"values[]" => ["1", "2"]}), "values").should eq [1, 2]
  end

  describe Bool do
    it "a truthy value" do
      Bool.from_form_data("true").should be_true
      Bool.from_form_data("on").should be_true
      Bool.from_form_data("yes").should be_true
      Bool.from_form_data("1").should be_true
    end

    it "a falsey value" do
      Bool.from_form_data("false").should be_false
      Bool.from_form_data("off").should be_false
      Bool.from_form_data("no").should be_false
      Bool.from_form_data("0").should be_false
    end

    it "any other value" do
      Bool.from_form_data("foo").should be_nil
    end
  end

  it String do
    String.from_form_data("John Doe").should eq "John Doe"
  end

  it Enum do
    Color.from_form_data("green").should eq Color::Green
  end

  it Time do
    Time.from_form_data("2016-11-16T09:55:48-03:00").to_utc.should eq(Time.utc(2016, 11, 16, 12, 55, 48))
    Time.from_form_data("2016-11-16T09:55:48-0300").to_utc.should eq(Time.utc(2016, 11, 16, 12, 55, 48))
    Time.from_form_data("20161116T095548-03:00").to_utc.should eq(Time.utc(2016, 11, 16, 12, 55, 48))
  end

  it Nil do
    Nil.from_form_data("").should be_nil
    Nil.from_form_data("null").should be_nil
  end

  describe Number do
    describe Int do
      it "valid numbers" do
        Int64.from_form_data("123").should eq 123_i64
        UInt8.from_form_data("7").should eq 7_u8
        Int64.from_form_data("-12").should eq -12_i64
      end

      it "with whitespace" do
        expect_raises ArgumentError do
          Int32.from_form_data(" 123")
        end
      end
    end

    describe Float do
      it "valid numbers" do
        Float32.from_form_data("123.0").should eq 123_f32
        Float64.from_form_data("123.0").should eq 123_f64
      end

      it "with whitespace" do
        expect_raises ArgumentError do
          Float64.from_form_data(" 123.0")
        end
      end
    end
  end

  describe Union do
    it "valid" do
      String?.from_form_data("John Doe").should eq "John Doe"
    end

    it "invalid" do
      expect_raises ArgumentError do
        (Int32 | Float64).from_form_data("foo")
      end
    end
  end
end
