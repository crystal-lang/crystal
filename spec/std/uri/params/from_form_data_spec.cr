require "spec"
require "uri/params/serializable"

private enum Color
  Red
  Green
  Blue
end

describe ".from_form_data" do
  describe Bool do
    it "a truthy value" do
      Bool.from_form_data(URI::Params.parse("alive=true"), "alive").should be_true
      Bool.from_form_data(URI::Params.parse("alive=on"), "alive").should be_true
      Bool.from_form_data(URI::Params.parse("alive=yes"), "alive").should be_true
      Bool.from_form_data(URI::Params.parse("alive=1"), "alive").should be_true
    end

    it "a falsey value" do
      Bool.from_form_data(URI::Params.parse("alive=false"), "alive").should be_false
      Bool.from_form_data(URI::Params.parse("alive=off"), "alive").should be_false
      Bool.from_form_data(URI::Params.parse("alive=no"), "alive").should be_false
      Bool.from_form_data(URI::Params.parse("alive=0"), "alive").should be_false
    end

    it "any other value" do
      Bool.from_form_data(URI::Params.parse("alive=foo"), "alive").should be_nil
    end

    it "missing value" do
      Bool.from_form_data(URI::Params.new, "value").should be_nil
    end
  end

  describe String do
    it "valid value" do
      String.from_form_data(URI::Params.parse("name=John Doe"), "name").should eq "John Doe"
    end

    it "missing value" do
      String.from_form_data(URI::Params.new, "value").should be_nil
    end
  end

  describe Enum do
    it "valid value" do
      Color.from_form_data(URI::Params.parse("color=green"), "color").should eq Color::Green
    end

    it "missing value" do
      Color.from_form_data(URI::Params.new, "value").should be_nil
    end
  end

  describe Time do
    it "valid value" do
      Time.from_form_data(URI::Params.parse("time=2016-11-16T09:55:48-03:00"), "time").try &.to_utc.should eq(Time.utc(2016, 11, 16, 12, 55, 48))
      Time.from_form_data(URI::Params.parse("time=2016-11-16T09:55:48-0300"), "time").try &.to_utc.should eq(Time.utc(2016, 11, 16, 12, 55, 48))
      Time.from_form_data(URI::Params.parse("time=20161116T095548-03:00"), "time").try &.to_utc.should eq(Time.utc(2016, 11, 16, 12, 55, 48))
    end

    it "missing value" do
      Time.from_form_data(URI::Params.new, "value").should be_nil
    end
  end

  it Nil do
    Nil.from_form_data(URI::Params.new, "name").should be_nil
    Nil.from_form_data(URI::Params.parse("name=null"), "name").should be_nil
  end

  describe Number do
    describe Int do
      it "valid numbers" do
        Int64.from_form_data(URI::Params.parse("value=123"), "value").should eq 123_i64
        UInt8.from_form_data(URI::Params.parse("value=7"), "value").should eq 7_u8
        Int64.from_form_data(URI::Params.parse("value=-12"), "value").should eq -12_i64
      end

      it "with whitespace" do
        expect_raises ArgumentError do
          Int32.from_form_data(URI::Params.parse("value= 123"), "value")
        end
      end

      it "missing value" do
        Int32.from_form_data(URI::Params.new, "value").should be_nil
        UInt8.from_form_data(URI::Params.new, "value").should be_nil
      end
    end

    describe Float do
      it "valid numbers" do
        Float32.from_form_data(URI::Params.parse("value=123.0"), "value").should eq 123_f32
        Float64.from_form_data(URI::Params.parse("value=123.0"), "value").should eq 123_f64
      end

      it "with whitespace" do
        expect_raises ArgumentError do
          Float64.from_form_data(URI::Params.parse("value= 123.0"), "value")
        end
      end

      it "missing value" do
        Float64.from_form_data(URI::Params.new, "value").should be_nil
      end
    end
  end

  describe Union do
    it "valid" do
      String?.from_form_data(URI::Params.parse("name=John Doe"), "name").should eq "John Doe"
    end

    it "invalid" do
      expect_raises ArgumentError do
        (Int32 | Float64).from_form_data(URI::Params.parse("value=foo"), "value")
      end
    end
  end
end
