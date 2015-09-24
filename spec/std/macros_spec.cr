require "spec"

record Record1, a, b

describe "macro" do
  describe "record" do
    it "create record" do
      r = Record1.new 1, 2
      r.a.should eq(1)
      r.b.should eq(2)
    end

    it "create record with defaults" do
      r = Record1.new 1
      r.a.should eq(1)
      r.b.should eq(nil)
    end
  end
end
