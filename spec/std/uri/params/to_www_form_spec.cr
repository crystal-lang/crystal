require "spec"
require "uri/params/serializable"

private enum Color
  Red
  Green
  Blue
end

describe "#to_www_form" do
  it Number do
    URI::Params.build do |builder|
      12.to_www_form builder, "value"
    end.should eq "value=12"
  end

  it String do
    URI::Params.build do |builder|
      "12".to_www_form builder, "value"
    end.should eq "value=12"
  end

  it Bool do
    URI::Params.build do |builder|
      false.to_www_form builder, "value"
    end.should eq "value=false"
  end

  describe Array do
    it "of a single type" do
      URI::Params.build do |builder|
        [1, 2, 3].to_www_form builder, "value"
      end.should eq "value=1&value=2&value=3"
    end

    it "of a union of types" do
      URI::Params.build do |builder|
        [1, false, "foo"].to_www_form builder, "value"
      end.should eq "value=1&value=false&value=foo"
    end
  end
end
