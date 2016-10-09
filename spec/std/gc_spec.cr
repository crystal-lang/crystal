require "spec"

describe "GC" do
  it "stats compiled" do
    GC.stats.collections.should be >= 0
  end
end
