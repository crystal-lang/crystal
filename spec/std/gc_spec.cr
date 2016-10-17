require "spec"

describe "GC" do
  it "compiles GC.stats" do
    typeof(GC.stats).should eq(GC::Stats)
  end
end
