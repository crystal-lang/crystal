require "spec"

describe TimeFormat do
  context "Patterns" do
    context "%W" do
      it "should print the week number" do
        time_format = TimeFormat.new("%W")

        time_format.format(Time.new(2015,  5, 22)).should eq("21")
        time_format.format(Time.new(2015,  3, 24)).should eq("13")
        time_format.format(Time.new(1989, 10, 26)).should eq("43")
        time_format.format(Time.new(2012,  4, 15)).should eq("16")
        time_format.format(Time.new(2014,  9,  2)).should eq("36")
        time_format.format(Time.new(2000,  1,  1)).should eq("1")
      end
    end
  end
end
