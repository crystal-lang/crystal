require "spec"

describe TimeFormat do
  context "Patterns" do
    context "%W" do
      it "should print the week number" do
        time_format = TimeFormat.new("%W")

        time_format.format(Time.new(2015,  5, 22)).should eq("20")
        time_format.format(Time.new(2015,  3, 24)).should eq("12")
        time_format.format(Time.new(1989, 10, 26)).should eq("42")
        time_format.format(Time.new(2012,  4, 15)).should eq("14")
        time_format.format(Time.new(2014,  9,  2)).should eq("35")
        time_format.format(Time.new(1991, 11, 23)).should eq("46")
        time_format.format(Time.new(2000,  1,  1)).should eq("51")
        time_format.format(Time.new(2000, 12, 31)).should eq("51")
        time_format.format(Time.new(2001, 12, 31)).should eq("0")
      end
    end
  end
end
