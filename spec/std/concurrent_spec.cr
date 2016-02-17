require "spec"

describe "concurrent" do
  it "does four things concurrently" do
    a, b, c, d = parallel(1 + 2, "hello".size, [1, 2, 3, 4].size, nil)
    a.should eq(3)
    b.should eq(5)
    c.should eq(4)
    d.should be_nil
  end
end
