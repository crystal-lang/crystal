require "spec"
require "crystal/unordered_hash"

describe Crystal::UnorderedHash do
  it "#empty?" do
    h = Crystal::UnorderedHash(Int32, Int32).new(16)
    h.empty?.should be_true

    h.put(1, 123)
    h.empty?.should be_false

    h.delete(1) { nil }
    h.empty?.should be_true
  end

  it "#put" do
    h = Crystal::UnorderedHash(Int32, Int32).new(16)

    # empty
    h.size.should eq(0)
    h.fetch(1) { nil }.should be_nil

    # insert
    h.put(1, 123).should eq(123)
    h.size.should eq(1)

    h.put(5, 54).should eq(54)
    h.put(129879, 789).should eq(789)
    h.size.should eq(3)
    h.fetch(5) { nil }.should eq(54)

    # replace key
    h.put(5, 79).should eq(79)
    h.size.should eq(3)
    h.fetch(5) { nil }.should eq(79)
  end

  it "#has_key?" do
    h = Crystal::UnorderedHash(Int32, Int32).new(16)

    # empty
    h.has_key?(1).should be_false
    h.has_key?(5).should be_false

    # not empty
    h.put(1, 54)
    h.has_key?(1).should be_true
    h.has_key?(5).should be_false

    # empty again
    h.delete(1) { nil }
    h.has_key?(1).should be_false
  end

  it "#update" do
    h = Crystal::UnorderedHash(Int32, Int32).new(16)

    # empty
    old_value = -1
    expect_raises(KeyError) { h.update(1) { |x| old_value = x } }
    old_value.should eq(-1)
    h.size.should eq(0)
    h.fetch(1) { nil }.should be_nil

    # existing key
    h.put(1, 456)

    old_value = -1
    h.update(1) { |x| old_value = x; 123 }.should eq(456)
    old_value.should eq(456)
    h.size.should eq(1)
    h.fetch(1) { nil }.should eq(123)

    # unknown key
    expect_raises(KeyError) { h.update(5) { -1 } }
    h.size.should eq(1)
    h.fetch(5) { nil }.should be_nil
  end

  it "#delete" do
    h = Crystal::UnorderedHash(Int32, Int32).new(16)
    h.size.should eq(0)

    # delete unknown key
    h.delete(5) { nil }.should be_nil

    h.put(1, 123)
    h.put(5, 54)
    h.put(129879, 789)

    # delete known key
    h.delete(5) { nil }.should eq(54)

    h.size.should eq(2)
    h.fetch(5) { nil }.should be_nil

    # reinsert (recycle tombstone)
    h.put(5, 88)
    h.size.should eq(3)
    h.fetch(5) { nil }.should eq(88)
  end

  it "#resizes" do
    h = Crystal::UnorderedHash(Int32, Int32).new(8)

    # insert
    2048.times do |i|
      h.put(i, i * 2)
    end
    h.size.should eq(2048)
    h.capacity.should eq(4096)

    # verify
    2048.times do |i|
      h.fetch(i) { nil }.should eq(i * 2)
    end

    # delete half the keys (even ones)
    1024.times do |i|
      j = i * 2
      h.delete(j) { nil }
    end
    h.size.should eq(1024)
    h.capacity.should eq(2048)

    # verify
    1.step(to: 2047, by: 2) do |i|
      h.fetch(i) { nil }.should eq(i * 2)
    end

    # re-insert + replace existing
    2048.times do |i|
      h.put(i, i * 3)
    end

    # verify
    2048.times do |i|
      h.fetch(i) { nil }.should eq(i * 3)
    end

    h.size.should eq(2048)
    h.capacity.should eq(4096)
  end
end
