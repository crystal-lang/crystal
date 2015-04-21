require "spec"
require "set"

describe "Set" do
  describe "set" do
    it "is empty" do
      expect(Set(Nil).new.empty?).to be_true
    end

    it "has length 0" do
      expect(Set(Nil).new.length).to eq(0)
    end
  end

  describe "add" do
    it "adds and includes" do
      set = Set(Int32).new
      set.add 1
      expect(set.includes?(1)).to be_true
      expect(set.length).to eq(1)
    end
  end

  describe "delete" do
    it "deletes an object" do
      set = Set{1, 2, 3}
      set.delete 2
      expect(set.length).to eq(2)
      expect(set.includes?(1)).to be_true
      expect(set.includes?(3)).to be_true
    end
  end

  describe "==" do
    it "compares two sets" do
      set1 = Set{1, 2, 3}
      set2 = Set{1, 2, 3}
      set3 = Set{1, 2, 3, 4}

      expect(set1).to eq(set1)
      expect(set1).to eq(set2)
      expect(set1).to_not eq(set3)
    end
  end

  it "does &" do
    set1 = Set{1, 2, 3}
    set2 = Set{4, 2, 5, 3}
    set3 = set1 & set2
    expect(set3).to eq(Set{2, 3})
  end

  it "does |" do
    set1 = Set{1, 2, 3}
    set2 = Set{4, 2, 5, 3}
    set3 = set1 | set2
    expect(set3).to eq(Set{1, 2, 3, 4, 5})
  end

  it "does to_a" do
    expect(Set{1, 2, 3}.to_a).to eq([1, 2, 3])
  end

  it "does to_s" do
    expect(Set{1, 2, 3}.to_s).to eq("Set{1, 2, 3}")
    expect(Set{"foo"}.to_s).to eq(%(Set{"foo"}))
  end

  it "does clear" do
    x = Set{1, 2, 3}
    expect(x.to_a).to eq([1, 2, 3])
    expect(x.clear).to be(x)
    x << 1
    expect(x.to_a).to eq([1])
  end

  it "compares hashes of sets" do
    h1 = { Set{1, 2, 3} => 1 }
    h2 = { Set{1, 2, 3} => 1 }
    expect(h1).to eq(h2)
  end
end
