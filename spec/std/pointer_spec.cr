require "spec"

private def reset(p1, p2)
  p1.value = 10
  p2.value = 20
end

describe "Pointer" do
  it "does malloc with value" do
    p1 = Pointer.malloc(4, 1)
    4.times do |i|
      p1[i].should eq(1)
    end
  end

  it "does malloc with value from block" do
    p1 = Pointer.malloc(4) { |i| i }
    4.times do |i|
      p1[i].should eq(i)
    end
  end

  it "does index with count" do
    p1 = Pointer.malloc(4) { |i| i ** 2 }
    p1.to_slice(4).index(4).should eq(2)
    p1.to_slice(4).index(5).should be_nil
  end

  describe "copy_from" do
    it "performs" do
      p1 = Pointer.malloc(4) { |i| i }
      p2 = Pointer.malloc(4) { 0 }
      p2.copy_from(p1, 4)
      4.times do |i|
        p2[i].should eq(p1[i])
      end
    end

    it "raises on negative count" do
      p1 = Pointer.malloc(4, 0)
      expect_raises(ArgumentError, "Negative count") do
        p1.copy_from(p1, -1)
      end
    end

    it "copies from union of pointers" do
      p1 = Pointer.malloc(4, 1)
      p2 = Pointer.malloc(4, 1.5)
      p3 = Pointer.malloc(4, 0 || 0.0)
      p3.copy_from(p1 || p2, 4)
      4.times { |i| p3[i].should eq(p1[i]) }
    end
  end

  describe "realloc" do
    it "raises on negative count" do
      p1 = Pointer(Int32).new(123)
      expect_raises(ArgumentError) do
        p1.realloc(-1)
      end
    end
  end

  describe "copy_to" do
    it "performs" do
      p1 = Pointer.malloc(4) { |i| i }
      p2 = Pointer.malloc(4) { 0 }
      p1.copy_to(p2, 4)
      4.times do |i|
        p2[i].should eq(p1[i])
      end
    end

    it "raises on negative count" do
      p1 = Pointer.malloc(4, 0)
      expect_raises(ArgumentError, "Negative count") do
        p1.copy_to(p1, -1)
      end
    end

    it "copies to union of pointers" do
      p1 = Pointer.malloc(4, 1)
      p2 = Pointer.malloc(4, 0 || 1.5)
      p3 = Pointer.malloc(4, 0 || 'a')
      p1.copy_to(p2 || p3, 4)
      4.times { |i| p2[i].should eq(p1[i]) }
    end
  end

  describe "move_from" do
    it "performs with overlap right to left" do
      p1 = Pointer.malloc(4) { |i| i }
      (p1 + 1).move_from(p1 + 2, 2)
      p1[0].should eq(0)
      p1[1].should eq(2)
      p1[2].should eq(3)
      p1[3].should eq(3)
    end

    it "performs with overlap left to right" do
      p1 = Pointer.malloc(4) { |i| i }
      (p1 + 2).move_from(p1 + 1, 2)
      p1[0].should eq(0)
      p1[1].should eq(1)
      p1[2].should eq(1)
      p1[3].should eq(2)
    end

    it "raises on negative count" do
      p1 = Pointer.malloc(4, 0)
      expect_raises(ArgumentError, "Negative count") do
        p1.move_from(p1, -1)
      end
    end

    it "moves from union of pointers" do
      p1 = Pointer.malloc(4, 1)
      p2 = Pointer.malloc(4, 1.5)
      p3 = Pointer.malloc(4, 0 || 0.0)
      p3.move_from(p1 || p2, 4)
      4.times { |i| p3[i].should eq(p1[i]) }
    end
  end

  describe "move_to" do
    it "performs with overlap right to left" do
      p1 = Pointer.malloc(4) { |i| i }
      (p1 + 2).move_to(p1 + 1, 2)
      p1[0].should eq(0)
      p1[1].should eq(2)
      p1[2].should eq(3)
      p1[3].should eq(3)
    end

    it "performs with overlap left to right" do
      p1 = Pointer.malloc(4) { |i| i }
      (p1 + 1).move_to(p1 + 2, 2)
      p1[0].should eq(0)
      p1[1].should eq(1)
      p1[2].should eq(1)
      p1[3].should eq(2)
    end

    it "raises on negative count" do
      p1 = Pointer.malloc(4, 0)
      expect_raises(ArgumentError, "Negative count") do
        p1.move_to(p1, -1)
      end
    end

    it "moves to union of pointers" do
      p1 = Pointer.malloc(4, 1)
      p2 = Pointer.malloc(4, 0 || 1.5)
      p3 = Pointer.malloc(4, 0 || 'a')
      p1.move_to(p2 || p3, 4)
      4.times { |i| p2[i].should eq(p1[i]) }
    end
  end

  describe "memcmp" do
    it do
      p1 = Pointer.malloc(4) { |i| i }
      p2 = Pointer.malloc(4) { |i| i }
      p3 = Pointer.malloc(4) { |i| i + 1 }

      p1.memcmp(p2, 4).should eq(0)
      p1.memcmp(p3, 4).should be < 0
      p3.memcmp(p1, 4).should be > 0
    end
  end

  it "compares two pointers by address" do
    p1 = Pointer(Int32).malloc(1)
    p2 = Pointer(Int32).malloc(1)
    p1.should eq(p1)
    p1.should_not eq(p2)
    p1.should_not eq(1)
  end

  it "does to_s" do
    Pointer(Int32).null.to_s.should eq("Pointer(Int32).null")
    Pointer(Int32).new(1234_u64).to_s.should eq("Pointer(Int32)@0x4d2")
  end

  it "creates from int" do
    Pointer(Int32).new(1234).address.should eq(1234)
  end

  it "shuffles!" do
    a = Pointer(Int32).malloc(3) { |i| i + 1 }
    a.shuffle!(3)

    (a[0] + a[1] + a[2]).should eq(6)

    3.times do |i|
      a.to_slice(3).includes?(i + 1).should be_true
    end
  end

  it "maps!" do
    a = Pointer(Int32).malloc(3) { |i| i + 1 }
    a.map!(3) { |i| i + 1 }
    a[0].should eq(2)
    a[1].should eq(3)
    a[2].should eq(4)
  end

  it "maps_with_index!" do
    a = Pointer(Int32).malloc(3) { |i| i + 1 }
    a.map_with_index!(3) { |e, i| e + i }
    a[0].should eq(1)
    a[1].should eq(3)
    a[2].should eq(5)
  end

  it "raises if mallocs negative size" do
    expect_raises(ArgumentError) { Pointer.malloc(-1, 0) }
  end

  it "copies/move with different types" do
    p1 = Pointer(Int32).malloc(1)
    p2 = Pointer(Int32 | String).malloc(1)

    reset p1, p2
    p1.copy_from(p1, 1)
    p1.value.should eq(10)

    # p1.copy_from(p2, 10) # invalid

    reset p1, p2
    p2.copy_from(p1, 1)
    p2.value.should eq(10)

    reset p1, p2
    p2.copy_from(p2, 1)
    p2.value.should eq(20)

    reset p1, p2
    p1.move_from(p1, 1)
    p1.value.should eq(10)

    # p1.move_from(p2, 10) # invalid

    reset p1, p2
    p2.move_from(p1, 1)
    p2.value.should eq(10)

    reset p1, p2
    p2.move_from(p2, 1)
    p2.value.should eq(20)

    # ---

    reset p1, p2
    p1.copy_to(p1, 1)
    p1.value.should eq(10)

    reset p1, p2
    p1.copy_to(p2, 1)
    p2.value.should eq(10)

    # p2.copy_to(p1, 10) # invalid

    reset p1, p2
    p2.copy_to(p2, 1)
    p2.value.should eq(20)

    reset p1, p2
    p1.move_to(p1, 1)
    p1.value.should eq(10)

    reset p1, p2
    p1.move_to(p2, 1)
    p2.value.should eq(10)

    # p2.move_to(p1, 10) # invalid

    reset p1, p2
    p2.move_to(p2, 1)
    p2.value.should eq(20)
  end

  describe "clear" do
    it "clears one" do
      ptr = Pointer(Int32).malloc(2)
      ptr[0] = 10
      ptr[1] = 20
      ptr.clear
      ptr[0].should eq(0)
      ptr[1].should eq(20)
    end

    it "clears many" do
      ptr = Pointer(Int32).malloc(4)
      ptr[0] = 10
      ptr[1] = 20
      ptr[2] = 30
      ptr[3] = 40
      ptr.clear(2)
      ptr[0].should eq(0)
      ptr[1].should eq(0)
      ptr[2].should eq(30)
      ptr[3].should eq(40)
    end

    it "clears with union" do
      ptr = Pointer(Int32 | Nil).malloc(4)
      ptr[0] = 10
      ptr[1] = 20
      ptr[2] = 30
      ptr[3] = 0
      ptr.clear(2)
      ptr[0].should be_nil
      ptr[1].should be_nil
      ptr[2].should eq(30)
      ptr[3].should eq(0)
      ptr[3].should_not be_nil
    end
  end

  it "does !" do
    (!Pointer(Int32).null).should be_true
    (!Pointer(Int32).new(123)).should be_false
  end

  it "clones" do
    ptr = Pointer(Int32).new(123)
    ptr.clone.should eq(ptr)
  end

  {% if flag?(:bits32) %}
    it "raises on copy_from with size bigger than UInt32::MAX" do
      ptr = Pointer(Int32).new(123)

      expect_raises(ArgumentError) do
        ptr.copy_from(ptr, UInt32::MAX.to_u64 + 1)
      end
    end

    it "raises on move_from with size bigger than UInt32::MAX" do
      ptr = Pointer(Int32).new(123)

      expect_raises(ArgumentError) do
        ptr.move_from(ptr, UInt32::MAX.to_u64 + 1)
      end
    end

    it "raises on clear with size bigger than UInt32::MAX" do
      ptr = Pointer(Int32).new(123)

      expect_raises(ArgumentError) do
        ptr.clear(UInt32::MAX.to_u64 + 1)
      end
    end
  {% end %}
end
