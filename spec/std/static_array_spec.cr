require "spec"
require "spec/helpers/iterate"

describe "StaticArray" do
  it "creates with new" do
    a = StaticArray(Int32, 3).new 0
    a.size.should eq(3)
  end

  it "creates with new and value" do
    a = StaticArray(Int32, 3).new 1
    a.size.should eq(3)
    a[0].should eq(1)
    a[1].should eq(1)
    a[2].should eq(1)
  end

  it "creates with new and block" do
    a = StaticArray(Int32, 3).new { |i| i + 1 }
    a.size.should eq(3)
    a[0].should eq(1)
    a[1].should eq(2)
    a[2].should eq(3)
  end

  it "raises index out of bounds on read" do
    a = StaticArray(Int32, 3).new 0
    expect_raises IndexError do
      a[4]
    end
  end

  it "raises index out of bounds on write" do
    a = StaticArray(Int32, 3).new 0
    expect_raises IndexError do
      a[4] = 1
    end
  end

  it "allows using negative indices" do
    a = StaticArray(Int32, 3).new 0
    a[-1] = 2
    a[-1].should eq(2)
    a[2].should eq(2)
  end

  describe "==" do
    it "compares empty" do
      (StaticArray(Int32, 0).new(0)).should eq(StaticArray(Int32, 0).new(0))
      (StaticArray(Int32, 1).new(0)).should_not eq(StaticArray(Int32, 0).new(0))
      (StaticArray(Int32, 0).new(0)).should_not eq(StaticArray(Int32, 1).new(0))
    end

    it "compares elements" do
      a = StaticArray(Int32, 3).new { |i| i * 2 }
      a.should eq(StaticArray(Int32, 3).new { |i| i * 2 })
      a.should_not eq(StaticArray(Int32, 3).new { |i| i * 3 })
    end

    it "compares other" do
      (StaticArray(Int32, 0).new(0)).should_not eq(nil)
      (StaticArray(Int32, 3).new(0)).should eq(StaticArray(Int8, 3).new(0_i8))
    end
  end

  describe "values_at" do
    it "returns the given indexes" do
      StaticArray(Int32, 4).new { |i| i + 1 }.values_at(1, 0, 2).should eq({2, 1, 3})
    end

    it "raises when passed an invalid index" do
      expect_raises IndexError do
        StaticArray(Int32, 1).new { |i| i + 1 }.values_at(10)
      end
    end
  end

  it "does to_s" do
    a = StaticArray(Int32, 3).new { |i| i + 1 }
    a.to_s.should eq("StaticArray[1, 2, 3]")
  end

  it "does #fill, without block" do
    a = StaticArray(Int32, 3).new { |i| i + 1 }
    a.fill(0).should eq(StaticArray[0, 0, 0])
    a.should eq(StaticArray[0, 0, 0])
    a.fill(2).should eq(StaticArray[2, 2, 2])
    a.should eq(StaticArray[2, 2, 2])
  end

  it "does #fill, with block" do
    a = StaticArray(Int32, 4).new { |i| i + 1 }
    a.fill { |i| i * i }.should eq(StaticArray[0, 1, 4, 9])
    a.should eq(StaticArray[0, 1, 4, 9])
  end

  it "shuffles" do
    a = StaticArray(Int32, 3).new { |i| i + 1 }
    a.shuffle!

    (a[0] + a[1] + a[2]).should eq(6)

    3.times do |i|
      a.includes?(i + 1).should be_true
    end
  end

  it "shuffles with a seed" do
    a = StaticArray(Int32, 10).new { |i| i + 1 }
    b = StaticArray(Int32, 10).new { |i| i + 1 }
    a.shuffle!(Random.new(42))
    b.shuffle!(Random.new(42))

    10.times do |i|
      a[i].should eq(b[i])
    end
  end

  it "reverse" do
    a = StaticArray(Int32, 3).new { |i| i + 1 }
    a.reverse!
    a[0].should eq(3)
    a[1].should eq(2)
    a[2].should eq(1)
  end

  it "does map" do
    a = StaticArray[0, 1, 2]
    b = a.map { |e| e * 2 }
    b.should eq(StaticArray[0, 2, 4])
  end

  it "does map!" do
    a = StaticArray(Int32, 3).new { |i| i + 1 }
    a.map! { |i| i + 1 }
    a[0].should eq(2)
    a[1].should eq(3)
    a[2].should eq(4)
  end

  it "does map_with_index" do
    a = StaticArray[1, 1, 2, 2]
    b = a.map_with_index { |e, i| e + i }
    b.should eq(StaticArray[1, 2, 4, 5])
  end

  it "does map_with_index, with offset" do
    a = StaticArray[1, 1, 2, 2]
    b = a.map_with_index(10) { |e, i| e + i }
    b.should eq(StaticArray[11, 12, 14, 15])
  end

  it "does map_with_index!" do
    a = StaticArray(Int32, 3).new { |i| i + 1 }
    a.map_with_index! { |e, i| i * 2 }
    a[0].should eq(0)
    a[1].should eq(2)
    a[2].should eq(4)
    a.should be_a(StaticArray(Int32, 3))
  end

  it "does map_with_index!, with offset" do
    a = StaticArray(Int32, 3).new { |i| i + 1 }
    a.map_with_index!(10) { |e, i| i * 2 }
    a[0].should eq(20)
    a[1].should eq(22)
    a[2].should eq(24)
    a.should be_a(StaticArray(Int32, 3))
  end

  it "updates value" do
    a = StaticArray(Int32, 3).new { |i| i + 1 }
    a.update(1) { |x| x * 2 }
    a[0].should eq(1)
    a[1].should eq(4)
    a[2].should eq(3)
  end

  it "clones" do
    a = StaticArray(Array(Int32), 1).new { |i| [1] }
    b = a.clone
    b[0].should eq(a[0])
    b[0].should_not be(a[0])
  end

  it_iterates "#each", [1, 2, 3], StaticArray[1, 2, 3].each
  it_iterates "#reverse_each", [3, 2, 1], StaticArray[1, 2, 3].reverse_each
  it_iterates "#each_index", [0, 1, 2], StaticArray[1, 2, 3].each_index
end
