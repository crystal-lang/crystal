require "spec"
require "compiler/crystal/syntax/location"

describe Crystal::Location do
  it "#inspect" do
    Crystal::Location.new("foo.cr", 1, 1).inspect.should eq ("Location(foo.cr:1:1)")
    Crystal::Location.new("foo.cr", 1, 1, 5).inspect.should eq ("Location(foo.cr:1:1+5)")
  end

  it "#to_s" do
    Crystal::Location.new("foo.cr", 1, 1).to_s.should eq ("foo.cr:1:1")
    Crystal::Location.new("foo.cr", 1, 1, 5).to_s.should eq ("foo.cr:1:1+5")
  end
end
