require "spec"

describe Symbol do
  it "inspects" do
    :foo.inspect.should eq(%(:foo))
    :"{".inspect.should eq(%(:"{"))
    :"hi there".inspect.should eq(%(:"hi there"))
    # :かたな.inspect.should eq(%(:かたな))
  end
end
