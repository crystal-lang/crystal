require "spec"

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

  it "maps!" do
    a = StaticArray(Int32, 3).new { |i| i + 1 }
    a.map! { |i| i + 1 }
    a[0].should eq(2)
    a[1].should eq(3)
    a[2].should eq(4)
  end

  it "map_with_index!" do
    a = StaticArray(Int32, 3).new { |i| i + 1 }
    a.map_with_index! { |e, i| i * 2 }
    a[0].should eq(0)
    a[1].should eq(2)
    a[2].should eq(4)
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

  it "iterates with each" do
    a = StaticArray(Int32, 3).new { |i| i + 1 }
    iter = a.each
    iter.next.should eq(1)
    iter.next.should eq(2)
    iter.next.should eq(3)
    iter.next.should be_a(Iterator::Stop)

    iter.rewind
    iter.next.should eq(1)

    iter.rewind
    iter.cycle.first(5).to_a.should eq([1, 2, 3, 1, 2])
  end

  it "iterates with reverse each" do
    a = StaticArray(Int32, 3).new { |i| i + 1 }
    iter = a.reverse_each
    iter.next.should eq(3)
    iter.next.should eq(2)
    iter.next.should eq(1)
    iter.next.should be_a(Iterator::Stop)

    iter.rewind
    iter.next.should eq(3)

    iter.rewind
    iter.cycle.first(5).to_a.should eq([3, 2, 1, 3, 2])
  end
end
