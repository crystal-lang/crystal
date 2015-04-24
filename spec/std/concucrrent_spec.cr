require "spec"

describe "concurrent" do
  it "does three things concurrently" do
    a, b, c = parallel(1 + 2, "hello".length, [1, 2, 3, 4].length)
    expect(a).to eq(3)
    expect(b).to eq(5)
    expect(c).to eq(4)
  end
end
