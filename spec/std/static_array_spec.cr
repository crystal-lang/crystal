require "spec"

describe "StaticArray" do
  it "creates with new" do
    a = StaticArray(Int32, 3).new 0
    expect(a.length).to eq(3)
    expect(a.size).to eq(3)
    expect(a.count).to eq(3)
  end

  it "creates with new and value" do
    a = StaticArray(Int32, 3).new 1
    expect(a.length).to eq(3)
    expect(a[0]).to eq(1)
    expect(a[1]).to eq(1)
    expect(a[2]).to eq(1)
  end

  it "creates with new and block" do
    a = StaticArray(Int32, 3).new { |i| i + 1 }
    expect(a.length).to eq(3)
    expect(a[0]).to eq(1)
    expect(a[1]).to eq(2)
    expect(a[2]).to eq(3)
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
    expect(a[-1]).to eq(2)
    expect(a[2]).to eq(2)
  end

  it "does to_s" do
    a = StaticArray(Int32, 3).new { |i| i + 1 }
    expect(a.to_s).to eq("[1, 2, 3]")
  end

  it "shuffles" do
    a = StaticArray(Int32, 3).new { |i| i + 1 }
    a.shuffle!

    expect((a[0] + a[1] + a[2])).to eq(6)

    3.times do |i|
      expect(a.includes?(i + 1)).to be_true
    end
  end

  it "maps!" do
    a = StaticArray(Int32, 3).new { |i| i + 1 }
    a.map! { |i| i + 1 }
    expect(a[0]).to eq(2)
    expect(a[1]).to eq(3)
    expect(a[2]).to eq(4)
  end


  it "updates value" do
    a = StaticArray(Int32, 3).new { |i| i + 1 }
    a.update(1) { |x| x * 2 }
    expect(a[0]).to eq(1)
    expect(a[1]).to eq(4)
    expect(a[2]).to eq(3)
  end
end
