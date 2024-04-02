require "spec"

describe "GC" do
  it "compiles GC.stats" do
    typeof(GC.stats).should eq(GC::Stats)
  end

  it "raises if calling enable when not disabled" do
    expect_raises(Exception, "GC is not disabled") do
      GC.enable
    end
  end

  it ".stats" do
    GC.stats.should be_a(GC::Stats)
  end

  it ".prof_stats" do
    GC.prof_stats.should be_a(GC::ProfStats)
  end
end
