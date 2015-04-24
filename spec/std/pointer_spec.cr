require "spec"

private def reset(p1, p2)
  p1.value = 10
  p2.value = 20
end

describe "Pointer" do
  it "does malloc with value" do
    p1 = Pointer.malloc(4, 1)
    4.times do |i|
      expect(p1[i]).to eq(1)
    end
  end

  it "does malloc with value from block" do
    p1 = Pointer.malloc(4) { |i| i }
    4.times do |i|
      expect(p1[i]).to eq(i)
    end
  end

  it "does index with count" do
    p1 = Pointer.malloc(4) { |i| i ** 2 }
    expect(p1.to_slice(4).index(4)).to eq(2)
    expect(p1.to_slice(4).index(5)).to be_nil
  end

  describe "copy_from" do
    it "performs" do
      p1 = Pointer.malloc(4) { |i| i }
      p2 = Pointer.malloc(4) { 0 }
      p2.copy_from(p1, 4)
      4.times do |i|
        expect(p2[0]).to eq(p1[0])
      end
    end
  end

  describe "copy_to" do
    it "performs" do
      p1 = Pointer.malloc(4) { |i| i }
      p2 = Pointer.malloc(4) { 0 }
      p1.copy_to(p2, 4)
      4.times do |i|
        expect(p2[0]).to eq(p1[0])
      end
    end
  end

  describe "move_from" do
    it "performs with overlap right to left" do
      p1 = Pointer.malloc(4) { |i| i }
      (p1 + 1).move_from(p1 + 2, 2)
      expect(p1[0]).to eq(0)
      expect(p1[1]).to eq(2)
      expect(p1[2]).to eq(3)
      expect(p1[3]).to eq(3)
    end

    it "performs with overlap left to right" do
      p1 = Pointer.malloc(4) { |i| i }
      (p1 + 2).move_from(p1 + 1, 2)
      expect(p1[0]).to eq(0)
      expect(p1[1]).to eq(1)
      expect(p1[2]).to eq(1)
      expect(p1[3]).to eq(2)
    end
  end

  describe "move_to" do
    it "performs with overlap right to left" do
      p1 = Pointer.malloc(4) { |i| i }
      (p1 + 2).move_to(p1 + 1, 2)
      expect(p1[0]).to eq(0)
      expect(p1[1]).to eq(2)
      expect(p1[2]).to eq(3)
      expect(p1[3]).to eq(3)
    end

    it "performs with overlap left to right" do
      p1 = Pointer.malloc(4) { |i| i }
      (p1 + 1).move_to(p1 + 2, 2)
      expect(p1[0]).to eq(0)
      expect(p1[1]).to eq(1)
      expect(p1[2]).to eq(1)
      expect(p1[3]).to eq(2)
    end
  end

  describe "memcmp" do
    assert do
      p1 = Pointer.malloc(4) { |i| i }
      p2 = Pointer.malloc(4) { |i| i }
      p3 = Pointer.malloc(4) { |i| i + 1 }

      expect(p1.memcmp(p2, 4)).to eq(0)
      expect(p1.memcmp(p3, 4)).to be < 0
      expect(p3.memcmp(p1, 4)).to be > 0
    end
  end

  it "compares two pointers by address" do
    p1 = Pointer(Int32).malloc(1)
    p2 = Pointer(Int32).malloc(1)
    expect(p1).to eq(p1)
    expect(p1).to_not eq(p2)
    expect(p1).to_not eq(1)
  end

  it "does to_s" do
    expect(Pointer(Int32).null.to_s).to eq("Pointer(Int32).null")
    expect(Pointer(Int32).new(1234_u64).to_s).to eq("Pointer(Int32)@0x4D2")
  end

  it "creates from int" do
    expect(Pointer(Int32).new(1234).address).to eq(1234)
  end

  it "shuffles!" do
    a = Pointer(Int32).malloc(3) { |i| i + 1}
    a.shuffle!(3)

    expect((a[0] + a[1] + a[2])).to eq(6)

    3.times do |i|
      expect(a.to_slice(3).includes?(i + 1)).to be_true
    end
  end

  it "maps!" do
    a = Pointer(Int32).malloc(3) { |i| i + 1}
    a.map!(3) { |i| i + 1 }
    expect(a[0]).to eq(2)
    expect(a[1]).to eq(3)
    expect(a[2]).to eq(4)
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
end
