require "spec"

describe "p" do
  it "can be used with tuples" do
    typeof(p!({1, 2}))
    typeof(p!({1, 2}, {3, 4}))
  end
end

describe "pp" do
  it "can be used with tuples" do
    typeof(pp!({1, 2}))
    typeof(pp!({1, 2}, {3, 4}))
  end
end
