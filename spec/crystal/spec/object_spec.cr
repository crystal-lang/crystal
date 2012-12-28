describe "Object" do
  it "compares object to other objects" do
    o1 = Object.new
    o2 = Object.new
    o1.should eq(o1)
    o1.should_not eq(o2)
    o1.should_not eq(1)
  end
end
