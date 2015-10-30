require "spec"

describe "concurrent" do
  it "does three things concurrently" do
    a, b, c = parallel(1 + 2, "hello".size, [1, 2, 3, 4].size)
    a.should eq(3)
    b.should eq(5)
    c.should eq(4)
  end
end
