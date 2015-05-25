require "spec"

describe "StaticArray" do
  it "creates with new" do
    a = StaticArray(Int32, 3).new 0
    a.length.should eq(3)
    a.size.should eq(3)
    a.count.should eq(3)
  end

  it "creates with new and value" do
    a = StaticArray(Int32, 3).new 1
    a.length.should eq(3)
    a[0].should eq(1)
    a[1].should eq(1)
    a[2].should eq(1)
  end

  it "creates with new and block" do
    a = StaticArray(Int32, 3).new { |i| i + 1 }
    a.length.should eq(3)
    a[0].should eq(1)
    a[1].should eq(2)
    a[2].should eq(3)
  end

  it "raises index out of bounds on read" do
    a = StaticArray(Int32, 3).new 0
    expect_raises IndexOutOfBounds do
      a[4]
    end
  end

  it "raises index out of bounds on write" do
    a = StaticArray(Int32, 3).new 0
    expect_raises IndexOutOfBounds do
      a[4] = 1
    end
  end

  it "allows using negative indices" do
    a = StaticArray(Int32, 3).new 0
    a[-1] = 2
    a[-1].should eq(2)
    a[2].should eq(2)
  end

  describe "values_at" do
    it "returns the given indexes" do
      StaticArray(Int32, 4).new { |i| i + 1 }.values_at(1, 0, 2).should eq({2, 1, 3})
    end

    it "raises when passed an invalid index" do
      expect_raises IndexOutOfBounds do
        StaticArray(Int32, 1).new { |i| i + 1 }.values_at(10)
      end
    end
  end

  it "does to_s" do
    a = StaticArray(Int32, 3).new { |i| i + 1 }
    a.to_s.should eq("[1, 2, 3]")
  end

  it "shuffles" do
    a = StaticArray(Int32, 3).new { |i| i + 1 }
    a.shuffle!

    (a[0] + a[1] + a[2]).should eq(6)

    3.times do |i|
      a.includes?(i + 1).should be_true
    end
  end

  it "maps!" do
    a = StaticArray(Int32, 3).new { |i| i + 1 }
    a.map! { |i| i + 1 }
    a[0].should eq(2)
    a[1].should eq(3)
    a[2].should eq(4)
  end


  it "updates value" do
    a = StaticArray(Int32, 3).new { |i| i + 1 }
    a.update(1) { |x| x * 2 }
    a[0].should eq(1)
    a[1].should eq(4)
    a[2].should eq(3)
  end
end
