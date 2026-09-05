require "spec"
require "sync/map"
require "wait_group"

describe Sync::Map do
  it "#put" do
    map = Sync::Map(Int32, Int32).new(16, 4)
    map.size.should eq(0)

    # insert
    (map[1] = 123).should eq(123)
    map.size.should eq(1)

    (map[5] = 54).should eq(54)
    (map[129879] = 789).should eq(789)
    map.size.should eq(3)
    map[5].should eq(54)

    # replace key
    (map[5] = 79).should eq(79)
    map.size.should eq(3)
    map[5].should eq(79)
  end

  it "#update" do
    map = Sync::Map(Int32, Int32).new(16, 4)
    expect_raises(KeyError) { map.update(1) { |v| v * 2 } }

    map[1] = 3
    map.update(1) { |v| v * 2 }.should eq(3)
    map[1].should eq(6)
  end

  it "#put_if_absent" do
    map = Sync::Map(Int32, Int32).new(16, 4)

    map.put_if_absent(1, 64).should eq(64)
    map.size.should eq(1)

    5.times do |i|
      map.put_if_absent(1, i).should eq(64)
      map.size.should eq(1)
    end

    map.put_if_absent(2, 256).should eq(256)
    map.size.should eq(2)

    map[1].should eq(64)
    map[2].should eq(256)
  end

  it "#fetch" do
    map = Sync::Map(Int32, Int32).new(16, 4)
    map[1] = 123
    map[-5] = 54
    map[129879] = 789

    # raising
    map[1].should eq(123)
    map[-5].should eq(54)
    expect_raises(KeyError) { map[2] }

    # nilable
    map[1]?.should eq(123)
    map[-5]?.should eq(54)
    map[2]?.should be_nil

    # default
    map.fetch(1, -1).should eq(123)
    map.fetch(129879, -2).should eq(789)
    map.fetch(2, -3).should eq(-3)
    map.fetch(2, nil).should be_nil

    # default (block)
    map.fetch(1) { -1 }.should eq(123)
    map.fetch(129879) { -2 }.should eq(789)
    map.fetch(2) { 981726 }.should eq(981726)
  end

  it "#has_key?" do
    map = Sync::Map(Int32, Int32).new(16, 4)
    map.has_key?(1).should be_false

    map[1] = 123
    map[-5] = 54
    map[129879] = 789

    map.has_key?(1).should be_true
    map.has_key?(-5).should be_true
    map.has_key?(129879).should be_true
    map.has_key?(0).should be_false
    map.has_key?(9812).should be_false
  end

  it "#each" do
    map = Sync::Map(Int32, Int32).new(16, 4)
    100.times { |i| map[i * 2] = i * 5 }

    keys = [] of Int32
    values = [] of Int32

    map.each do |k, v|
      keys << k
      values << v
    end

    100.times.map(&.*(2)).to_a.should eq(keys.sort!)
    100.times.map(&.*(5)).to_a.should eq(values.sort!)
  end

  it "#keys" do
    map = Sync::Map(Int32, Int32).new(16, 4)
    map.keys.should eq([] of Int32)

    map[1] = 123
    map[-5] = 54
    map[129879] = 789
    map.keys.sort!.should eq([-5, 1, 129879])
  end

  it "#values" do
    map = Sync::Map(Int32, Int32).new(16, 4)
    map.values.should eq([] of Int32)

    map[1] = 123
    map[-5] = 54
    map[129879] = 789
    map.values.sort!.should eq([54, 123, 789])
  end

  it "#delete" do
    map = Sync::Map(Int32, Int32).new(16, 4)
    map.size.should eq(0)

    # delete unknown key
    map.delete(1).should be_nil

    map[1] = 123
    map[5] = 54
    map[129879] = 789

    # delete known key
    map.delete(5).should eq(54)
    map.size.should eq(2)
    map[5]?.should be_nil

    # reinsert (recycle tombstone)
    map[5] = 88
    map.size.should eq(3)
    map[5].should eq(88)
  end

  it "#resizes" do
    map = Sync::Map(Int32, Int32).new(8, 4)

    # insert
    WaitGroup.wait do |wg|
      8.times do |n|
        wg.spawn do
          256.times do |i|
            ii = n * 256 + i
            map[ii] = ii * 2
          end
        end
      end
    end
    map.size.should eq(2048)

    # verify
    WaitGroup.wait do |wg|
      8.times do |n|
        256.times do |i|
          ii = n * 256 + i
          map[ii].should eq(ii * 2)
        end
      end
    end

    # delete half the keys (even ones)
    WaitGroup.wait do |wg|
      8.times do |n|
        128.times do |i|
          j = (n * 128 + i) * 2
          map.delete(j)
        end
      end
    end
    map.size.should eq(1024)

    # verify
    1.step(to: 2047, by: 2) do |i|
      map[i].should eq(i * 2)
    end

    # re-insert + replace existing
    WaitGroup.wait do |wg|
      8.times do |n|
        wg.spawn do
          256.times do |i|
            ii = n * 256 + i
            map[ii] = ii * 3
          end
        end
      end
    end

    # verify
    2048.times do |i|
      map[i].should eq(i * 3)
    end
    map.size.should eq(2048)
  end

  it "#dup" do
    map = Sync::Map(Int32, Int32).new(16, 4)
    map[1] = 123
    map[-5] = 54
    map[129879] = 789

    copy = map.dup
    copy.should_not be(map)
    copy.size.should eq(map.size)
    copy.to_a.should eq(map.to_a)

    # modifying copy doesn't affect original
    copy[1] = 321
    copy[2] = 4
    copy.to_a.sort!.should_not eq(map.to_a.sort!)
  end
end
