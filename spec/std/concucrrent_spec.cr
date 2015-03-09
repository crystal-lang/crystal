require "spec"

describe "concurrent" do
  it "does three things concurrently" do
    a, b, c = parallel(1 + 2, "hello".length, [1, 2, 3, 4].length)
    a.should eq(3)
    b.should eq(5)
    c.should eq(4)
  end
end
